#!/bin/bash
set -e

# Read secrets
DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

# Create runtime directories
mkdir -p /run/mysqld /var/log/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql /var/log/mysql

# Step 1: Initialize raw data if not yet done
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Running mysql_install_db..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
    echo "mysql_install_db done."
fi

# Step 2: Setup application DB/user if not yet done
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "Setting up databases and users..."

    # Start temporary server (no networking, no password yet)
    mysqld --user=mysql --skip-networking &
    MYSQL_PID=$!

    # Wait for socket to be ready
    until mysqladmin --host=localhost --socket=/run/mysqld/mysqld.sock ping --silent 2>/dev/null; do
        sleep 1
    done

    mysql --host=localhost --socket=/run/mysqld/mysqld.sock -u root <<-EOSQL
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        FLUSH PRIVILEGES;
EOSQL

    kill $MYSQL_PID
    wait $MYSQL_PID 2>/dev/null || true
    echo "MariaDB initialized."
fi

# Start MariaDB as PID 1
exec mysqld --user=mysql
