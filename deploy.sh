#!/usr/bin/env bash

# SSH parameters
SSH="ssh -o StrictHostKeyChecking=no -i $DEPLOY_KEY $DEPLOY_USER@$DEPLOY_HOST"
SCP="scp -o StrictHostKeyChecking=no -i $DEPLOY_KEY"

# Decrypt deployment key
openssl aes-256-cbc -K $encrypted_0c35eebf403c_key -iv $encrypted_0c35eebf403c_iv -in deploy.key.enc -out $DEPLOY_KEY -d
chmod 400 $DEPLOY_KEY

# Decrypt configuration
function decrypt() {
  filename="$1"
  openssl enc -aes-256-cbc -pass env:SECRET_PASSWORD -d -a -in "${filename}" -out "${filename}.dec" && rm -f "${filename}" && mv "${filename}.dec" "${filename}"
} 
decrypt config/integrations.yml

# Create dashboard artifact 
rm -rf dashboard.tgz
tar -czf dashboard.tgz ./config ./assets ./dashboards ./jobs ./public ./widgets ./config.ru ./Gemfile* ./smashing.service

# Copy artifacts to remote host
$SCP dashboard.tgz $DEPLOY_USER@$DEPLOY_HOST:/tmp
$SCP smashing.nginx $DEPLOY_USER@$DEPLOY_HOST:/tmp
rm -rf dashboard.tgz
rm -rf config/integrations.yml

# Deploy dashboard code
$SSH sudo mkdir -p /dashboard/config
$SSH sudo tar -zxvf /tmp/dashboard.tgz --no-same-owner -C /dashboard

# Create or renew certificate
# TODO: if does not exist or expired
# $SSH sudo systemctl stop nginx
decrypt cloudflare.ini
$SSH mkdir -p /home/ubuntu/.secrets/cerbot
$SCP cloudflare.ini $DEPLOY_USER@$DEPLOY_HOST:/home/ubuntu/.secrets/cerbot
# $SSH sudo docker run --rm --name certbot -it -p 80:80 -p 443:443 -v /etc/letsencrypt:/etc/letsencrypt/ -v /var/log/letsencrypt:/var/log/letsencrypt -v /home/ubuntu/.secrets/certbot:/secrets certbot/dns-cloudflare certonly --dns-cloudflare --dns-cloudflare-credentials /secrets/cloudflare.ini --dns-dnsimple-propagation-seconds 60 -n --agree-tos -m andrey@aestasit.com -d dashboard.devternity.com --server https://acme-v02.api.letsencrypt.org/directory"
$SSH rm -rf /home/ubuntu/.secrets
rm -rf cloudflare.ini

# Restart service
$SSH <<EOF
  sudo mkdir -p /var/lib/sqlite
  sudo touch /var/lib/sqlite/twitter.db
  yes | sudo cp -rf /tmp/smashing.nginx /etc/nginx/sites-available/default
  echo ">>>> Stopping service"
  sudo systemctl stop smashing 
  echo ">>>> Installing bundler"
  cd /dashboard && bundler install
  echo ">>>> Enabling service"
  sudo systemctl disable smashing.service
  sudo systemctl daemon-reload
  sudo systemctl enable /dashboard/smashing.service
  sudo systemctl daemon-reload
  echo ">>>> Restarting service"
  sudo systemctl start smashing 
  sudo systemctl restart nginx
  echo ">>>> Sleeping"
  sleep 30
  echo ">>>> Showing logs"
  sudo journalctl --no-pager --since "15 minutes ago" -u smashing.service
  echo ">>>> Checking status"
  sudo systemctl -q is-active smashing
EOF


