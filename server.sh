#!/usr/bin/env bash
# ==========================================================
#  SERVER MANAGEMENT TOOLKIT
#  Version: 1.0 (Base Release)
#  Author: You
#  Compatible with: Debian 9+, Ubuntu 18+, CentOS/RHEL 7+, Rocky, AlmaLinux
# ==========================================================

# ---------- COLORS ----------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ---------- LOGO ----------
show_logo() {
clear
echo -e "${BLUE}${BOLD}"
echo "██████╗ ███████╗███████╗██╗   ██╗███████╗██████╗ "
echo "██╔══██╗██╔════╝██╔════╝██║   ██║██╔════╝██╔══██╗"
echo "██║  ██║█████╗  █████╗  ██║   ██║█████╗  ██████╔╝"
echo "██║  ██║██╔══╝  ██╔══╝  ╚██╗ ██╔╝██╔══╝  ██╔══██╗"
echo "██████╔╝███████╗██║      ╚████╔╝ ███████╗██║  ██║"
echo "╚═════╝ ╚══════╝╚═╝       ╚═══╝  ╚══════╝╚═╝  ╚═╝"
echo "       Server Management Toolkit v1.0"
echo -e "${NC}"
}

# ---------- SERVER INFO ----------
show_system_info() {
echo -e "\n${YELLOW}${BOLD}System Information${NC}"
echo "--------------------------------"

OS_INFO=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
HOSTNAME=$(hostname)
KERNEL_VERSION=$(uname -r)
UPTIME=$(uptime -p)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
TOTAL_DISK=$(df -h / | awk 'NR==2 {print $2}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
PUBLIC_IP=$(curl -s https://api.ipify.org)
LOC_INFO=$(curl -s https://ipapi.co/json | grep -E '"city"|"country_name"' | tr -d ',"')

echo -e "${BOLD}Hostname:${NC} $HOSTNAME"
echo -e "${BOLD}OS:${NC} $OS_INFO"
echo -e "${BOLD}Kernel:${NC} $KERNEL_VERSION"
echo -e "${BOLD}Uptime:${NC} $UPTIME"
echo -e "${BOLD}CPU:${NC} $CPU_MODEL ($CPU_CORES cores)"
echo -e "${BOLD}Memory:${NC} $TOTAL_MEM"
echo -e "${BOLD}Disk:${NC} $TOTAL_DISK"
echo -e "${BOLD}Load Avg:${NC} $LOAD_AVG"
echo -e "${BOLD}Public IP:${NC} $PUBLIC_IP"
echo -e "${BOLD}Location:${NC} $LOC_INFO"
}

# ---------- FUTURE FEATURES ----------
ip_cleanliness_check() {
    echo -e "\n${YELLOW}[+] IP Cleanliness & DNS Leak Check coming soon...${NC}"
}

mtu_finder_script() {
    echo -e "\n${YELLOW}[+] MTU Finder & Auto Configure coming soon...${NC}"
}

security_audit() {
    echo -e "\n${YELLOW}[+] Security & System Audit coming soon...${NC}"
}

# ---------- MENU ----------
main_menu() {
while true; do
echo -e "\n${GREEN}${BOLD}Main Menu${NC}"
echo "--------------------------------"
echo "1) IP Cleanliness & DNS Leak Check"
echo "2) MTU Finder + Auto Configure"
echo "3) Security & System Audit"
echo "4) Exit"
echo
read -p "Select an option [1-4]: " choice

case $choice in
    1) ip_cleanliness_check ;;
    2) mtu_finder_script ;;
    3) security_audit ;;
    4) echo -e "${GRAY}Exiting...${NC}"; exit 0 ;;
    *) echo -e "${RED}[!] Invalid selection${NC}" ;;
esac

done
}

# ---------- MAIN ----------
show_logo
show_system_info
main_menu
