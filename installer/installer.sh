#!/bin/bash

# ==============================================================================
# MASTER INSTALLER: n8n-personal-assistant (Agent-in-a-Box)
# Versión: 1.6.1 (Clean Architecture - Proactive Permissions)
# ==============================================================================

# Colores y Formatos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Archivos de configuración
ENV_FILE=".env"

show_header() {
    clear
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${BOLD}    WIZARD DE INSTALACIÓN: AGENTE PERSONAL LOCAL    ${NC}"
    echo -e "${BLUE}====================================================${NC}"
}

# 1. Requisitos
show_header
echo -e "${BOLD}[1/5] Verificando Docker...${NC}"
if ! [ -x "$(command -v docker)" ]; then
    echo -e "${RED}❌ Error: Docker no está instalado.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker detectado.${NC}"

# 2. Configuración de Instancia
echo -e "\n${BOLD}[2/5] Identidad de la Instancia${NC}"
read -p "Prefijo (ej: dev, prod, cliente1): " INSTANCE_NAME
INSTANCE_NAME=$(echo "$INSTANCE_NAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
INSTANCE_NAME=${INSTANCE_NAME:-asistente}

read -p "Puerto para n8n (Sugerido: 5678): " N8N_PORT
N8N_PORT=${N8N_PORT:-5678}

# 3. Variables de Red
echo -e "\n${BOLD}[3/5] Configuración de Red${NC}"
read -p "Dominio Base (ej: dev.trascendex.com.ar): " DOMAIN
read -p "Email de administración: " ADMIN_EMAIL
read -p "Token de Cloudflare Tunnel: " CF_TOKEN

# 4. Aprovisionamiento y Permisos (LA SOLUCIÓN AL ERROR EACCES)
echo -e "\n${BOLD}[4/5] Preparando Infraestructura y Permisos...${NC}"

# Generar contraseñas aleatorias
N8N_KEY=$(openssl rand -hex 16)
DB_PASS=$(openssl rand -hex 12)
PG_PASS=$(openssl rand -hex 12)

# Crear carpetas de volúmenes
mkdir -p volumes/{postgres_data,n8n_asistente_data,ollama_data,open_webui_data,openhands,npm_data,npm_letsencrypt}

# APLICAR PERMISOS PARA EL USUARIO NODE (UID 1000)
echo -e "Asignando permisos UID 1000 a la carpeta de n8n..."
sudo chown -R 1000:1000 ./volumes/n8n_asistente_data

# Generar archivo .env
cat <<EOF > $ENV_FILE
COMPOSE_PROJECT_NAME=$INSTANCE_NAME-n8n-agent
INSTANCE_PREFIX=$INSTANCE_NAME
N8N_PORT=$N8N_PORT
USER=$USER
N8N_ASISTENTE_URL=$DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
PGADMIN_EMAIL=$ADMIN_EMAIL
POSTGRES_USER=admin
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=n8n_db
PGADMIN_PASSWORD=$PG_PASS
N8N_KEY_ASISTENTE=$N8N_KEY
CLOUDFLARE_TOKEN=$CF_TOKEN
EOF

# 5. Despliegue
echo -e "\n${BOLD}[5/5] Finalizando...${NC}"
echo -e "${GREEN}✓ Archivo .env generado.${NC}"
echo -e "${GREEN}✓ Permisos de carpetas aplicados.${NC}"
echo ""
read -p "¿Levantar contenedores ahora? [s/n]: " START_NOW
if [[ "$START_NOW" =~ ^[Ss]$ ]]; then
    docker compose up -d
    echo -e "${GREEN}🚀 Proceso finalizado.${NC}"
else
    echo -e "${YELLOW}Listo. Iniciá manualmente con: docker compose up -d${NC}"
fi