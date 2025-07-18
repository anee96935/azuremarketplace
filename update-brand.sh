#!/bin/bash

DB_USER="$1"
DB_PASS="$2"
DB_NAME="$3"
BRAND_NAME="$4"

echo "Starting brand update for $BRAND_NAME"

# Update site title and description
mysql -u "$DB_USER" -p"$DB_PASS" -e "
USE $DB_NAME;
UPDATE wp_options SET option_value = '$BRAND_NAME' WHERE option_name IN ('blogname', 'blogdescription');
UPDATE wp_options SET option_value = REPLACE(option_value, 'http://OLD_IP', 'http://NEW_IP') WHERE option_name IN ('siteurl', 'home');
"

# Update plugin branding if needed
sed -i "s/page=athena/page=$BRAND_NAME/g" /var/www/html/wp-content/plugins/athena/lib/helpers/athena_grid_helper.php

echo "Brand update completed" >> /var/log/brand-update.log
