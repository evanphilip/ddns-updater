#!/bin/bash

host="@"
domain_name="example.com"
ddns_password="adf154kjb34igkv43i8y7adsf97"


###########################################
## Check if we have a public IP
###########################################
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
if [[ ! $ret == 0 ]]; then # In the case that cloudflare failed to return an ip.
    # Attempt to get the ip from other websites.
    ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
else
    # Extract just the ip from the ip line from cloudflare.
    ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
fi

# Use regex to check for proper IPv4 format.
if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
    logger -s "DDNS Updater: Failed to find a valid public IP."
    exit 2
else
    your_ip=$ip
fi


###########################################
## Check the website's IP address
###########################################
if [[ ${your_ip} == $(</tmp/ddns_updater) ]]; then
    logger "DDNS Updater: IP (${your_ip}) for ${domain_name} has not changed as per /tmp/ddns_updater"
    exit 0
else
    website_ip=$(host -t A ${domain_name} | awk -F "address " '{print $2}')
fi

# Use regex to check for proper IPv4 format.
if [[ ! $website_ip =~ ^$ipv4_regex$ ]]; then
    logger "DDNS Updater: Failed to find a valid IP for the website."
fi


###########################################
## Change the IP using the API
###########################################
if [[ ${your_ip} == ${website_ip} ]]; then
  logger "DDNS Updater: IP (${website_ip}) for ${domain_name} has not changed."
  echo $website_ip > /tmp/ddns_updater
  exit 0
else
  logger "DDNS Updater: IP for ${domain_name} has to be updated from ${website_ip} to ${your_ip}."
  update=$(curl -s "https://dynamicdns.park-your-domain.com/update?host=$host&domain=$domain_name&password=$ddns_password&ip=$your_ip")
  ret=$(echo $update | grep "<ErrCount>0</ErrCount><errors /><ResponseCount>0</ResponseCount><responses /><Done>true</Done>"); ret=$?
  if [[ ! $ret == 0 ]]; then
      logger -s "DDNS Updater: Failed to update IP using API"
      logger "DDNS Updater: Request returned $update "
      exit 2
  else 
      logger "DDNS Updater: API update request for IP successful."
      echo $your_ip > /tmp/ddns_updater
      exit 0
  fi
fi