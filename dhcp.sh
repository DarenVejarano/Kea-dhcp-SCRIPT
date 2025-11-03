#!/bin/bash
set -e

echo "[INFO] Instalando servidor DHCP..."
apt update && apt install -y isc-dhcp-server

IFACE="eth0"
echo "[INFO] Configurando interfaz DHCP en $IFACE..."
sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$IFACE\"/" /etc/default/isc-dhcp-server

echo "[INFO] Creando configuración DHCP..."
cat > /etc/dhcp/dhcpd.conf <<EOF
option domain-name "local";
option domain-name-servers 8.8.8.8, 1.1.1.1;
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 10.18.41.0 netmask 255.255.255.224 {
  range 10.18.41.10 10.18.41.25;
  option routers 10.18.41.1;
  option broadcast-address 10.18.41.31;
}
EOF

echo "[INFO] Reiniciando servicio DHCP..."
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server

echo "[OK] Servidor DHCP activo en $(hostname -I | awk '{print $1}')"
