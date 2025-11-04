#!/bin/bash
# Purpose: Config ubuntu DHCP server
# https://ubuntu.com/server/docs/network-dhcp
# Author: Jose Maria Madronal GPL v2.0+
# ------------------------------------------
#
#
# declare STRING variable
STRING="Scripts examples"
f_dchpd_conf="https://raw.githubusercontent.com/AlexGomila/dhcp/refs/heads/main/kea-dhcp4.conf"
#print variable on a screen
echo $STRING

#Install DHCP
apt-get install kea
rm  /etc/kea/kea-dhcp4.conf
# download githup configuration file
wget $f_dchpd_conf

# copy configuration file to etc directory
cp kea-dhcp4.conf /etc/kea

systemctl restart kea-dhcp4-server
systemctl status kea-dhcp4-server
