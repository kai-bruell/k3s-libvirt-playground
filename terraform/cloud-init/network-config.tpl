version: 2
ethernets:
  default:
    match:
      name: "e*"
    dhcp4: false
    dhcp6: false
    addresses:
      - ${ip_address}/${netmask}
    routes:
      - to: default
        via: ${gateway}
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
