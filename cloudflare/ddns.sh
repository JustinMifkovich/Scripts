#!/bin/bash

# A bash script to update Cloudflare DNS A records with the external IP of the source machine
# Used to provide DDNS service from anywhere
# DNS records need to be pre-created on Cloudflare

# Proxy - uncomment and provide details if using a proxy
#export https_proxy=http://<proxyuser>:<proxypassword>@<proxyip>:<proxyport>

# Cloudflare zone is the zone which holds the records
zone=mifko.co

# DNS records to be updated
#dnsrecords=(vpn.mifko.co vcenter.mifko.co desktop.mifko.co www.mifko.co mifko.co)
dnsrecords=(mifko.co)
email=jmifkovich@gmail.com
auth_key={api-key}

# Flag for Cloudflare proxy status (ALL LOWER CASE)
use_proxy=true

# Cloudflare authentication details file path
cloudflare_auth_file="./cloudflare_auth_key.txt"

# Get the Cloudflare authentication key from the file
cloudflare_auth_key=$(cat "$cloudflare_auth_file")

# Get the current external IP address
current_ip=$(curl -s -X GET https://checkip.amazonaws.com)

echo "Current IP is $current_ip"

# Loop through the DNS records and update if necessary
for dnsrecord in "${dnsrecords[@]}"; do
    if [[ "$use_proxy" != "true" ]] && [[ $(host $dnsrecord 1.1.1.1 | grep "has address" | grep "$current_ip") ]]; then
        echo "$dnsrecord is currently set to $current_ip; no changes needed"
    else
        cloudflare_zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
          -H "Authorization: Bearer $cloudflare_auth_key" \
          -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

        echo "cloudflare_zone_id: $cloudflare_zone_id"

        cloudflare_dnsrecord=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records?type=A&name=$dnsrecord" \
          -H "Authorization: Bearer $cloudflare_auth_key" \
          -H "Content-Type: application/json")

        cloudflare_dnsrecord_ip=$(echo $cloudflare_dnsrecord | jq -r '{"result"}[] | .[0] | .content')
        cloudflare_dnsrecord_proxied=$(echo $cloudflare_dnsrecord | jq -r '{"result"}[] | .[0] | .proxied')
        cloudflare_dnsrecord_id=$(echo $cloudflare_dnsrecord | jq -r '{"result"}[] | .[0] | .id')

        echo "cloudflare_dnsrecord_id:$cloudflare_dnsrecord_id"



        if [[ "$current_ip" == "$cloudflare_dnsrecord_ip" ]] && [[ "$cloudflare_dnsrecord_proxied" == "$use_proxy" ]]; then
            echo "$dnsrecord DNS record is up to date"
        else


            curl -s -Z PUT "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records/$cloudflare_dnsrecord_id" \
              -H "Authorization: Bearer $cloudflare_auth_key" \
              -H "Content-Type: application/json" \
              -H "X-Auth-Email: $email" \
              -H "X-Auth-Key: $auth_key" \
              --data "{\"type\":\"A\",\"name\":\"$dnsrecord\",\"content\":\"$current_ip\",\"ttl\":1,\"proxied\":$use_proxy}" | jq
            echo "$dnsrecord DNS record has been updated with the current IP"
        fi
    fi
done