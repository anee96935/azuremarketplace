#!/bin/bash
set -e

# === Auto-fix line endings ===
if [ -z "$DOS2UNIX_FIXED" ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y && apt-get install -y dos2unix
  dos2unix "$0"
  DOS2UNIX_FIXED=1 exec "$0" "$@"
fi

# === CONFIG ===
WP_PATH="/var/www/html"
NEW_BRAND="Yen Healthcare"
BRAND_PAGE_NAME="yen"
OLD_BRANDS=("Athena" "athena")

# === Replace in wp_postmeta and wp_posts ===
for OLD in "${OLD_BRANDS[@]}"; do
  wp search-replace "$OLD" "$NEW_BRAND" wp_postmeta --include-columns=meta_value --path="$WP_PATH" --allow-root
  wp search-replace "$OLD" "$NEW_BRAND" wp_posts --include-columns=post_title,post_content --path="$WP_PATH" --allow-root
done

# === Update wp_athena_settings setting ===
wp db query "
  UPDATE wp_athena_settings
  SET value = REPLACE(value, 'Athena', '${NEW_BRAND}')
  WHERE name = 'notification_email_setting_from_name';
" --path="/var/www/html" --allow-root

# === Update WordPress Site Title and Tagline ===
wp option update blogname "$NEW_BRAND" --path="$WP_PATH" --allow-root
wp option update blogdescription "$NEW_BRAND" --path="$WP_PATH" --allow-root

# === Clear cache and regenerate Elementor CSS ===
wp cache flush --path="$WP_PATH" --allow-root
wp elementor flush-css --path="$WP_PATH" --allow-root

# === Replace menu title label ===
PLUGIN_FILE="$WP_PATH/wp-content/plugins/athena/athena.php"
if [ -f "$PLUGIN_FILE" ]; then
  sed -i "s/__('\(Athena\)', 'athena')/get_option('blogname')/" "$PLUGIN_FILE"
fi

# === Inject brand filters into theme functions.php ===
THEME_NAME=$(wp theme list --status=active --field=name --path="$WP_PATH" --allow-root)
THEME_FUNCTIONS="$WP_PATH/wp-content/themes/$THEME_NAME/functions.php"

BRANDING_FIX=$(cat <<EOF
// Auto-added by brand update script to rename 'WordPress' in admin/frontend
add_filter('admin_title', function(\$admin_title, \$title) {
    return str_ireplace('WordPress', '$NEW_BRAND', \$admin_title);
}, 10, 2);

add_filter('login_title', function(\$login_title) {
    return str_ireplace('WordPress', '$NEW_BRAND', \$login_title);
});

add_filter('wp_title', function(\$title, \$sep) {
    return str_ireplace('WordPress', '$NEW_BRAND', \$title);
}, 10, 2);

add_filter('admin_footer_text', function(\$text) {
    return str_ireplace('WordPress', '$NEW_BRAND', \$text);
});

add_filter('update_footer', function(\$text) {
    return str_ireplace('WordPress', '$NEW_BRAND', \$text);
}, 11);

add_filter('gettext', function(\$translated_text, \$text, \$domain) {
    return str_ireplace('WordPress', '$NEW_BRAND', \$translated_text);
}, 20, 3);
EOF
)

if ! grep -q "str_ireplace('WordPress'" "$THEME_FUNCTIONS"; then
  echo "$BRANDING_FIX" >> "$THEME_FUNCTIONS"
fi

# === Replace hardcoded 'Back to WordPress' in sidebar ===
SIDE_MENU_FILE="$WP_PATH/wp-content/plugins/athena/lib/views/partials/_side_menu.php"
if [ -f "$SIDE_MENU_FILE" ]; then
  sed -i "s/Back to WordPress/Back to $NEW_BRAND/g" "$SIDE_MENU_FILE"
fi

# === Update URL aliases in database ===
wp search-replace 'athena-login.php' 'yen-login.php' --all-tables --path="$WP_PATH" --allow-root
wp search-replace 'athena-admin' 'yen-admin' --all-tables --path="$WP_PATH" --allow-root

# === Replace login/admin paths in .htaccess only ===
HTACCESS_FILE="$WP_PATH/.htaccess"
if [ -f "$HTACCESS_FILE" ]; then

  sed -i 's/athena-login\.php/yen-login.php/g' "$HTACCESS_FILE"
  sed -i 's/athena-admin/yen-admin/g' "$HTACCESS_FILE"
fi

# === Update plugin menu page slug ===
PLUGIN_FILE="$WP_PATH/wp-content/plugins/athena/athena.php"
if [ -f "$PLUGIN_FILE" ]; then

  awk '
  /add_menu_page\s*\(/ {
    found=1
  }
  found && /'\''athena'\''/ {
    sub(/'\''athena'\''/, "'\''yen'\''")
    found=0
  }
  { print }
  ' "$PLUGIN_FILE" > "${PLUGIN_FILE}.tmp" && mv "${PLUGIN_FILE}.tmp" "$PLUGIN_FILE"
fi

THEME_NAME=$(wp theme list --status=active --field=name --path="$WP_PATH" --allow-root)
THEME_FUNCTIONS="$WP_PATH/wp-content/themes/$THEME_NAME/functions.php"

# Inject filter to keep old body classes if not present
if ! grep -q "add_filter('admin_body_class'" "$THEME_FUNCTIONS"; then
cat <<EOF >> "$THEME_FUNCTIONS"

add_filter('admin_body_class', function(\$classes) {
    if (strpos(\$_SERVER['REQUEST_URI'], 'page=yen') !== false) {
        \$classes .= ' athena-admin athena';
    }
    return \$classes;
});
EOF
fi

# === Inject output buffer with static brand from $NEW_BRAND_NAME ===
if ! grep -q "replace_wordpress_with_athena" "$THEME_FUNCTIONS"; then
cat <<EOF >> "$THEME_FUNCTIONS"

function replace_wordpress_with_athena(\$buffer) {
    return str_ireplace('wordpress', '$BRAND_PAGE_NAME', \$buffer);
}

add_action('template_redirect', function() {
    ob_start('replace_wordpress_with_athena');
});
add_action('admin_init', function() {
    ob_start('replace_wordpress_with_athena');
});
EOF
fi

GRID_HELPER_FILE="/var/www/html/wp-content/plugins/athena/lib/helpers/athena_grid_helper.php"

if [ -f "$GRID_HELPER_FILE" ]; then
    # Only replace in lines that match the specific patterns
    sed -i "/if(\$_REQUEST\['page'\]/ s/'athena'/'$BRAND_PAGE_NAME'/" "$GRID_HELPER_FILE"
    sed -i "/if ((is_admin()) && isset(\$_GET\['page'\])/ s/'athena'/'$BRAND_PAGE_NAME'/" "$GRID_HELPER_FILE"
fi


# === Replace login redirect to page=yen ===
find "$WP_PATH/wp-content/plugins/athena" -type f -name "*.php" -exec sed -i "s/admin\.php?page=athena/admin.php?page=yen/g" {} +

# === Safely update Branda login redirect (ub_login_screen) from ?page=athena to ?page=yen ===
BRANDA_OPTION_JSON=$(wp option get ub_login_screen --format=json --path="$WP_PATH" --allow-root)

if echo "$BRANDA_OPTION_JSON" | grep -q "page=athena"; then
  echo "$BRANDA_OPTION_JSON" | sed 's/page=athena/page=yen/g' > /tmp/ub_login_screen.json
  wp option update ub_login_screen --format=json < /tmp/ub_login_screen.json --path="$WP_PATH" --allow-root
  rm /tmp/ub_login_screen.json
fi

GRID_HELPER_FILE="$WP_PATH/wp-content/plugins/athena/lib/helpers/athena_grid_helper.php"
if [ -f "$GRID_HELPER_FILE" ]; then
  sed -i "s/['\"]page['\"][[:space:]]*==[[:space:]]*['\"]athena['\"]/\"page\" == \"yen\"/g" "$GRID_HELPER_FILE"
fi

if [ -f "$GRID_HELPER_FILE" ]; then
  sed -i "s/\\\$_GET\['page'\][[:space:]]*==[[:space:]]*'athena'/\$_GET['page'] == 'yen'/g" "$GRID_HELPER_FILE"
fi

# === File paths to process ===
FILES=(
"/var/www/html/wp-content/plugins/athena-users/public/javascripts/athena_user_admin_script.js"
"/var/www/html/wp-content/plugins/athena-remove-wp/athena-remove-wp.php"
"/var/www/html/wp-content/plugins/athena-payroll/lib/views/soapnotes/index.php"
"/var/www/html/wp-content/plugins/athena-payroll/lib/helpers/soap_notes_css_js_file_inc.php"
"/var/www/html/wp-content/plugins/athena-addon-customer/lib/views/client_availibility.php"
"/var/www/html/wp-content/plugins/athena-addon-customer/lib/models/athena_customer_model.php"
)

# === Replace 'athena-admin' with 'yen-admin' in each file ===
for FILE in "${FILES[@]}"; do
  if [ -f "$FILE" ]; then
    sed -i "s/athena-admin/yen-admin/g" "$FILE"
  fi
done

# === Define absolute Linux paths for each file ===
FILES=(
"/var/www/html/wp-content/plugins/athena-users/public/javascripts/athena_user_admin_script.js"
"/var/www/html/wp-content/plugins/athena-remove-wp/athena-remove-wp.php"
"/var/www/html/wp-content/plugins/athena-payroll/athena-payroll.php"
"/var/www/html/wp-content/plugins/athena-addon-customer/lib/views/client_availibility.php"
"/var/www/html/wp-content/plugins/athena-addon-customer/lib/models/athena_customer_model.php"
"/var/www/html/wp-content/plugins/athena/lib/helpers/router_helper.php"
)

# === Perform search and replace ?page=athena → ?page=yen ===
for FILE in "${FILES[@]}"; do
  if [ -f "$FILE" ]; then
    sed -i "s/?page=athena/?page=yen/g" "$FILE"
  fi
done

