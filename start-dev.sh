#!/bin/bash

echo "Iniciando Streamia - Modo Desarrollo"
echo "========================================"

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================
# DETECCIÓN DE SISTEMA OPERATIVO
# ============================================
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="mac";;
        CYGWIN*|MINGW*|MSYS*) OS="windows";;
        *)          OS="unknown";;
    esac
    echo "Sistema detectado: $OS"
}

detect_os

# ============================================
# CONFIGURACIÓN DE MICROFRONTENDS
# ============================================
# Para añadir un nuevo MFE:
# 1. Agregar entrada en MFE_CONFIGS
# 2. El formato es: "nombre:carpeta:puerto"

declare -a MFE_CONFIGS=(
    "Auth MFE:auth-mfe:3001"
    "Static MFE:static-mfe:3006"
    "Comments MFE:comments-mfe:3007"
    # Ejemplo para añadir más:
    # "Movies MFE:movies-mfe:3002"
    # "Profile MFE:profile-mfe:3003"
)

SHELL_PORT=5000
SHELL_DIR="shell"

# ============================================
# FUNCIONES AUXILIARES
# ============================================

# Función para matar proceso en un puerto específico (compatible con Windows/Linux/Mac)
kill_port() {
    local port=$1
    
    if [ "$OS" = "windows" ]; then
        # Windows (Git Bash / MSYS / Cygwin)
        local pid=$(netstat -ano 2>/dev/null | grep ":$port " | grep "LISTENING" | awk '{print $5}' | head -1)
        if [ ! -z "$pid" ] && [ "$pid" != "0" ]; then
            echo "  Matando proceso en puerto $port (PID: $pid)"
            taskkill //F //PID $pid 2>/dev/null || true
        fi
    else
        # Linux / macOS
        local pid=$(lsof -ti :$port 2>/dev/null)
        if [ ! -z "$pid" ]; then
            echo "  Matando proceso en puerto $port (PID: $pid)"
            kill -9 $pid 2>/dev/null || true
        fi
    fi
}

# Función para matar procesos de vite
kill_vite_processes() {
    echo "  Matando procesos de vite..."
    if [ "$OS" = "windows" ]; then
        # Windows: matar procesos node que contengan vite
        taskkill //F //IM node.exe 2>/dev/null || true
    else
        # Linux / macOS
        pkill -f "vite" 2>/dev/null || true
    fi
}

# Función para limpiar todos los puertos
cleanup_ports() {
    echo "Limpiando procesos previos..."
    
    # Matar proceso del Shell
    kill_port $SHELL_PORT
    
    # Matar procesos de cada MFE
    for config in "${MFE_CONFIGS[@]}"; do
        IFS=':' read -r name folder port <<< "$config"
        kill_port $port
    done
    
    # Matar cualquier proceso de vite restante
    kill_vite_processes
    
    # Esperar a que los puertos se liberen
    sleep 2
}

# Función para verificar si un puerto está en uso
check_port_in_use() {
    local port=$1
    
    if [ "$OS" = "windows" ]; then
        netstat -ano 2>/dev/null | grep ":$port " | grep "LISTENING" > /dev/null 2>&1
        return $?
    else
        lsof -ti :$port > /dev/null 2>&1
        return $?
    fi
}

# Función para construir un MFE
build_mfe() {
    local name=$1
    local folder=$2
    
    echo -e "\n${BLUE}Building $name...${NC}"
    cd packages/$folder
    npm run build
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error building $folder${NC}"
        exit 1
    fi
    cd ../..
}

# Función para iniciar un MFE en preview mode
start_mfe_preview() {
    local name=$1
    local folder=$2
    local port=$3
    
    cd packages/$folder
    npm run preview > ../../logs/$folder.log 2>&1 &
    local pid=$!
    cd ../..
    echo "  $name iniciado en puerto $port (PID: $pid)"
}

# Función para verificar que un MFE esté disponible
verify_mfe() {
    local name=$1
    local port=$2
    
    if ! curl -s http://localhost:$port/assets/remoteEntry.js > /dev/null; then
        echo -e "${RED}$name no está disponible en puerto $port${NC}"
        exit 1
    fi
}

# ============================================
# INICIO DEL SCRIPT
# ============================================

# Limpiar puertos
cleanup_ports

# Limpiar builds anteriores
echo "Limpiando builds anteriores..."
rm -rf packages/$SHELL_DIR/dist
for config in "${MFE_CONFIGS[@]}"; do
    IFS=':' read -r name folder port <<< "$config"
    rm -rf packages/$folder/dist
done

# Build todos los MFEs
for config in "${MFE_CONFIGS[@]}"; do
    IFS=':' read -r name folder port <<< "$config"
    build_mfe "$name" "$folder"
done

echo -e "\n${GREEN}Builds completados${NC}"
echo -e "\n${BLUE}Iniciando servidores...${NC}\n"

# Iniciar todos los MFEs en preview mode
for config in "${MFE_CONFIGS[@]}"; do
    IFS=':' read -r name folder port <<< "$config"
    start_mfe_preview "$name" "$folder" "$port"
done

# Esperar a que los MFEs estén listos
echo "Esperando a que los microfrontends estén listos..."
sleep 3

# Verificar que todos los MFEs estén disponibles
for config in "${MFE_CONFIGS[@]}"; do
    IFS=':' read -r name folder port <<< "$config"
    verify_mfe "$name" "$port"
done

echo -e "${GREEN}Microfrontends listos${NC}"

# Iniciar Shell
echo -e "\n${BLUE}Iniciando Shell...${NC}"
cd packages/$SHELL_DIR
npm run dev > ../../logs/$SHELL_DIR.log 2>&1 &
SHELL_PID=$!
cd ../..
echo "  Shell iniciado en puerto $SHELL_PORT (PID: $SHELL_PID)"

sleep 3

# Mostrar resumen
echo -e "\n${GREEN}======================================"
echo "Streamia iniciado correctamente"
echo "======================================${NC}"
echo ""
echo "Aplicación principal: http://localhost:$SHELL_PORT"
for config in "${MFE_CONFIGS[@]}"; do
    IFS=':' read -r name folder port <<< "$config"
    printf "%-20s http://localhost:%s\n" "$name:" "$port"
done
echo ""
echo "Ver logs:"
echo "   tail -f logs/$SHELL_DIR.log"
for config in "${MFE_CONFIGS[@]}"; do
    IFS=':' read -r name folder port <<< "$config"
    echo "   tail -f logs/$folder.log"
done
echo ""
if [ "$OS" = "windows" ]; then
    echo "Para detener: taskkill //F //IM node.exe"
else
    echo "Para detener: pkill -f vite"
fi
echo ""

# Mantener el script corriendo y mostrar logs del shell
tail -f logs/shell.log
