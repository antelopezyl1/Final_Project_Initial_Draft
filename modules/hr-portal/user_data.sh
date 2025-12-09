#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y jq unzip

# install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install -i /usr/local/aws-cli -b /usr/local/bin

apt-get install -y apache2 mysql-client php libapache2-mod-php php-mysql php-xml php-gd php-mbstring php-curl php-zip unzip curl wget ca-certificates


IS_PRIMARY="${is_primary}"

# read DB username and pass from Secrets Manager 
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --region us-west-1 \
  --secret-id "hr-portal-db-credentials-v2" \
  --query SecretString \
  --output text)

DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)

# These parameters are injected by templatefile of Terraform 
DB_HOST_RAW="${db_host}"
DB_PORT="${db_port}"
DB_NAME="${db_name}"
SITE_URL="${site_url}"

# remove :port from DB_HOST 
DB_HOST=$(echo "$DB_HOST_RAW" | cut -d ':' -f 1)

echo "DB_HOST_RAW=$DB_HOST_RAW" >> /var/log/cloud-init-output.log
echo "DB_HOST=$DB_HOST  DB_PORT=$DB_PORT  IS_PRIMARY=$IS_PRIMARY" >> /var/log/cloud-init-output.log

# Apache config
a2enmod rewrite
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf
systemctl enable --now apache2

# ---- create db only in primary ----
if [ "$IS_PRIMARY" = "true" ]; then
  # wait RDS ready
  for i in {1..24}; do
    if timeout 2 bash -c "echo > /dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
      break
    fi
    sleep 5
  done

  # create db if not exist
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" \
    -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
    || echo "[WARN] create database failed, continue..."
fi
# ---- /only primary ----

# install WordPress
cd /var/www/html
rm -rf ./*
curl -L -o wp.tar.gz https://wordpress.org/latest.tar.gz
tar -xzf wp.tar.gz --strip-components=1
rm -f wp.tar.gz

# install Composer and AWS SDK for PHP（for wp-config.php）
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

cd /var/www/html
composer require aws/aws-sdk-php

# write wp-config.php with Secrets Manager
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

/** prefix of tables */
\$table_prefix = 'wp_';

/** debug mode */
define( 'WP_DEBUG', false );

/** set abs path and load WordPress files */
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require ABSPATH . 'wp-settings.php';
PHP

# sed random SALT
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
