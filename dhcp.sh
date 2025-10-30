#!/bin/bash
set -e

echo "Iniciando instalación automática de Kea DHCP..."

# --- Verificar permisos ---
if [ "$EUID" -ne 0 ]; then
  echo "Debes ejecutar este script como root o con sudo."
  exit 1
fi

# --- Actualizar e instalar dependencias ---
apt update -y
apt install -y kea-dhcp4-server kea-admin iproute2 curl jq

# --- Detectar interfaz principal ---
echo "Detectando interfaz de red..."
IFACE=$(ip route | awk '/default/ {print $5; exit}')
if [ -z "$IFACE" ]; then
  echo "No se pudo detectar la interfaz de red."
  exit 1
fi
echo "Interfaz detectada: $IFACE"

# --- Obtener IP y subred ---
IP_INFO=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2; exit}')
if [ -z "$IP_INFO" ]; then
  echo "No se pudo obtener la IP de la interfaz $IFACE"
  exit 1
fi
echo "IP y subred detectadas: $IP_INFO"

# Extraer red base y gateway
NETWORK=$(ip route | awk '/src/ {print $1; exit}')
GATEWAY=$(ip route | awk '/default/ {print $3; exit}')

# Si no detecta la red, intenta calcularla
if [ -z "$NETWORK" ]; then
  NETWORK=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2; exit}')
fi

echo "Subred detectada: $NETWORK"
echo "Gateway detectado: $GATEWAY"

# --- Crear directorios ---
mkdir -p /etc/kea /var/log/kea
touch /var/log/kea/kea-dhcp4.log

# --- Generar archivo de configuración dinámico ---
echo "Creando configuración /etc/kea/kea-dhcp4.conf..."

# Derivar rango DHCP automáticamente (últimos 100 IPs)
IFS='./' read -r a b c d mask <<<"${NETWORK//\// }"
POOL_START="${a}.${b}.${c}.$((d + 100))"
POOL_END="${a}.${b}.${c}.$((d + 200))"

cat > /etc/kea/kea-dhcp4.conf <<EOF
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
        "loggers": [
            {
                "name": "kea-dhcp4",
                "output_options": [
                    {
                        "output": "/var/log/kea/kea-dhcp4.log",
                        "maxsize": 1048576,
                        "maxver": 5
                    }
                ],
                "severity": "INFO"
            }
        ]
    }
}
EOF

# --- Permisos ---
chmod 644 /etc/kea/kea-dhcp4.conf
chown -R _kea:_kea /etc/kea /var/log/kea

# --- Habilitar y arrancar servicio ---
systemctl enable kea-dhcp4-server
systemctl restart kea-dhcp4-server

sleep 2

if systemctl is-active --quiet kea-dhcp4-server; then
  echo "Kea DHCP configurado y ejecutándose correctamente."
else
  echo "Error al iniciar Kea DHCP. Revisa con:"
  echo "journalctl -u kea-dhcp4-server -e"
fi

echo
echo "Archivo de configuración: /etc/kea/kea-dhcp4.conf"
echo "Logs: /var/log/kea/kea-dhcp4.log"
echo "Red detectada: $NETWORK"
echo "Instalación finalizada."
