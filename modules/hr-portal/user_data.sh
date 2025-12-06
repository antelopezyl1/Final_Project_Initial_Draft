#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y jq awscli

IS_PRIMARY="${is_primary}"

# 从 Secrets Manager 读取 DB 用户和密码（用于 mysql 建库）
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --region us-west-1 \
  --secret-id "hr-portal-db-credentials" \
  --query SecretString \
  --output text)

DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)

# 这些变量由 Terraform 的 templatefile 注入
DB_HOST_RAW="${db_host}"
DB_PORT="${db_port}"
DB_NAME="${db_name}"
SITE_URL="${site_url}"

# 去掉 DB_HOST 本身已经带的 :port（如果有）
DB_HOST=$(echo "$DB_HOST_RAW" | cut -d ':' -f 1)

echo "DB_HOST_RAW=$DB_HOST_RAW" >> /var/log/cloud-init-output.log
echo "DB_HOST=$DB_HOST  DB_PORT=$DB_PORT  IS_PRIMARY=$IS_PRIMARY" >> /var/log/cloud-init-output.log

apt-get update -y
apt-get install -y apache2 mysql-client php libapache2-mod-php php-mysql php-xml php-gd php-mbstring php-curl php-zip unzip curl wget ca-certificates

# Apache 基本配置
a2enmod rewrite
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf
systemctl enable --now apache2

# ---- 只在 primary 节点创建 DB ----
if [ "$IS_PRIMARY" = "true" ]; then
  # 等 RDS ready
  for i in {1..24}; do
    if timeout 2 bash -c "echo > /dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
      break
    fi
    sleep 5
  done

  # 创建数据库
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" \
    -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
    || echo "[WARN] create database failed, continue..."
fi
# ---- /only primary ----

# 安装 WordPress
cd /var/www/html
rm -rf ./*
curl -L -o wp.tar.gz https://wordpress.org/latest.tar.gz
tar -xzf wp.tar.gz --strip-components=1
rm -f wp.tar.gz

# 安装 Composer 和 AWS SDK for PHP（给 wp-config.php 用）
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

cd /var/www/html
composer require aws/aws-sdk-php

# 写入带 Secrets Manager 集成的 wp-config.php
cat > wp-config.php <<PHP
<?php
/**
 * Custom wp-config.php for HR Portal with Secrets Manager integration
 */

require __DIR__ . '/vendor/autoload.php';

use Aws\SecretsManager\SecretsManagerClient;
use Aws\Exception\AwsException;

/**
 * Retrieve DB credentials from AWS Secrets Manager using EC2 IAM Role
 */
\$region     = 'us-west-1';
\$secretName = 'hr-portal-db-credentials';

\$client = new SecretsManagerClient([
    'version' => '2017-10-17',
    'region'  => \$region,
]);

try {
    \$result       = \$client->getSecretValue(['SecretId' => \$secretName]);
    \$secretString = \$result['SecretString'];
    \$secret       = json_decode(\$secretString, true);

    if (!is_array(\$secret) || !isset(\$secret['username'], \$secret['password'])) {
        throw new \RuntimeException('Secret format is invalid.');
    }

    \$dbUser = \$secret['username'];
    \$dbPass = \$secret['password'];
} catch (AwsException \$e) {
    error_log('Failed to retrieve DB credentials from Secrets Manager: ' . \$e->getMessage());
    die('Error loading database credentials. Please contact administrator.');
} catch (\Throwable \$e) {
    error_log('Unexpected error when reading DB secret: ' . \$e->getMessage());
    die('Error loading database credentials. Please contact administrator.');
}

/** db settings */

define( 'DB_NAME', '$DB_NAME' ); 
define( 'DB_USER', \$dbUser );                // from Secrets Manager
define( 'DB_PASSWORD', \$dbPass );            // from Secrets Manager
define( 'DB_HOST', '$DB_HOST:$DB_PORT' );  
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

/** 数据表前缀 */
\$table_prefix = 'wp_';

/** 调试模式 */
define( 'WP_DEBUG', false );

/** 设置绝对路径并加载 WordPress 核心文件 */
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require ABSPATH . 'wp-settings.php';
PHP

# 自动插入随机 SALT
sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" wp-config.php
curl -s https://api.wordpress.org/secret-key/1.1/salt/ > /tmp/wp-salts
awk '1;/\$table_prefix/{system("cat /tmp/wp-salts")}' wp-config.php > wp-config.php.new && mv wp-config.php.new wp-config.php

# Optional: SITE_URL
if [ -n "$SITE_URL" ]; then
  cat >> wp-config.php <<EOF
define( 'WP_HOME', '$SITE_URL' );
define( 'WP_SITEURL', '$SITE_URL' );
EOF
fi

chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find -H /var/www/html -type f -exec chmod 644 {} \;

systemctl restart apache2
