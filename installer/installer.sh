#!/bin/bash

# ==============================================================================
# MASTER INSTALLER: n8n-personal-assistant (Agent-in-a-Box)
# Versión: 1.8.0 (Hardened Architecture & Detailed Post-Install)
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ENV_FILE=".env"

show_header() {
    clear
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${BOLD}    WIZARD DE INSTALACIÓN: AGENTE PERSONAL LOCAL    ${NC}"
    echo -e "${BLUE}====================================================${NC}"
}

show_header
echo -e "${BOLD}[1/5] Verificando Requisitos...${NC}"
[ -x "$(command -v docker)" ] || { echo -e "${RED}❌ Docker no instalado.${NC}"; exit 1; }
echo -e "${GREEN}✓ Docker detectado.${NC}"

echo -e "\n${BOLD}[2/5] Identidad de la Instancia${NC}"
read -p "Prefijo (ej: dev, prod): " INSTANCE_NAME
INSTANCE_NAME=$(echo "$INSTANCE_NAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
INSTANCE_NAME=${INSTANCE_NAME:-asistente}

read -p "Puerto para n8n (Sugerido: 5678): " N8N_PORT
N8N_PORT=${N8N_PORT:-5678}

echo -e "\n${BOLD}[3/5] Configuración de Red${NC}"
echo -e "${YELLOW}IMPORTANTE:${NC} El dominio debe estar registrado en Cloudflare y apuntar a tu IP pública."
read -p "Dominio Base (ej: trascendex.com.ar): " DOMAIN
eho -e "${YELLOW}RECOMENDACIÓN:${NC} Usa un email asociado a tu cuenta de Cloudflare para evitar problemas con el token."
read -p "Email de administración: " ADMIN_EMAIL
echo -e "${YELLOW}RECOMENDACIÓN:${NC} Ahora necesitas un tunnel desde Cloudflare."
echo -e "Ve a https://dash.cloudflare.com/ luego a Zero Trust -> Networks -> Connectors"
echo -e "Crea un nuevo tunnel, (selecciona Cloudflared) asignale un nombre (ej: server-local-tunnel) y luego genera un token."
echo -e "En Install and run a connector selecciona Docker y copia el comando completo (que incluye el token) para usarlo en la siguiente pregunta. (Solo necesitas el token, no el comando completo)."
read -p "Token de Cloudflare Tunnel: " CF_TOKEN

echo -e "\n${BOLD}[4/5] Aprovisionamiento...${NC}"
N8N_KEY=$(openssl rand -hex 16)
DB_PASS=$(openssl rand -hex 12)
PG_PASS=$(openssl rand -hex 12)

mkdir -p volumes/{postgres_data,n8n_asistente_data,ollama_data,open_webui_data,openhands,npm_data,npm_letsencrypt}
sudo chown -R 1000:1000 ./volumes/n8n_asistente_data
USER_ID=$(id -u)

cat <<EOF > $ENV_FILE
COMPOSE_PROJECT_NAME=$INSTANCE_NAME-n8n-agent
INSTANCE_PREFIX=$INSTANCE_NAME
N8N_PORT=$N8N_PORT
USER_ID=$USER_ID
USER=$USER
N8N_ASISTENTE_URL=$INSTANCE_NAME-n8n.$DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
PGADMIN_EMAIL=$ADMIN_EMAIL
POSTGRES_USER=admin
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=n8n_db
PGADMIN_PASSWORD=$PG_PASS
N8N_KEY_ASISTENTE=$N8N_KEY
CLOUDFLARE_TOKEN=$CF_TOKEN
EOF

echo -e "\n${BOLD}[5/5] Instalación Completa${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "${YELLOW}${BOLD}CREDENCIALES PARA EL ARCHIVO:${NC}"
echo -e "DB Pass:  $DB_PASS"
echo -e "pgAdmin:  $PG_PASS"
echo -e "n8n Key:  $N8N_KEY"
echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}${BOLD}PASOS CRÍTICOS POST-INSTALACIÓN:${NC}"
echo -e "${BOLD}A. CLOUDFLARE ZERO TRUST (Public Hostnames):${NC}"
echo -e "   1. n8n-$INSTANCE_NAME.$DOMAIN  --> http://proxy:80"
echo -e "   2. ia-$INSTANCE_NAME.$DOMAIN   --> http://proxy:80"
echo -e "   3. code-$INSTANCE_NAME.$DOMAIN --> http://proxy:80"
echo ""

# Obtener solo la IPv4 de la interfaz principal
MI_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)

echo -e "${BOLD}B. EN NGINX PROXY MANAGER http://$MI_IP:81:${NC}"
echo -e "   En el menú: Host -> Proxy Hosts -> ADD PROXY HOSTS"
echo -e "   1. Domain Names: n8n-$INSTANCE_NAME.$DOMAIN"
echo -e "      Forward Hostname / IP: n8n | Forward Port: 5678 | Websockets: ON"
echo ""
echo -e "   2. Domain Names: ia-$INSTANCE_NAME.$DOMAIN"
echo -e "      Forward Hostname / IP: open-webui | Forward Port: 8080 | Websockets: ON"
echo ""
echo -e "   3. Domain Names: code-$INSTANCE_NAME.$DOMAIN"
echo -e "      Forward Hostname / IP: openhands | Forward Port: 3000 | Websockets: ON"
echo -e "${BLUE}====================================================${NC}"

read -p "¿Levantar stack ahora? [s/n]: " START_NOW
[[ "$START_NOW" =~ ^[Ss]$ ]] && docker compose up -d    