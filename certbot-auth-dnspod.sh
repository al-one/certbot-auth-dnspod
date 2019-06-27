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

if [ -f /tmp/CERTBOT_$CERTBOT_DOMAIN/VALIDATION ]; then
    VALIDATION_PRE=$(cat /tmp/CERTBOT_$CERTBOT_DOMAIN/VALIDATION)
    if [ "$CERTBOT_VALIDATION" = "$VALIDATION_PRE" ]; then
        echo "Same Validation: $CERTBOT_VALIDATION"
        exit
    fi
fi

RECORDS=$(curl -s -X POST "https://dnsapi.cn/Record.List" \
    -H "User-Agent: $USER_AGENT" \
    -d "$PARAMS&domain=$DOMAIN&keyword=$TXHOST" \
| python -c "import sys,json;ret=json.load(sys.stdin);print(ret.get('records',[{}])[0].get('id',''))")

echo "\
RECORDS:        $RECORDS"

sleep 3

if [ -n "$RECORDS" ]; then
    RECORD_ID="$RECORDS"
    RECORD_ID=$(curl -s -X POST "https://dnsapi.cn/Record.Modify" \
        -H "User-Agent: $USER_AGENT" \
        -d "$PARAMS&domain=$DOMAIN&sub_domain=$TXHOST&record_type=TXT&value=$CERTBOT_VALIDATION&record_line=默认&record_id=$RECORD_ID" \
    | python -c "import sys,json;ret=json.load(sys.stdin);print(ret.get('record',{}).get('id',ret.get('status',{}).get('message','error')))")
else
    RECORD_ID=$(curl -s -X POST "https://dnsapi.cn/Record.Create" \
        -H "User-Agent: $USER_AGENT" \
        -d "$PARAMS&domain=$DOMAIN&sub_domain=$TXHOST&record_type=TXT&value=$CERTBOT_VALIDATION&record_line=默认" \
    | python -c "import sys,json;ret=json.load(sys.stdin);print(ret.get('record',{}).get('id',ret.get('status',{}).get('message','error')))")
fi

echo "\
RECORD_ID:      $RECORD_ID"

# Save info for cleanup
if [ ! -d /tmp/CERTBOT_$CERTBOT_DOMAIN ]; then
    mkdir -m 0700 /tmp/CERTBOT_$CERTBOT_DOMAIN
fi
echo $DOMAIN > /tmp/CERTBOT_$CERTBOT_DOMAIN/DOMAIN
echo $RECORD_ID > /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID
echo $CERTBOT_VALIDATION > /tmp/CERTBOT_$CERTBOT_DOMAIN/VALIDATION

# Sleep to make sure the change has time to propagate over to DNS
sleep 30