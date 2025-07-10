bash
CopyEdit
#!/bin/bash

BRAND_NAME=$1
USERNAME=$2
PASSWORD=$3

# Validate input
if [[ -z "$BRAND_NAME" || -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo "Missing one or more inputs. Exiting." >&2
  exit 1
fi

# Create user and store brand info
useradd -m "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "Welcome to $BRAND_NAME!" > /home/$USERNAME/welcome.txt
chown $USERNAME:$USERNAME /home/$USERNAME/welcome.txt
