#!/bin/bash

BRAND_NAME="$1"
ADMIN_USER="$2"
ADMIN_PASS="$3"
WP_PATH="/var/www/html"

# Read DB credentials from a secure local file or env vars
DB_USER=$(cat /etc/athena/db_user)
DB_PASS=$(cat /etc/athena/db_pass)
DB_NAME=$(cat /etc/athena/db_name)

NEW_IP=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text")

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
UPDATE wp_options SET option_value = '$BRAND_NAME' WHERE option_name IN ('blogname', 'blogdescription');
UPDATE wp_options SET option_value = 'http://$NEW_IP' WHERE option_name IN ('siteurl', 'home');
UPDATE wp_users SET user_login = '$ADMIN_USER', user_pass = MD5('$ADMIN_PASS') WHERE ID = 1;
"

# Update WordPress options via WP-CLI
wp option update blogname "$BRAND_NAME" --path="$WP_PATH" --allow-root
wp option update blogdescription "$BRAND_NAME" --path="$WP_PATH" --allow-root