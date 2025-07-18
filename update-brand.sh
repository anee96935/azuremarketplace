#!/bin/bash

BRAND_NAME="$1"
ADMIN_USER="$2"
ADMIN_PASS="$3"

# Fetch DB credentials from image-included files (do NOT hardcode them)
DB_USER=$(cat /etc/athena/db_user)
DB_PASS=$(cat /etc/athena/db_pass)
DB_NAME=$(cat /etc/athena/db_name)

# Get current public IP
CURRENT_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Updating site branding to '$BRAND_NAME' at $CURRENT_IP"

# Update WordPress site title and URL
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
UPDATE wp_options SET option_value = '$BRAND_NAME' WHERE option_name = 'blogname';
UPDATE wp_options SET option_value = REPLACE(option_value, option_value, 'http://$CURRENT_IP') WHERE option_name IN ('siteurl', 'home');
"

# Set or update admin user
EXISTING_USER=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -se "SELECT ID FROM wp_users WHERE user_login = '$ADMIN_USER';")

if [ -z "$EXISTING_USER" ]; then
    # Create new admin user if not exists
    HASHED_PASS=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
    INSERT INTO wp_users (user_login, user_pass, user_nicename, user_email, user_status, display_name)
    VALUES ('$ADMIN_USER', '$HASHED_PASS', '$ADMIN_USER', '$ADMIN_USER@example.com', 0, '$ADMIN_USER');
    SET @user_id = LAST_INSERT_ID();
    INSERT INTO wp_usermeta (user_id, meta_key, meta_value) VALUES (@user_id, 'wp_capabilities', 'a:1:{s:13:\"administrator\";b:1;}');
    INSERT INTO wp_usermeta (user_id, meta_key, meta_value) VALUES (@user_id, 'wp_user_level', '10');
    "
    echo "Admin user '$ADMIN_USER' created"
else
    # Update password for existing user
    HASHED_PASS=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
    UPDATE wp_users SET user_pass = '$HASHED_PASS' WHERE ID = $EXISTING_USER;
    "
    echo "Admin user '$ADMIN_USER' password updated"
fi

# Replace branding in plugin
sed -i "s/page=athena/page=$BRAND_NAME/g" /var/www/html/wp-content/plugins/athena/lib/helpers/athena_grid_helper.php

echo "Brand update completed at $(date)" >> /var/log/brand-update.log
