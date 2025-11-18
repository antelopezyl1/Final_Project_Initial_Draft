#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

IS_PRIMARY="${is_primary}"

DB_HOST_RAW="${db_host}"
DB_PORT="${db_port}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
SITE_URL="${site_url}"

# remove redundant :port
DB_HOST="$${DB_HOST_RAW%%:*}"

echo "DB_HOST_RAW=$DB_HOST_RAW" >> /var/log/cloud-init-output.log
echo "DB_HOST=$DB_HOST  DB_PORT=$DB_PORT  IS_PRIMARY=$IS_PRIMARY" >> /var/log/cloud-init-output.log

apt-get update -y
apt-get install -y apache2 mysql-client php libapache2-mod-php php-mysql php-xml php-gd php-mbstring php-curl php-zip unzip curl wget ca-certificates

# Apache 
a2enmod rewrite
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf
systemctl enable --now apache2

# ---- create DB only in primary node ----
if [ "$IS_PRIMARY" = "true" ]; then
  # wait RDS activate
  for i in {1..24}; do
    if timeout 2 bash -c "echo > /dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
      break
    fi
    sleep 5
  done

  # create db
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" \
    -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
    || echo "[WARN] create database failed, continue..."
fi
# ---- /only primary ----

# install WordPress files
cd /var/www/html
rm -rf ./*
curl -L -o wp.tar.gz https://wordpress.org/latest.tar.gz
tar -xzf wp.tar.gz --strip-components=1
rm -f wp.tar.gz

cp wp-config-sample.php wp-config.php

# write DB_* and DB_HOST
sed -i "s/database_name_here/$DB_NAME/;s/username_here/$DB_USER/;s/password_here/$DB_PASSWORD/" wp-config.php
# set DB_HOST=host:port
sed -i "s/define( 'DB_HOST'.*/define( 'DB_HOST', '$DB_HOST:$DB_PORT' );/" wp-config.php

# SALT
sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" wp-config.php
curl -s https://api.wordpress.org/secret-key/1.1/salt/ > /tmp/wp-salts
awk '1;/\$table_prefix/{system("cat /tmp/wp-salts")}' wp-config.php > wp-config.php.new && mv wp-config.php.new wp-config.php


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
