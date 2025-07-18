#!/bin/bash

BRAND_NAME="$1"
ADMIN_USER="$2"
ADMIN_PASS="$3"

LOG_FILE="/var/log/brand-update.log"

# Validate input
if [[ -z "$BRAND_NAME" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  echo "Usage: $0 BRAND_NAME ADMIN_USER ADMIN_PASS" | tee -a "$LOG_FILE"
  exit 1
fi

# Fetch DB credentials from secure files
DB_USER=$(cat /etc/athena/db_user)
DB_PASS=$(cat /etc/athena/db_pass)
DB_NAME=$(cat /etc/athena/db_name)

# Get current public IP
CURRENT_IP=$(curl --silent --fail http://169.254.169.254/latest/meta-data/public-ipv4)

if [ -z "$CURRENT_IP" ]; then
  echo "Failed to fetch current public IP address." | tee -a "$LOG_FILE"
  exit 1
fi

echo "[$(date)] Updating brand to '$BRAND_NAME' at $CURRENT_IP" | tee -a "$LOG_FILE"

# Update WordPress site title and URLs
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
UPDATE wp_options SET option_value = '$BRAND_NAME' WHERE option_name = 'blogname';
UPDATE wp_options SET option_value = 'http://$CURRENT_IP' WHERE option_name IN ('siteurl', 'home');
" 2>>"$LOG_FILE"

# Set or update admin user
EXISTING_USER=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -se "SELECT ID FROM wp_users WHERE user_login = '$ADMIN_USER';" 2>>"$LOG_FILE")

HASHED_PASS=$(php -r "echo password_hash('$ADMIN_PASS', PASSWORD_BCRYPT);")

if [ -z "$EXISTING_USER" ]; then
  # Create new admin user
  mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
    INSERT INTO wp_users (user_login, user_pass, user_nicename, user_email, user_status, display_name)
    VALUES ('$ADMIN_USER', '$HASHED_PASS', '$ADMIN_USER', '$ADMIN_USER@example.com', 0, '$ADMIN_USER');
    SET @user_id = LAST_INSERT_ID();
    INSERT INTO wp_usermeta (user_id, meta_key, meta_value) VALUES (@user_id, 'wp_capabilities', 'a:1:{s:13:\"administrator\";b:1;}');
    INSERT INTO wp_usermeta (user_id, meta_key, meta_value) VALUES (@user_id, 'wp_user_level', '10');
  " 2>>"$LOG_FILE"
  echo "[$(date)] Admin user '$ADMIN_USER' created" | tee -a "$LOG_FILE"
else
  # Update existing user password
  mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
    UPDATE wp_users SET user_pass = '$HASHED_PASS' WHERE ID = $EXISTING_USER;
  " 2>>"$LOG_FILE"
  echo "[$(date)] Admin user '$ADMIN_USER' password updated" | tee -a "$LOG_FILE"
fi

# Update plugin branding reference
sed -i "s/page=athena/page=$BRAND_NAME/g" /var/www/html/wp-content/plugins/athena/lib/helpers/athena_grid_helper.php

echo "[$(date)] Branding and admin setup complete." | tee -a "$LOG_FILE"
