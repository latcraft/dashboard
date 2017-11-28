#!/usr/bin/env bash

# SSH parameters
SSH="ssh -o StrictHostKeyChecking=no -i $DEPLOY_KEY $DEPLOY_USER@$DEPLOY_HOST"

# Decrypt deployment key
openssl aes-256-cbc -K $encrypted_0c35eebf403c_key -iv $encrypted_0c35eebf403c_iv -in deploy.key.enc -out $DEPLOY_KEY -d
chmod 400 $DEPLOY_KEY

# Decrypt configuration
function decrypt() {
  filename="$1"
  openssl enc -aes-256-cbc -pass env:SECRET_PASSWORD -d -a -in "${filename}" -out "${filename}.dec" && rm -f "${filename}" && mv "${filename}.dec" "${filename}"
} 
decrypt config/latcraft.yml

# Create artifact 
rm -rf dashboard.tgz
tar -czf dashboard.tgz ./config ./assets ./dashboards ./jobs ./public ./widgets ./config.ru ./Gemfile* ./dashing.service

# Copy artifact to remote host
scp -o StrictHostKeyChecking=no -i $DEPLOY_KEY dashboard.tgz $DEPLOY_USER@$DEPLOY_HOST:/tmp

# Deploy dashboard code
$SSH sudo mkdir -p /dashboard/config
$SSH sudo tar -zxvf /tmp/dashboard.tgz --no-same-owner -C /dashboard

# Restart service
$SSH <<EOF
  mkdir -p /var/lib/sqlite
  touch /var/lib/sqlite/latcraft.db
  echo ">>>> Stopping service"
  sudo systemctl stop dashing 
  echo ">>>> Installing bundler"
  cd /dashboard && bundler install
  echo ">>>> Enabling service"
  sudo systemctl disable dashing.service
  sudo systemctl daemon-reload
  sudo systemctl enable /dashboard/dashing.service
  sudo systemctl daemon-reload
  echo ">>>> Restarting service"
  sudo systemctl start dashing 
  echo ">>>> Sleeping"
  sleep 20
  echo ">>>> Showing logs"
  sudo journalctl -xn --no-pager -u dashing.service
  echo ">>>> Checking status"
  sudo systemctl -q is-active dashing
EOF
