# Especificación de Infraestructura Base

Este documento detalla los cimientos técnicos y la arquitectura de sistemas sobre la cual se despliegan los servicios del ecosistema. El diseño sigue una filosofía de microservicios orquestados por Docker, priorizando la seguridad, el aislamiento y la portabilidad absoluta entre diferentes servidores.

## 1. Capa de Red (Networking)

La arquitectura utiliza un modelo de red segmentada para garantizar que los datos sensibles y la comunicación entre procesos nunca queden expuestos al tráfico externo de forma innecesaria.

| **Red** | **Driver** | **Propósito** |
| :--- | :--- | :--- |
| `internal-net` | bridge | Red aislada para comunicación de backend (Bases de datos, cache, comunicación inter-servicios). No tiene exposición directa al host. |
| `external-net` | bridge | Red de borde. Solo los servicios que actúan como Gateway o Proxy participan aquí para recibir tráfico externo. |

### Reglas de Comunicación

* **Aislamiento de Persistencia:** Los motores de base de datos residen exclusivamente en `internal-net`.
* **Descubrimiento de Servicios:** El stack utiliza el DNS interno de Docker, permitiendo la comunicación mediante el nombre del servicio (ej: `http://database:5432`).
* **Interacción con el Host:** El acceso a recursos fuera del contenedor se realiza mediante `host-gateway`, mapeado como `host.docker.internal`.

## 2. Estrategia de Persistencia (Volumes)

Se ha estandarizado el uso de **volúmenes relativos** dentro del directorio del proyecto. Esto garantiza la portabilidad "Plug & Play", permitiendo mover el ecosistema completo entre directorios o servidores sin reconfigurar rutas absolutas.

### Estructura de Datos Estandarizada

* `./data/`: Directorio raíz para todos los datos persistentes.
* `./data/[service_name]`: Subdirectorios específicos para cada componente (configuraciones, bases de datos, estados).
* `./backups/`: Directorio destinado a volcados lógicos y archivos comprimidos de recuperación.

## 3. Capa de Seguridad y Borde (Edge Layer)

La infraestructura implementa una estrategia de defensa en profundidad para proteger los servicios internos.

### Componentes de Exposición

1. **Proxy Inverso:** Actúa como único punto de entrada para tráfico HTTP/HTTPS, gestionando la terminación SSL y certificados (Let's Encrypt).
2. **Túnel Seguro (Zero Trust):** Implementación de túneles de salida para exponer servicios a internet sin necesidad de abrir puertos en el router o cortafuegos local.
   * *Requisito:* El tráfico de larga duración debe configurarse preferentemente sobre WebSockets para mantener la estabilidad de las sesiones.

## 4. Gestión de Configuración y Secretos

El sistema se rige por el principio de separación de código y configuración (Twelve-Factor App).

### El archivo de entorno (.env)

Toda la variabilidad del sistema se define en un archivo `.env` no versionado. Esto incluye:

* Credenciales de acceso a infraestructura.
* Tokens de vinculación de servicios de red.
* Claves maestras de cifrado.

## 5. Requerimientos de Hardware

Basado en el perfil de carga del stack en un entorno Z170, se definen los siguientes parámetros:

* **CPU:** Mínimo 4 núcleos físicos para evitar cuellos de botella en la gestión de redes virtuales.
* **RAM:** Arquitectura dimensionada para 16GB, con reserva del 25% para el sistema operativo.
* **Storage:** Almacenamiento SSD con soporte para altas operaciones de entrada/salida (IOPS).

---
*Documento de Arquitectura Base - Solution Architect.*