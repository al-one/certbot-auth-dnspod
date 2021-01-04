#!/bin/bash

#
# Author: Alone(hi@anlo.ng)
# Create: certbot certonly --manual --preferred-challenges dns-01 --email mail@domain.com -d laravel.run -d *.laravel.run --server https://acme-v02.api.letsencrypt.org/directory --manual-auth-hook /path/to/certbot-auth-dnspod.sh
# Renew:  certbot renew --manual-auth-hook /path/to/certbot-auth-dnspod.sh
#

# https://www.dnspod.cn/console/user/security
API_TOKEN=""

USER_AGENT="AnDNS/1.0.0 (hi@anlo.ng)"
DOMAIN=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')
TXHOST=$(expr match "$CERTBOT_DOMAIN" '\(.*\)\..*\..*')
[ -z "$DOMAIN" ] && DOMAIN="$CERTBOT_DOMAIN"
[ -z "$TXHOST" ] || TXHOST="_acme-challenge.$TXHOST"
[ -z "$TXHOST" ] && TXHOST="_acme-challenge"

if [ -z "$API_TOKEN" ]; then
    [ -f $HOME/.dnspod_token_$DOMAIN ] && API_TOKEN=$(cat $HOME/.dnspod_token_$DOMAIN)
fi

if [ -z "$API_TOKEN" ]; then
    [ -f /etc/dnspod_token_$DOMAIN ] && API_TOKEN=$(cat /etc/dnspod_token_$DOMAIN)
fi

if [ -z "$API_TOKEN" ]; then
    [ -f $HOME/.dnspod_token ] && API_TOKEN=$(cat $HOME/.dnspod_token)
fi

if [ -z "$API_TOKEN" ]; then
    [ -f /etc/dnspod_token ] && API_TOKEN=$(cat /etc/dnspod_token)
fi

if [ -z "$API_TOKEN" ]; then
    API_TOKEN="$DNSPOD_TOKEN"
fi

PARAMS="login_token=$API_TOKEN&format=json"

echo "\
CERTBOT_DOMAIN: $CERTBOT_DOMAIN
DOMAIN:         $DOMAIN
TXHOST:         $TXHOST
VALIDATION:     $CERTBOT_VALIDATION"
#echo "PARAMS:         $PARAMS"

RECORD_PATH="/tmp/CERTBOT_$CERTBOT_DOMAIN"
RECORD_FILE="$RECORD_PATH/RECORD_ID_$CERTBOT_VALIDATION"

if [ "$1" = "clean" ]; then
    RECORD_ID=$(cat $RECORD_FILE)
    if [ -n "$RECORD_ID" ]; then
      APIRET=$(curl -s -X POST "https://dnsapi.cn/Record.Remove" \
          -H "User-Agent: $USER_AGENT" \
          -d "$PARAMS&domain=$DOMAIN&record_id=$RECORD_ID" \
      | python -c "import sys,json;ret=json.load(sys.stdin);print(ret.get('status',{}).get('message','error'))")
      echo "Remove Record: $RECORD_ID - $APIRET"
    fi
    rm -f $RECORD_FILE
else
    RECORD_ID=$(curl -s -X POST "https://dnsapi.cn/Record.Create" \
        -H "User-Agent: $USER_AGENT" \
        -d "$PARAMS&domain=$DOMAIN&sub_domain=$TXHOST&record_type=TXT&value=$CERTBOT_VALIDATION&record_line=默认" \
    | python -c "import sys,json;ret=json.load(sys.stdin);print(ret.get('record',{}).get('id',ret.get('status',{}).get('message','error')))")

    # Save info for cleanup
    if [ ! -d $RECORD_PATH ]; then
        mkdir -m 0700 $RECORD_PATH
    fi
    echo $RECORD_ID > $RECORD_FILE

    # Sleep to make sure the change has time to propagate over to DNS
    sleep 30
fi
