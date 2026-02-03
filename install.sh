#!/bin/bash

# Server Tool - Quick Installation Script
# This script will install the Server Management & Audit Tool

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     Server Management & Audit Tool - Installer           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This installer must be run as root or with sudo${NC}"
    exit 1
fi

echo -e "${CYAN}Installing Server Management Tool...${NC}\n"

# Detect installation method
if [ -f "server" ]; then
    # Local installation
    echo -e "${GREEN}✓${NC} Found local server file"
    cp server /usr/local/bin/server
elif [ -n "$1" ]; then
    # Install from URL
    echo -e "${YELLOW}Downloading from: $1${NC}"
    curl -fsSL "$1" -o /usr/local/bin/server
else
    echo -e "${RED}Error: No server file found and no URL provided${NC}"
    echo -e "${YELLOW}Usage: $0 [URL to server file]${NC}"
    exit 1
fi

# Make executable
chmod +x /usr/local/bin/server

echo -e "${GREEN}✓${NC} Installation completed successfully!\n"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Server Management Tool is now installed!${NC}\n"
echo -e "Run the tool with: ${YELLOW}sudo server${NC}\n"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

# Ask if user wants to run it now
read -p "$(echo -e ${YELLOW}Do you want to run it now? [y/N]:${NC} )" run_now

if [[ $run_now =~ ^[Yy]$ ]]; then
    /usr/local/bin/server
fi
