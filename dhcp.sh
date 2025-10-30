#!/bin/bash
# =====================================================
# Script de configuración automática para Kea DHCP4
# Autor: Daren Vejarano (ajustado)
# Descripción:
#   Detecta la red del contenedor Docker y genera
#   el archivo kea-dhcp4.conf dinámicamente.
# =====================================================

# Detectar la interfaz activa
IFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$IFACE" ]; then
    echo "No se pudo detectar la interfaz de red."
    exit 1
fi
echo "Interfaz detectada: $IFACE"

# Detectar IP y máscara
IP_INFO=$(ip -o -f inet addr show "$IFACE" | awk '{print $4}')
if [ -z "$IP_INFO" ]; then
    echo "No se pudo detectar la IP en $IFACE."
    exit 1
fi
echo "Dirección IP detectada: $IP_INFO"

# Extraer red y máscara
NETWORK=$(ipcalc -n "$IP_INFO" | awk -F'= ' '/Network/ {print $2}')
MASK=$(echo "$NETWORK" | cut -d'/' -f2)
NETWORK_ADDR=$(echo "$NETWORK" | cut -d'/' -f1)

# Calcular gateway (la primera IP usable)
IFS=. read -r n1 n2 n3 n4 <<< "$NETWORK_ADDR"
GATEWAY="$n1.$n2.$n3.$((n4 + 1))"

# Calcular rango DHCP automáticamente
# Evita gateway (.1) y broadcast
block_size=$(( 2 ** (32 - MASK) ))
POOL_START="$n1.$n2.$n3.$((n4 + 2))"
POOL_END_OCTET=$((n4 + block_size - 2))
POOL_END="$n1.$n2.$n3.$POOL_END_OCTET"

echo "------------------------------------------"
echo "Red detectada:      $NETWORK"
echo "Gateway:            $GATEWAY"
echo "Rango DHCP:         $POOL_START - $POOL_END"
echo "------------------------------------------"

# Crear configuración Kea DHCP4
cat <<EOF > /etc/kea/kea-dhcp4.conf
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [ "$IFACE" ]
    },
    "lease-database": {
      "type": "memfile",
      "lfc-interval": 3600
    },
    "valid-lifetime": 4000,
    "renew-timer": 1000,
    "rebind-timer": 2000,
    "subnet4": [
      {
        "subnet": "$NETWORK",
        "pools": [ { "pool": "$POOL_START - $POOL_END" } ],
        "option-data": [
          { "name": "routers", "data": "$GATEWAY" },
          { "name": "domain-name-servers", "data": "8.8.8.8, 8.8.4.4" }
        ]
      }
    ],
    "control-socket": {
      "socket-type": "unix",
      "socket-name": "/run/kea/kea4-ctrl-socket"
    }
  }
}
EOF

echo "Archivo /etc/kea/kea-dhcp4.conf generado correctamente."

# Reiniciar servicio Kea
systemctl restart kea-dhcp4-server

# Comprobar estado
if systemctl is-active --quiet kea-dhcp4-server; then
    echo "Kea DHCP4 Server se ha iniciado correctamente."
else
    echo "Error al iniciar Kea DHCP4 Server. Revisa el log:"
    journalctl -u kea-dhcp4-server -n 20 --no-pager
fi
