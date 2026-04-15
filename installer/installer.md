# Especificación: Instalador Interactivo (Product Wizard)

Este componente actúa como el orquestador de despliegue para la solución. Permite una configuración modular del stack, asegurando que solo los servicios necesarios se activen y que el archivo de entorno se genere con integridad técnica.

## 1. Módulos de Selección (Componentes)

El instalador permitirá activar de forma independiente los siguientes bloques:

* **Core Agent (Obligatorio):**
    * n8n-asistente (Motor de automatización)
    * PostgreSQL 16 & pgAdmin (Persistencia y gestión)
    * Redis (Cache de reconocimiento)
* **Inteligencia Artificial Local (Opcional):**
    * Ollama & Open-WebUI
* **Software Engineering / Agentes de Código (Opcional):**
    * **OpenHands / ClawCode:** Configuración del entorno de desarrollo autónomo.
* **Conectividad y Borde (Edge):**
    * Nginx Proxy Manager & Cloudflare Tunnel.

## 2. Lógica del Wizard

El script operará bajo los siguientes principios:

1.  **Detección de Hardware:** Verificación de capacidad para correr modelos de IA y contenedores de desarrollo (OpenHands requiere recursos considerables de Docker).
2.  **Inyección de Variables:** Solicitará únicamente los datos necesarios para los módulos seleccionados (ej: si no se elige Cloudflare, no pide el Token).
3.  **Generación de Manifiesto:** Compondrá el `docker-compose.yml` final utilizando una técnica de "Merge" o "Includes" para evitar servicios fantasma.

## 3. Seguridad en el Despliegue

* **Generación de Secretos:** Creación automática de `N8N_ENCRYPTION_KEY` y passwords de base de datos únicas por instalación.
* **Estructura Relativa:** Creación automática de la estructura `./data/[componente]` para garantizar portabilidad.

---
*Documento de Especificación de Componente - Installer v1.1*