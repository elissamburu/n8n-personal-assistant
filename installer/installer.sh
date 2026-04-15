#!/bin/bash

# ==============================================================================
# INSTALLER: n8n-personal-assistant (Agent-in-a-Box)
# Versión: 1.5.3 (Hardened Conflict Detection & Compose Validation)
# ==============================================================================

# Colores y Formatos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Archivos de estado
CONFIG_FILE="installer_state.json"
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

show_header() {
    clear
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${BOLD}    WIZARD DE INSTALACIÓN: AGENTE PERSONAL LOCAL    ${NC}"
    echo -e "${BLUE}====================================================${NC}"
}

explain() {
    echo -e "${BLUE}${BOLD}➤ CONTEXTO:${NC} ${YELLOW}$1${NC}"
}

check_requirements() {
    show_header
    echo -e "${BOLD}[1/6] Verificando el entorno...${NC}"
    
    if ! [ -x "$(command -v docker)" ]; then
        echo -e "${RED}❌ Error: Docker no está instalado.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker detectado.${NC}"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}! Se detectó una instalación previa ($CONFIG_FILE).${NC}"
        read -p "¿Desea cargar los datos anteriores? [s/n]: " RELOAD
    fi
    sleep 1
}

select_modules() {
    show_header
    echo -e "${BOLD}[2/6] Selección de Componentes${NC}"
    explain "Seleccioná qué 'órganos' tendrá tu agente."
    echo ""
    
    read -p "¿Instalar Inteligencia Artificial (Ollama + WebUI)? [s/n]: " INSTALL_AI
    read -p "¿Instalar Agente de Código (OpenHands / ClawCode)? [s/n]: " INSTALL_CODE
    read -p "¿Exponer a Internet (Cloudflare Tunnel)? [s/n]: " INSTALL_TUNNEL
}

configure_instance() {
    show_header
    echo -e "${BOLD}[3/6] Identidad de la Instancia (Prefijo)${NC}"
    explain "El prefijo evita conflictos. Si usás 'prod', el proyecto será 'prod-n8n-agent'."
    
    read -p "Prefijo de la instancia (ej: prod, dev, cliente1): " INSTANCE_NAME
    INSTANCE_NAME=$(echo "$INSTANCE_NAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    INSTANCE_NAME=${INSTANCE_NAME:-default}

    read -p "Puerto para n8n (Sugerido: 5678): " N8N_PORT
    N8N_PORT=${N8N_PORT:-5678}
}

configure_variables() {
    show_header
    echo -e "${BOLD}[4/6] Configuración de Identidad y Red${NC}"
    
    read -p "Dominio (ej: n8n.midominio.com): " DOMAIN
    
    echo -e "\n${BLUE}${BOLD}--- SOBRE TU EMAIL DE ADMINISTRACIÓN ---${NC}"
    echo -e "Se usará para el login de n8n, pgAdmin y certificados SSL."
    read -p "Ingresá el Email de administración: " ADMIN_EMAIL

    if [[ "$INSTALL_TUNNEL" =~ ^[Ss]$ ]]; then
        echo -e "\n${BLUE}${BOLD}--- ASISTENTE DE CLOUDFLARE ---${NC}"
        echo -e "1. Dash -> Networks -> Tunnels -> Configure -> Install Connector -> Docker."
        read -p "Pegá el Token aquí: " CF_TOKEN
    fi
}

generate_security() {
    show_header
    echo -e "${BOLD}[5/6] Generando Capa de Seguridad${NC}"
    
    explain "Generando llaves maestras únicas para la instancia con prefijo '$INSTANCE_NAME'..."
    
    if [ -f "$ENV_FILE" ]; then
        OLD_KEY=$(grep N8N_KEY_ASISTENTE "$ENV_FILE" | cut -d '=' -f2)
    fi
    N8N_KEY=${OLD_KEY:-$(openssl rand -hex 16)}
    DB_PASS=$(openssl rand -hex 12)
    PG_PASS=$(openssl rand -hex 12)

    cat <<EOF > $ENV_FILE
# --- IDENTIDAD ---
COMPOSE_PROJECT_NAME=$INSTANCE_NAME-n8n-agent
INSTANCE_PREFIX=$INSTANCE_NAME
N8N_PORT=$N8N_PORT
USER=$USER

# --- RED Y ADMIN ---
N8N_ASISTENTE_URL=$DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
PGADMIN_EMAIL=$ADMIN_EMAIL

# --- BASE DE DATOS (Postgres 16) ---
POSTGRES_USER=admin
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=n8n_db

# --- SEGURIDAD ---
PGADMIN_PASSWORD=$PG_PASS
N8N_KEY_ASISTENTE=$N8N_KEY

# --- CONECTIVIDAD ---
CLOUDFLARE_TOKEN=${CF_TOKEN:-none}

# --- MODULOS ---
INSTALL_AI=${INSTALL_AI:-n}
INSTALL_CODE=${INSTALL_CODE:-n}
EOF

    cat <<EOF > $CONFIG_FILE
{
  "instance_prefix": "$INSTANCE_NAME",
  "project_name": "$INSTANCE_NAME-n8n-agent",
  "domain": "$DOMAIN",
  "email": "$ADMIN_EMAIL",
  "port": "$N8N_PORT",
  "modules": { "ai": "$INSTALL_AI", "code": "$INSTALL_CODE", "tunnel": "$INSTALL_TUNNEL" }
}
EOF
}

finalize() {
    show_header
    echo -e "${BOLD}[6/6] Validación de Conflictos Críticos${NC}"
    
    # 1. VALIDACIÓN DEL COMPOSE (Crucial para multi-instancia)
    if [ -f "$COMPOSE_FILE" ]; then
        if grep -q "container_name:" "$COMPOSE_FILE"; then
            echo -e "${RED}${BOLD}🚨 ALERTA DE ARQUITECTURA DETECTADA:${NC}"
            echo -e "Tu archivo '$COMPOSE_FILE' tiene nombres de contenedor fijos (container_name)."
            echo -e "Esto BLOQUEA la capacidad de tener más de una instancia funcionando."
            echo -e "\n${YELLOW}Sugerencia:${NC} Borrá todas las líneas 'container_name:' del archivo."
            echo -e "Docker asignará nombres dinámicos basados en tu prefijo '$INSTANCE_NAME'.\n"
            read -p "¿Desea continuar de todos modos sabiendo que puede fallar? [s/n]: " CONTINUE_WRONG
            if [[ ! "$CONTINUE_WRONG" =~ ^[Ss]$ ]]; then exit 1; fi
        fi
    fi

    # 2. DETECCIÓN DE CONTENEDORES BLOQUEANTES
    CONFLICT_CONTAINERS=("postgres16" "n8n-asistente" "cloudflared" "nginx-proxy-manager" "postgres")
    
    echo -e "${YELLOW}Buscando procesos que ocupan los nombres reservados...${NC}"
    for container in "${CONFLICT_CONTAINERS[@]}"; do
        # Buscamos coincidencias exactas de nombre
        EXISTING_ID=$(docker ps -aq -f name="^/${container}$")
        if [ ! -z "$EXISTING_ID" ]; then
            echo -e "${RED}⚠️  CONFLICTO:${NC} El nombre de contenedor '$container' ya existe (ID: ${EXISTING_ID:0:12})."
            read -p "¿Desea ELIMINAR el contenedor antiguo '$container' para liberar el nombre? [s/n]: " RM_OLD
            if [[ "$RM_OLD" =~ ^[Ss]$ ]]; then
                docker stop "$container" >/dev/null 2>&1
                docker rm "$container" >/dev/null 2>&1
                echo -e "${GREEN}✓ Liberado.${NC}"
            fi
        fi
    done

    # Creación de carpetas
    mkdir -p volumes/{postgres_data,n8n_asistente_data,ollama_data,open_webui_data,openhands}
    sudo chown -R 1000:1000 volumes/n8n_asistente_data 2>/dev/null || true

    echo -e "\n${GREEN}✓ Configuración terminada para '$INSTANCE_NAME-n8n-agent'${NC}"
    
    read -p "¿Desea intentar ejecutar 'docker compose up -d' ahora? [s/n]: " START_NOW
    if [[ "$START_NOW" =~ ^[Ss]$ ]]; then
        docker compose up -d
    fi
}

check_requirements
select_modules
configure_instance
configure_variables
generate_security
finalize