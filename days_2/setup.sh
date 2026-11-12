#!/bin/bash

set -euo pipefail

# check if the user is root
if [ "$EUID" -ne 0 ]; then
	echo "Execute the script as SUDO." >&2
	exit 1
fi

#Get into the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

#Check if all the files exists
[ -f index.html ] || { echo "index.html is missing"; exit 1; }
[ -f nginx.conf ] || { echo "nginx.conf is missing"; exit 1; }

#install nginx
apt-get update
apt-get install -y nginx curl tor

#creation of the tree of ft_onion
mkdir -p /var/www/ft_onion
cp index.html /var/www/ft_onion/index.html
chown -R www-data:www-data /var/www/ft_onion
chmod 755 /var/www/ft_onion
chmod 644 /var/www/ft_onion/index.html
cp nginx.conf /etc/nginx/sites-available/ft_onion


#enable ft_onion in nginx
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ft_onion /etc/nginx/sites-enabled/ft_onion

#test and reboot nginx
nginx -t
systemctl enable nginx
systemctl restart nginx

#Tor hidden service
[ -s torrc ] || { echo "torrc is missing or empty" >&2 ; exit 1; }
TORRC_MARKER="# ft_onion hidden service"
if ! grep -qF "$TORRC_MARKER" /etc/tor/torrc; then
	cp -a /etc/tor/torrc "/etc/tor/torrc.bak.$(date +%s)"
	printf '\n' >> /etc/tor/torrc
	cat torrc >> /etc/tor/torrc
fi

#test and reboot tor
systemctl enable tor
systemctl restart tor
HIDDEN_DIR="$(awk '$1 == "HiddenServiceDir" {print $2; exit}' torrc)"
HIDDEN_DIR="${HIDDEN_DIR%/}"
HOSTNAME_FILE="$HIDDEN_DIR/hostname"

#Waiting for the hostname to be created
for _ in $(seq 1 30); do
	[ -s "$HOSTNAME_FILE" ] && break
	sleep 1
done
[ -s "$HOSTNAME_FILE" ] || {
	echo "Tor did not create hostname" >&2
	journalctl -u tor -n 30 --no-pager
	exit 1
}

#last check
if curl -fsS http://127.0.0.1/ | grep -q "Welcome to ft_onion" ; then
	echo "Page correctly served"
else
	echo "Page is not working" >&2
	exit 1
fi
ONION="$(cat "$HOSTNAME_FILE")"
echo "Onion address: $ONION"

