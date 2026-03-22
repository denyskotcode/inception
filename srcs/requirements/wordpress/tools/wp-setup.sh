#!/bin/sh
set -e

# Read secrets
DB_PASSWORD=$(cat /run/secrets/db_password)

# Read WordPress credentials from secrets file
WP_ADMIN_USER=$(grep '^WP_ADMIN_USER=' /run/secrets/credentials | cut -d'=' -f2)
WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASS=' /run/secrets/credentials | cut -d'=' -f2)
WP_ADMIN_EMAIL=$(grep '^WP_ADMIN_EMAIL=' /run/secrets/credentials | cut -d'=' -f2)
WP_USER=$(grep '^WP_USER_LOGIN=' /run/secrets/credentials | cut -d'=' -f2)
WP_USER_PASSWORD=$(grep '^WP_USER_PASS=' /run/secrets/credentials | cut -d'=' -f2)
WP_USER_EMAIL=$(grep '^WP_USER_EMAIL=' /run/secrets/credentials | cut -d'=' -f2)

# Wait for MariaDB to be ready
echo "Waiting for MariaDB..."
until php -r "\$c=@new mysqli('${MYSQL_HOST}','${MYSQL_USER}','${DB_PASSWORD}','${MYSQL_DATABASE}');exit(\$c->connect_errno?1:0);" 2>/dev/null; do
    echo "MariaDB not ready, retrying in 3s..."
    sleep 3
done
echo "MariaDB is ready."

# Idempotent WordPress installation
if ! wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
    echo "Installing WordPress..."

    if [ ! -f "/var/www/html/wp-includes/version.php" ]; then
        wp core download \
            --path=/var/www/html \
            --allow-root \
            --locale=en_US
    fi

    if [ ! -f "/var/www/html/wp-config.php" ]; then
        wp config create \
            --path=/var/www/html \
            --dbname="${MYSQL_DATABASE}" \
            --dbuser="${MYSQL_USER}" \
            --dbpass="${DB_PASSWORD}" \
            --dbhost="${MYSQL_HOST}" \
            --allow-root
    fi

    wp core install \
        --path=/var/www/html \
        --url="${WP_URL}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=editor \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root \
        --path=/var/www/html

    echo "WordPress installed successfully."
fi

# Set correct file permissions
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

echo "Starting PHP-FPM..."
exec php-fpm8.2 --nodaemonize
