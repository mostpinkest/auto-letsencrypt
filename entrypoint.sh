#!/bin/bash

trap "exit" SIGHUP SIGINT SIGTERM

if [ -z "$DOMAINS" ] ; then
  echo "No domains set, please fill -e 'DOMAINS=example.com www.example.com'"
  exit 1
fi

if [ -z "$EMAIL" ] ; then
  echo "No email set, please fill -e 'EMAIL=your@email.tld'"
  exit 1
fi

DOMAINS=(${DOMAINS})
CERTBOT_DOMAINS=("${DOMAINS[*]/#/--domain }")
CHECK_FREQ="${CHECK_FREQ:-30}"
WEBROOT_PATH="${WEBROOT_PATH:-"/var/www"}"
CLOUDFLARE_PROPAGATION_SECONDS="${CHECK_FREQ:-10}"

check() {
  echo "* Starting webroot initial certificate request script..."

  if [ "$CLOUDFLARE_CREDENTIAL" ]; then
    OPTIONS="--dns-cloudflare \
    --dns-cloudflare-credentials $CLOUDFLARE_CREDENTIAL \
    --dns-cloudflare-propagation-seconds $CLOUDFLARE_PROPAGATION_SECONDS"
  else
    OPTIONS="--webroot --webroot-path ${WEBROOT_PATH}"
  fi

  certbot certonly --agree-tos --noninteractive --text --expand \
      --email ${EMAIL} \
      ${OPTIONS} \
      ${CERTBOT_DOMAINS}

  echo "* Certificate request process finished for domain $DOMAINS"

  if [ "$CERTS_PATH" ]; then
    echo "* Copying certificates to $CERTS_PATH"
    eval cp -LR /etc/letsencrypt/live/* $CERTS_PATH/
  fi

  if [ "$SERVER_CONTAINER" ]; then
    echo "* Reloading server configuration in containers: $SERVER_CONTAINER"
    eval docker kill -s HUP $SERVER_CONTAINER
  fi

  if [ "$SERVER_CONTAINER_LABEL" ]; then
    echo "* Reloading server configuration for label: $SERVER_CONTAINER_LABEL"

    container_id=`docker ps --filter label=$SERVER_CONTAINER_LABEL -q`
    eval docker kill -s HUP $container_id
  fi

  echo "* Next check in $CHECK_FREQ days"
  sleep ${CHECK_FREQ}d
  check
}

check
