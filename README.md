# Certbot DNS Authenticator For DNSPod

## Installing

```sh
$ wget https://raw.githubusercontent.com/al-one/certbot-auth-dnspod/master/certbot-auth-dnspod.sh
$ chmod +x certbot-auth-dnspod.sh
```

## Config

> Get Your DNSPod Token From https://www.dnspod.cn/console/user/security

```sh
$ export DNSPOD_TOKEN="your dnspod token"
```

or

```sh
$ echo "your dnspod token" > /etc/dnspod_token
```

or

```sh
$ echo "your dnspod token" > /etc/dnspod_token_$CERTBOT_DOMAIN
# echo "your dnspod token" > /etc/dnspod_token_laravel.run
```


## Usage

```sh
certbot certonly --manual --preferred-challenges dns-01 --email mail@domain.com -d laravel.run -d *.laravel.run --server https://acme-v02.api.letsencrypt.org/directory --manual-auth-hook /path/to/certbot-auth-dnspod.sh
```

or

```sh
certbot renew --manual-auth-hook /path/to/certbot-auth-dnspod.sh
```

or add crontab

```crontab
0 2 1 * * sh -c 'date "+\%Y-\%m-\%d \%H:\%M:\%S" && /usr/bin/certbot renew --manual-auth-hook /path/to/certbot-auth-dnspod.sh' >> /var/log/certbot-renew.log 2>&1
```
