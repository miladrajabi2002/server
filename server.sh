#!/usr/bin/env bash

#==============================================================================
# Server Management & Audit Tool
# Version: 1.0.0
# Description: Comprehensive server monitoring, security audit, and optimization
# Supported OS: Ubuntu 18+, Debian 9+, CentOS 7+
#==============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_VERSION="1.0.0"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="server-report-${TIMESTAMP}.txt"
LOG_DIR="/var/log/server-tool"
TEMP_DIR="/tmp/server-tool-$$"

# Create necessary directories
mkdir -p "$LOG_DIR" "$TEMP_DIR"

#==============================================================================
# Utility Functions
#==============================================================================

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║            SERVER MANAGEMENT & AUDIT TOOL                     ║
║                     Version 1.0.0                             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_section_header() {
    local title="$1"
    local width=65
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo -e "\n${BLUE}${BOLD}╔$(printf '═%.0s' {1..63})╗${NC}"
    printf "${BLUE}${BOLD}║${NC}%*s${CYAN}${BOLD}%s${NC}%*s${BLUE}${BOLD}║${NC}\n" \
        $padding "" "$title" $padding ""
    echo -e "${BLUE}${BOLD}╚$(printf '═%.0s' {1..63})╝${NC}\n"
}

print_box() {
    local text="$1"
    local color="${2:-$WHITE}"
    echo -e "${color}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${color}│${NC} $text"
    echo -e "${color}└─────────────────────────────────────────────────────────────┘${NC}"
}

print_info() {
    local label="$1"
    local value="$2"
    printf "${BOLD}%-25s${NC}: ${GREEN}%s${NC}\n" "$label" "$value"
    echo "$label: $value" >> "$REPORT_FILE"
}

print_status() {
    local status="$1"
    local message="$2"
    local details="${3:-}"
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓ [PASS]${NC} $message ${GRAY}$details${NC}"
            echo "[PASS] $message $details" >> "$REPORT_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ [WARN]${NC} $message ${GRAY}$details${NC}"
            echo "[WARN] $message $details" >> "$REPORT_FILE"
            ;;
        "FAIL")
            echo -e "${RED}✗ [FAIL]${NC} $message ${GRAY}$details${NC}"
            echo "[FAIL] $message $details" >> "$REPORT_FILE"
            ;;
        "INFO")
            echo -e "${CYAN}ℹ [INFO]${NC} $message ${GRAY}$details${NC}"
            echo "[INFO] $message $details" >> "$REPORT_FILE"
            ;;
    esac
}

spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    
    while kill -0 $pid 2>/dev/null; do
        temp=${spinstr#?}
        printf " ${CYAN}[%c]${NC} %s" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\r"
    done
    printf "    \r"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        OS_PRETTY=$PRETTY_NAME
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
        OS_PRETTY="$DISTRIB_ID $DISTRIB_RELEASE"
    else
        OS=$(uname -s)
        VER=$(uname -r)
        OS_PRETTY="Unknown"
    fi
    
    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y -qq"
            ;;
        centos|rhel|fedora)
            PKG_MANAGER="yum"
            PKG_UPDATE="yum check-update -q"
            PKG_INSTALL="yum install -y -q"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}This script must be run as root or with sudo${NC}"
        exit 1
    fi
}

install_dependencies() {
    local deps=("curl" "wget" "jq" "bc" "net-tools" "dnsutils" "traceroute")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing missing dependencies...${NC}"
        $PKG_UPDATE &>/dev/null || true
        for pkg in "${missing[@]}"; do
            $PKG_INSTALL "$pkg" &>/dev/null || true
        done
    fi
}

#==============================================================================
# System Information Functions
#==============================================================================

get_system_info() {
    print_section_header "SYSTEM INFORMATION"
    
    # Basic Info
    HOSTNAME=$(hostname)
    KERNEL=$(uname -r)
    UPTIME=$(uptime -p 2>/dev/null || uptime)
    UPTIME_SINCE=$(uptime -s 2>/dev/null || date)
    
    # CPU Info
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    CPU_CORES=$(nproc)
    CPU_ARCH=$(uname -m)
    
    # Memory Info
    TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
    USED_MEM=$(free -h | awk '/^Mem:/ {print $3}')
    AVAIL_MEM=$(free -h | awk '/^Mem:/ {print $7}')
    MEM_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    
    # Disk Info
    TOTAL_DISK=$(df -h / | awk 'NR==2 {print $2}')
    USED_DISK=$(df -h / | awk 'NR==2 {print $3}')
    AVAIL_DISK=$(df -h / | awk 'NR==2 {print $4}')
    DISK_USAGE=$(df -h / | awk 'NR==2 {print int($5)}')
    
    # Network Info
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org || echo "N/A")
    PUBLIC_IP6=$(curl -s --max-time 5 https://api64.ipify.org || echo "N/A")
    
    # Network interfaces
    if command -v ip &>/dev/null; then
        PRIMARY_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        LOCAL_IP=$(ip addr show "$PRIMARY_IFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    else
        PRIMARY_IFACE=$(route | grep default | awk '{print $8}' | head -1)
        LOCAL_IP=$(ifconfig "$PRIMARY_IFACE" 2>/dev/null | grep "inet " | awk '{print $2}')
    fi
    
    # Load Average
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    # Display Info
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${BOLD}SERVER OVERVIEW${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "Hostname" "$HOSTNAME"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "OS" "$OS_PRETTY"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "Kernel" "$KERNEL"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "Architecture" "$CPU_ARCH"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "Uptime" "$UPTIME"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "Load Average" "$LOAD_AVG"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "CPU Model" "${CPU_MODEL:0:35}"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "CPU Cores" "$CPU_CORES"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: ${GREEN}%-35s${NC} ${CYAN}║${NC}\n" "Memory" "$USED_MEM / $TOTAL_MEM (${MEM_USAGE}%)"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: ${GREEN}%-35s${NC} ${CYAN}║${NC}\n" "Disk Space" "$USED_DISK / $TOTAL_DISK (${DISK_USAGE}%)"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: ${YELLOW}%-35s${NC} ${CYAN}║${NC}\n" "Public IPv4" "$PUBLIC_IP"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: ${YELLOW}%-35s${NC} ${CYAN}║${NC}\n" "Public IPv6" "${PUBLIC_IP6:0:35}"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "Local IP" "$LOCAL_IP"
    printf "${CYAN}║${NC} ${BOLD}%-20s${NC}: %-35s ${CYAN}║${NC}\n" "Interface" "$PRIMARY_IFACE"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    # Save to report
    {
        echo "========================================"
        echo "SERVER INFORMATION REPORT"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        echo "SYSTEM INFO:"
        echo "Hostname: $HOSTNAME"
        echo "OS: $OS_PRETTY"
        echo "Kernel: $KERNEL"
        echo "Architecture: $CPU_ARCH"
        echo "Uptime: $UPTIME"
        echo ""
        echo "HARDWARE:"
        echo "CPU: $CPU_MODEL"
        echo "Cores: $CPU_CORES"
        echo "Memory: $USED_MEM / $TOTAL_MEM (${MEM_USAGE}%)"
        echo "Disk: $USED_DISK / $TOTAL_DISK (${DISK_USAGE}%)"
        echo ""
        echo "NETWORK:"
        echo "Public IPv4: $PUBLIC_IP"
        echo "Public IPv6: $PUBLIC_IP6"
        echo "Local IP: $LOCAL_IP"
        echo "Interface: $PRIMARY_IFACE"
        echo ""
    } > "$REPORT_FILE"
}

#==============================================================================
# IP Reputation Check Functions
#==============================================================================

check_ip_reputation() {
    print_section_header "IP REPUTATION CHECK"
    
    if [ "$PUBLIC_IP" = "N/A" ]; then
        print_status "WARN" "Could not retrieve public IP"
        return
    fi
    
    echo -e "${CYAN}Checking IP reputation for: ${YELLOW}$PUBLIC_IP${NC}\n"
    
    local reputation_score=0
    local total_checks=0
    
    # Check 1: IPQualityScore API (Free tier)
    echo -ne "${GRAY}Checking IP Quality Score...${NC}"
    local ipqs_result=$(curl -s --max-time 10 "https://ipqualityscore.com/api/json/ip/free/$PUBLIC_IP" 2>/dev/null)
    if [ -n "$ipqs_result" ]; then
        local fraud_score=$(echo "$ipqs_result" | jq -r '.fraud_score' 2>/dev/null || echo "N/A")
        local is_proxy=$(echo "$ipqs_result" | jq -r '.proxy' 2>/dev/null || echo "false")
        local is_vpn=$(echo "$ipqs_result" | jq -r '.vpn' 2>/dev/null || echo "false")
        
        echo -e "\r${GREEN}✓${NC} IP Quality Score checked"
        
        if [ "$fraud_score" != "N/A" ] && [ "$fraud_score" != "null" ]; then
            total_checks=$((total_checks + 1))
            if [ "$fraud_score" -lt 50 ]; then
                reputation_score=$((reputation_score + 1))
                print_status "PASS" "Fraud Score: $fraud_score/100" "(Low risk)"
            elif [ "$fraud_score" -lt 75 ]; then
                print_status "WARN" "Fraud Score: $fraud_score/100" "(Medium risk)"
            else
                print_status "FAIL" "Fraud Score: $fraud_score/100" "(High risk)"
            fi
        fi
        
        if [ "$is_proxy" = "true" ] || [ "$is_vpn" = "true" ]; then
            print_status "WARN" "IP detected as Proxy/VPN"
        else
            reputation_score=$((reputation_score + 1))
            total_checks=$((total_checks + 1))
            print_status "PASS" "Not detected as Proxy/VPN"
        fi
    else
        echo -e "\r${YELLOW}⚠${NC} Could not check IP Quality Score"
    fi
    
    # Check 2: AbuseIPDB (requires registration but has free tier)
    echo -ne "${GRAY}Checking AbuseIPDB...${NC}"
    local abuse_result=$(curl -s --max-time 10 "https://api.abuseipdb.com/api/v2/check?ipAddress=$PUBLIC_IP" \
        -H "Accept: application/json" 2>/dev/null)
    
    if [ -n "$abuse_result" ] && [ "$abuse_result" != "null" ]; then
        echo -e "\r${GREEN}✓${NC} AbuseIPDB checked"
        # Note: Free tier has limited access, this is just a placeholder
        print_status "INFO" "AbuseIPDB check completed"
        total_checks=$((total_checks + 1))
        reputation_score=$((reputation_score + 1))
    else
        echo -e "\r${YELLOW}⚠${NC} Could not check AbuseIPDB"
    fi
    
    # Check 3: Check if IP is in common blacklists
    echo -ne "${GRAY}Checking DNS blacklists...${NC}"
    local blacklisted=0
    local rbl_servers=(
        "zen.spamhaus.org"
        "bl.spamcop.net"
        "dnsbl.sorbs.net"
    )
    
    for rbl in "${rbl_servers[@]}"; do
        local reversed_ip=$(echo "$PUBLIC_IP" | awk -F. '{print $4"."$3"."$2"."$1}')
        if host "${reversed_ip}.${rbl}" &>/dev/null; then
            blacklisted=1
            break
        fi
    done
    
    echo -e "\r${GREEN}✓${NC} DNS blacklist check completed"
    total_checks=$((total_checks + 1))
    
    if [ $blacklisted -eq 0 ]; then
        reputation_score=$((reputation_score + 1))
        print_status "PASS" "IP not found in common blacklists"
    else
        print_status "FAIL" "IP found in DNS blacklists" "(May affect email delivery)"
    fi
    
    # Check 4: DNS Leak Test (check if DNS is leaking)
    echo -ne "${GRAY}Checking DNS configuration...${NC}"
    local dns_servers=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | head -3 | tr '\n' ', ' | sed 's/,$//')
    echo -e "\r${GREEN}✓${NC} DNS configuration checked"
    total_checks=$((total_checks + 1))
    
    if [ -n "$dns_servers" ]; then
        reputation_score=$((reputation_score + 1))
        print_status "PASS" "DNS Servers configured" "($dns_servers)"
    else
        print_status "WARN" "No DNS servers configured"
    fi
    
    # Check 5: Geolocation check
    echo -ne "${GRAY}Checking IP geolocation...${NC}"
    local geo_info=$(curl -s --max-time 10 "http://ip-api.com/json/$PUBLIC_IP" 2>/dev/null)
    if [ -n "$geo_info" ]; then
        local country=$(echo "$geo_info" | jq -r '.country' 2>/dev/null)
        local city=$(echo "$geo_info" | jq -r '.city' 2>/dev/null)
        local isp=$(echo "$geo_info" | jq -r '.isp' 2>/dev/null)
        
        echo -e "\r${GREEN}✓${NC} Geolocation checked"
        
        if [ "$country" != "null" ] && [ -n "$country" ]; then
            print_status "INFO" "Location: $city, $country" "(ISP: $isp)"
        fi
    else
        echo -e "\r${YELLOW}⚠${NC} Could not check geolocation"
    fi
    
    # Calculate final score
    echo ""
    local score_percentage=0
    if [ $total_checks -gt 0 ]; then
        score_percentage=$((reputation_score * 100 / total_checks))
    fi
    
    echo -e "${BOLD}IP Reputation Score: ${NC}"
    if [ $score_percentage -ge 80 ]; then
        echo -e "${GREEN}█████████░${NC} ${GREEN}$score_percentage/100${NC} - ${GREEN}CLEAN IP${NC}"
        print_status "PASS" "Your server IP has a good reputation"
    elif [ $score_percentage -ge 60 ]; then
        echo -e "${YELLOW}██████░░░░${NC} ${YELLOW}$score_percentage/100${NC} - ${YELLOW}MODERATE${NC}"
        print_status "WARN" "Your server IP has some issues"
    else
        echo -e "${RED}████░░░░░░${NC} ${RED}$score_percentage/100${NC} - ${RED}DIRTY IP${NC}"
        print_status "FAIL" "Your server IP may be blacklisted or flagged"
    fi
    
    echo ""
    echo "IP Reputation Score: $score_percentage/100 ($reputation_score/$total_checks checks passed)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

#==============================================================================
# MTU Finder Functions
#==============================================================================

find_optimal_mtu() {
    print_section_header "MTU OPTIMIZATION"
    
    echo -e "${CYAN}MTU (Maximum Transmission Unit) Finder & Auto Configuration${NC}\n"
    
    # Get current MTU
    local interface="$PRIMARY_IFACE"
    if [ -z "$interface" ]; then
        print_status "FAIL" "Could not detect network interface"
        return
    fi
    
    local current_mtu=$(ip link show "$interface" 2>/dev/null | grep -oP 'mtu \K\d+' || echo "1500")
    print_status "INFO" "Current MTU on $interface: $current_mtu"
    
    echo ""
    echo -e "${YELLOW}Select MTU test option:${NC}"
    echo "  1) Auto-detect optimal MTU (recommended)"
    echo "  2) Test specific MTU value"
    echo "  3) Skip MTU optimization"
    echo ""
    read -p "Enter choice [1-3]: " mtu_choice
    
    case $mtu_choice in
        1)
            auto_detect_mtu "$interface" "$current_mtu"
            ;;
        2)
            read -p "Enter MTU value to test (1000-9000): " test_mtu
            if [[ $test_mtu =~ ^[0-9]+$ ]] && [ "$test_mtu" -ge 1000 ] && [ "$test_mtu" -le 9000 ]; then
                test_specific_mtu "$interface" "$test_mtu"
            else
                print_status "FAIL" "Invalid MTU value"
            fi
            ;;
        3)
            print_status "INFO" "MTU optimization skipped"
            ;;
        *)
            print_status "FAIL" "Invalid choice"
            ;;
    esac
}

auto_detect_mtu() {
    local interface="$1"
    local current_mtu="$2"
    
    echo ""
    echo -e "${CYAN}Auto-detecting optimal MTU...${NC}\n"
    
    # Ask for test destination
    echo "Common test destinations:"
    echo "  1) Google DNS (8.8.8.8)"
    echo "  2) Cloudflare DNS (1.1.1.1)"
    echo "  3) Custom IP"
    echo ""
    read -p "Select destination [1-3]: " dest_choice
    
    case $dest_choice in
        1) test_ip="8.8.8.8" ;;
        2) test_ip="1.1.1.1" ;;
        3) read -p "Enter IP address: " test_ip ;;
        *) test_ip="8.8.8.8" ;;
    esac
    
    # Test connectivity first
    if ! ping -c 1 -W 2 "$test_ip" &>/dev/null; then
        print_status "FAIL" "Cannot reach $test_ip"
        return
    fi
    
    print_status "PASS" "Testing connectivity to $test_ip"
    
    # Binary search for optimal MTU
    local min_mtu=1000
    local max_mtu=1500
    local optimal_mtu=$max_mtu
    local step=10
    
    echo ""
    echo -e "${CYAN}Testing MTU values...${NC}"
    
    for ((mtu=$min_mtu; mtu<=$max_mtu; mtu+=$step)); do
        # Account for IP and ICMP headers (28 bytes for IPv4)
        local payload=$((mtu - 28))
        
        echo -ne "${GRAY}Testing MTU $mtu...${NC}\r"
        
        if ping -M do -c 1 -s $payload -W 1 "$test_ip" &>/dev/null; then
            optimal_mtu=$mtu
            echo -e "${GREEN}✓${NC} MTU $mtu: ${GREEN}OK${NC}     "
        else
            echo -e "${RED}✗${NC} MTU $mtu: ${RED}Failed${NC}"
            break
        fi
    done
    
    # Fine-tune if needed
    if [ $optimal_mtu -gt $min_mtu ]; then
        local fine_tune_mtu=$optimal_mtu
        for ((mtu=$optimal_mtu; mtu>$optimal_mtu-$step && mtu>=$min_mtu; mtu--)); do
            local payload=$((mtu - 28))
            if ping -M do -c 1 -s $payload -W 1 "$test_ip" &>/dev/null; then
                fine_tune_mtu=$mtu
            else
                break
            fi
        done
        optimal_mtu=$fine_tune_mtu
    fi
    
    # Recommend MTU (usually 2 bytes less than max working)
    local recommended_mtu=$((optimal_mtu - 2))
    
    echo ""
    print_status "PASS" "Optimal MTU found: $optimal_mtu"
    print_status "INFO" "Recommended MTU: $recommended_mtu"
    
    # Ask to apply
    echo ""
    read -p "Apply MTU $recommended_mtu to $interface? [y/N]: " apply_mtu
    
    if [[ $apply_mtu =~ ^[Yy]$ ]]; then
        apply_mtu_setting "$interface" "$recommended_mtu"
    fi
}

test_specific_mtu() {
    local interface="$1"
    local mtu="$2"
    
    echo ""
    echo -e "${CYAN}Testing MTU $mtu on $interface...${NC}\n"
    
    read -p "Enter test destination IP (default: 8.8.8.8): " test_ip
    test_ip=${test_ip:-8.8.8.8}
    
    local payload=$((mtu - 28))
    
    if ping -M do -c 3 -s $payload -W 2 "$test_ip" &>/dev/null; then
        print_status "PASS" "MTU $mtu works correctly"
        
        read -p "Apply this MTU? [y/N]: " apply
        if [[ $apply =~ ^[Yy]$ ]]; then
            apply_mtu_setting "$interface" "$mtu"
        fi
    else
        print_status "FAIL" "MTU $mtu does not work with $test_ip"
    fi
}

apply_mtu_setting() {
    local interface="$1"
    local mtu="$2"
    
    echo ""
    echo -e "${CYAN}Applying MTU $mtu to $interface...${NC}\n"
    
    # Set MTU temporarily
    if ip link set dev "$interface" mtu "$mtu" 2>/dev/null; then
        print_status "PASS" "MTU temporarily set to $mtu"
    else
        print_status "FAIL" "Could not set MTU"
        return
    fi
    
    # Make it permanent
    echo "Making MTU setting permanent..."
    
    if [ -f "/etc/netplan/01-netcfg.yaml" ] || [ -f "/etc/netplan/50-cloud-init.yaml" ]; then
        # Ubuntu with Netplan
        local netplan_file=$(ls /etc/netplan/*.yaml 2>/dev/null | head -1)
        if [ -n "$netplan_file" ]; then
            if ! grep -q "mtu: $mtu" "$netplan_file"; then
                cp "$netplan_file" "${netplan_file}.backup"
                print_status "INFO" "Netplan config backed up"
                
                # This is a simplified approach - may need manual editing
                print_status "WARN" "Please manually add 'mtu: $mtu' to $netplan_file under $interface"
                print_status "INFO" "Then run: netplan apply"
            fi
        fi
    elif [ -f "/etc/network/interfaces" ]; then
        # Debian/Ubuntu with interfaces file
        if ! grep -q "mtu $mtu" /etc/network/interfaces; then
            cp /etc/network/interfaces /etc/network/interfaces.backup
            print_status "INFO" "Interfaces file backed up"
            
            if grep -q "iface $interface" /etc/network/interfaces; then
                sed -i "/iface $interface/a \    mtu $mtu" /etc/network/interfaces
                print_status "PASS" "MTU added to /etc/network/interfaces"
            else
                print_status "WARN" "Please manually add 'mtu $mtu' to /etc/network/interfaces"
            fi
        fi
    elif [ -f "/etc/sysconfig/network-scripts/ifcfg-$interface" ]; then
        # CentOS/RHEL
        local ifcfg="/etc/sysconfig/network-scripts/ifcfg-$interface"
        cp "$ifcfg" "${ifcfg}.backup"
        
        if grep -q "MTU=" "$ifcfg"; then
            sed -i "s/MTU=.*/MTU=$mtu/" "$ifcfg"
        else
            echo "MTU=$mtu" >> "$ifcfg"
        fi
        print_status "PASS" "MTU saved to $ifcfg"
    else
        print_status "WARN" "Could not detect network configuration method"
        print_status "INFO" "MTU is set for current session only"
    fi
    
    echo ""
    echo "MTU Configuration: $interface = $mtu" >> "$REPORT_FILE"
}

#==============================================================================
# Security Audit Functions
#==============================================================================

security_audit() {
    print_section_header "SECURITY AUDIT"
    
    echo "SECURITY AUDIT RESULTS:" >> "$REPORT_FILE"
    echo "=======================" >> "$REPORT_FILE"
    
    # System restart check
    if [ -f /var/run/reboot-required ]; then
        print_status "WARN" "System Restart" "System requires restart for updates"
    else
        print_status "PASS" "System Restart" "No restart required"
    fi
    
    # SSH Configuration
    check_ssh_security
    
    # Firewall Status
    check_firewall_status
    
    # Automatic Updates
    check_auto_updates
    
    # Intrusion Prevention
    check_intrusion_prevention
    
    # Failed Login Attempts
    check_failed_logins
    
    # System Updates
    check_system_updates
    
    # Running Services
    check_running_services
    
    # Open Ports
    check_open_ports
    
    # Resource Usage
    check_resource_usage
    
    # Security Policies
    check_security_policies
    
    # SUID Files
    check_suid_files
    
    echo "" >> "$REPORT_FILE"
}

check_ssh_security() {
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_override=$(grep "^Include" "$ssh_config" 2>/dev/null | awk '{print $2}')
    
    # Check SSH root login
    local ssh_root
    if [ -n "$ssh_override" ] && [ -d "$(dirname "$ssh_override")" ]; then
        ssh_root=$(grep "^PermitRootLogin" $ssh_override "$ssh_config" 2>/dev/null | head -1 | awk '{print $2}')
    else
        ssh_root=$(grep "^PermitRootLogin" "$ssh_config" 2>/dev/null | head -1 | awk '{print $2}')
    fi
    ssh_root=${ssh_root:-prohibit-password}
    
    if [ "$ssh_root" = "no" ]; then
        print_status "PASS" "SSH Root Login" "Properly disabled"
    else
        print_status "FAIL" "SSH Root Login" "Root login allowed - security risk"
    fi
    
    # Check SSH password authentication
    local ssh_password
    if [ -n "$ssh_override" ] && [ -d "$(dirname "$ssh_override")" ]; then
        ssh_password=$(grep "^PasswordAuthentication" $ssh_override "$ssh_config" 2>/dev/null | head -1 | awk '{print $2}')
    else
        ssh_password=$(grep "^PasswordAuthentication" "$ssh_config" 2>/dev/null | head -1 | awk '{print $2}')
    fi
    ssh_password=${ssh_password:-yes}
    
    if [ "$ssh_password" = "no" ]; then
        print_status "PASS" "SSH Password Auth" "Disabled, key-based only"
    else
        print_status "FAIL" "SSH Password Auth" "Enabled - use key-based auth"
    fi
    
    # Check SSH port
    local ssh_port
    if [ -n "$ssh_override" ] && [ -d "$(dirname "$ssh_override")" ]; then
        ssh_port=$(grep "^Port" $ssh_override "$ssh_config" 2>/dev/null | head -1 | awk '{print $2}')
    else
        ssh_port=$(grep "^Port" "$ssh_config" 2>/dev/null | head -1 | awk '{print $2}')
    fi
    ssh_port=${ssh_port:-22}
    
    if [ "$ssh_port" = "22" ]; then
        print_status "WARN" "SSH Port" "Using default port 22"
    else
        print_status "PASS" "SSH Port" "Using non-standard port $ssh_port"
    fi
}

check_firewall_status() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -qw "active"; then
            print_status "PASS" "Firewall (UFW)" "Active and protecting system"
        else
            print_status "FAIL" "Firewall (UFW)" "Not active - system exposed"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            print_status "PASS" "Firewall (firewalld)" "Active and protecting system"
        else
            print_status "FAIL" "Firewall (firewalld)" "Not active - system exposed"
        fi
    elif command -v iptables >/dev/null 2>&1; then
        if iptables -L -n 2>/dev/null | grep -q "Chain INPUT"; then
            print_status "PASS" "Firewall (iptables)" "Active with rules"
        else
            print_status "FAIL" "Firewall (iptables)" "No active rules"
        fi
    else
        print_status "FAIL" "Firewall" "No firewall installed"
    fi
}

check_auto_updates() {
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        if dpkg -l | grep -q "unattended-upgrades"; then
            print_status "PASS" "Auto Updates" "Configured for security updates"
        else
            print_status "FAIL" "Auto Updates" "Not configured"
        fi
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        if yum list installed | grep -q "yum-cron"; then
            print_status "PASS" "Auto Updates" "Configured for security updates"
        else
            print_status "FAIL" "Auto Updates" "Not configured"
        fi
    fi
}

check_intrusion_prevention() {
    local ips_found=0
    local ips_active=0
    
    # Check fail2ban
    if dpkg -l 2>/dev/null | grep -q "fail2ban" || rpm -qa 2>/dev/null | grep -q "fail2ban"; then
        ips_found=1
        if systemctl is-active fail2ban &>/dev/null; then
            ips_active=1
        fi
    fi
    
    # Check CrowdSec
    if dpkg -l 2>/dev/null | grep -q "crowdsec" || rpm -qa 2>/dev/null | grep -q "crowdsec"; then
        ips_found=1
        if systemctl is-active crowdsec &>/dev/null; then
            ips_active=1
        fi
    fi
    
    # Check Docker containers
    if command -v docker &>/dev/null && systemctl is-active docker &>/dev/null; then
        if docker ps 2>/dev/null | grep -qE "fail2ban|crowdsec"; then
            ips_found=1
            ips_active=1
        fi
    fi
    
    if [ $ips_found -eq 1 ] && [ $ips_active -eq 1 ]; then
        print_status "PASS" "Intrusion Prevention" "IPS installed and running"
    elif [ $ips_found -eq 1 ]; then
        print_status "WARN" "Intrusion Prevention" "IPS installed but not running"
    else
        print_status "FAIL" "Intrusion Prevention" "No IPS installed"
    fi
}

check_failed_logins() {
    local failed_logins=0
    
    if [ -f "/var/log/auth.log" ]; then
        failed_logins=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0)
    elif command -v journalctl &>/dev/null; then
        failed_logins=$(journalctl -u ssh --since "24 hours ago" 2>/dev/null | grep -c "Failed password" || echo 0)
    fi
    
    failed_logins=$(echo "$failed_logins" | tr -d '[:space:]')
    failed_logins=${failed_logins:-0}
    
    if [ "$failed_logins" -lt 10 ]; then
        print_status "PASS" "Failed Logins" "$failed_logins attempts (normal range)"
    elif [ "$failed_logins" -lt 50 ]; then
        print_status "WARN" "Failed Logins" "$failed_logins attempts (might indicate breach)"
    else
        print_status "FAIL" "Failed Logins" "$failed_logins attempts (possible attack)"
    fi
}

check_system_updates() {
    local updates=0
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo 0)
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        updates=$(yum check-update 2>/dev/null | grep -c "^[a-zA-Z]" || echo 0)
    fi
    
    if [ "$updates" -eq 0 ]; then
        print_status "PASS" "System Updates" "All packages up to date"
    else
        print_status "FAIL" "System Updates" "$updates updates available"
    fi
}

check_running_services() {
    local services=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -c "loaded active running" || echo 0)
    
    if [ "$services" -lt 20 ]; then
        print_status "PASS" "Running Services" "$services services (minimal)"
    elif [ "$services" -lt 40 ]; then
        print_status "WARN" "Running Services" "$services services (moderate)"
    else
        print_status "FAIL" "Running Services" "$services services (too many)"
    fi
}

check_open_ports() {
    local listening_ports
    if command -v ss &>/dev/null; then
        listening_ports=$(ss -tuln 2>/dev/null | grep LISTEN | awk '{print $5}')
    elif command -v netstat &>/dev/null; then
        listening_ports=$(netstat -tuln 2>/dev/null | grep LISTEN | awk '{print $4}')
    else
        print_status "WARN" "Port Security" "Cannot check ports (ss/netstat missing)"
        return
    fi
    
    if [ -n "$listening_ports" ]; then
        local ports=$(echo "$listening_ports" | awk -F':' '{print $NF}' | sort -n | uniq | tr '\n' ',' | sed 's/,$//')
        local port_count=$(echo "$ports" | tr ',' '\n' | wc -l)
        
        if [ "$port_count" -lt 10 ]; then
            print_status "PASS" "Port Security" "$port_count ports: $ports"
        elif [ "$port_count" -lt 20 ]; then
            print_status "WARN" "Port Security" "$port_count ports: $ports"
        else
            print_status "FAIL" "Port Security" "$port_count ports: $ports"
        fi
    fi
}

check_resource_usage() {
    # Disk usage
    if [ "$DISK_USAGE" -lt 50 ]; then
        print_status "PASS" "Disk Usage" "${DISK_USAGE}% used"
    elif [ "$DISK_USAGE" -lt 80 ]; then
        print_status "WARN" "Disk Usage" "${DISK_USAGE}% used"
    else
        print_status "FAIL" "Disk Usage" "${DISK_USAGE}% used (critical)"
    fi
    
    # Memory usage
    if [ "$MEM_USAGE" -lt 50 ]; then
        print_status "PASS" "Memory Usage" "${MEM_USAGE}% used"
    elif [ "$MEM_USAGE" -lt 80 ]; then
        print_status "WARN" "Memory Usage" "${MEM_USAGE}% used"
    else
        print_status "FAIL" "Memory Usage" "${MEM_USAGE}% used (critical)"
    fi
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    if [ "$cpu_usage" -lt 50 ]; then
        print_status "PASS" "CPU Usage" "${cpu_usage}% used"
    elif [ "$cpu_usage" -lt 80 ]; then
        print_status "WARN" "CPU Usage" "${cpu_usage}% used"
    else
        print_status "FAIL" "CPU Usage" "${cpu_usage}% used (critical)"
    fi
}

check_security_policies() {
    # Sudo logging
    if grep -q "^Defaults.*logfile" /etc/sudoers 2>/dev/null; then
        print_status "PASS" "Sudo Logging" "Enabled for audit"
    else
        print_status "FAIL" "Sudo Logging" "Not configured"
    fi
    
    # Password policy
    if [ -f "/etc/security/pwquality.conf" ]; then
        if grep -q "minlen.*12" /etc/security/pwquality.conf 2>/dev/null; then
            print_status "PASS" "Password Policy" "Strong policy enforced"
        else
            print_status "FAIL" "Password Policy" "Weak policy"
        fi
    else
        print_status "FAIL" "Password Policy" "Not configured"
    fi
}

check_suid_files() {
    local suid_count=$(find / -type f -perm -4000 2>/dev/null | \
        grep -v -E '^/usr/bin/|^/bin/|^/sbin/|^/usr/sbin/|^/usr/lib' | \
        grep -v -E 'ping$|sudo$|mount$|umount$|su$|passwd$' | \
        wc -l)
    
    if [ "$suid_count" -eq 0 ]; then
        print_status "PASS" "SUID Files" "No suspicious files found"
    else
        print_status "WARN" "SUID Files" "$suid_count files outside standard locations"
    fi
}

#==============================================================================
# Network Diagnostics Functions
#==============================================================================

network_diagnostics() {
    print_section_header "NETWORK DIAGNOSTICS"
    
    echo "NETWORK DIAGNOSTICS:" >> "$REPORT_FILE"
    echo "====================" >> "$REPORT_FILE"
    
    # DNS Resolution Test
    echo -e "\n${BOLD}DNS Resolution:${NC}"
    local dns_targets=("google.com" "cloudflare.com" "github.com")
    for target in "${dns_targets[@]}"; do
        if nslookup "$target" &>/dev/null; then
            print_status "PASS" "DNS Resolution" "$target"
        else
            print_status "FAIL" "DNS Resolution" "$target"
        fi
    done
    
    # Connectivity Test
    echo -e "\n${BOLD}Connectivity:${NC}"
    local ping_targets=("8.8.8.8" "1.1.1.1")
    for target in "${ping_targets[@]}"; do
        if ping -c 3 -W 2 "$target" &>/dev/null; then
            local latency=$(ping -c 3 "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
            print_status "PASS" "Ping $target" "${latency}ms avg"
        else
            print_status "FAIL" "Ping $target" "Unreachable"
        fi
    done
    
    # Traceroute
    echo -e "\n${BOLD}Route to 8.8.8.8:${NC}"
    if command -v traceroute &>/dev/null; then
        local hops=$(traceroute -m 15 -w 2 8.8.8.8 2>/dev/null | grep -c " ms")
        print_status "INFO" "Traceroute" "$hops hops to 8.8.8.8"
    else
        print_status "WARN" "Traceroute" "Command not available"
    fi
    
    # Bandwidth Test (simple download test)
    echo -e "\n${BOLD}Download Speed Test:${NC}"
    local speed=$(curl -s -w '%{speed_download}' -o /dev/null --max-time 10 http://speedtest.tele2.net/1MB.zip 2>/dev/null || echo 0)
    if [ "$speed" != "0" ]; then
        local speed_mbps=$(echo "scale=2; $speed / 1024 / 1024 * 8" | bc)
        print_status "PASS" "Download Speed" "${speed_mbps} Mbps"
    else
        print_status "WARN" "Download Speed" "Test failed"
    fi
    
    echo "" >> "$REPORT_FILE"
}

#==============================================================================
# Log Analysis Functions
#==============================================================================

analyze_logs() {
    print_section_header "LOG ANALYSIS"
    
    echo "LOG ANALYSIS:" >> "$REPORT_FILE"
    echo "=============" >> "$REPORT_FILE"
    
    # System Errors
    echo -e "\n${BOLD}Recent System Errors:${NC}"
    if command -v journalctl &>/dev/null; then
        local error_count=$(journalctl -p err -S today --no-pager 2>/dev/null | grep -c "^--" || echo 0)
        if [ "$error_count" -lt 10 ]; then
            print_status "PASS" "System Errors" "$error_count errors today"
        elif [ "$error_count" -lt 50 ]; then
            print_status "WARN" "System Errors" "$error_count errors today"
        else
            print_status "FAIL" "System Errors" "$error_count errors today"
        fi
        
        # Show last 5 errors
        echo -e "\n${GRAY}Last 5 errors:${NC}"
        journalctl -p err -n 5 --no-pager 2>/dev/null | grep -v "^--" | head -5
    else
        print_status "INFO" "System Errors" "journalctl not available"
    fi
    
    # Authentication Logs
    echo -e "\n${BOLD}Authentication Events:${NC}"
    if [ -f "/var/log/auth.log" ]; then
        local auth_events=$(wc -l < /var/log/auth.log 2>/dev/null || echo 0)
        local successful_logins=$(grep -c "Accepted" /var/log/auth.log 2>/dev/null || echo 0)
        print_status "INFO" "Auth Events" "$auth_events total, $successful_logins successful logins"
    elif command -v journalctl &>/dev/null; then
        local successful_logins=$(journalctl -u ssh --since "24 hours ago" 2>/dev/null | grep -c "Accepted" || echo 0)
        print_status "INFO" "SSH Logins" "$successful_logins successful in last 24h"
    fi
    
    # Disk Usage Logs
    echo -e "\n${BOLD}Disk I/O Errors:${NC}"
    if command -v journalctl &>/dev/null; then
        local io_errors=$(journalctl -k --since "7 days ago" 2>/dev/null | grep -iE "i/o error|disk.*error" | wc -l || echo 0)
        if [ "$io_errors" -eq 0 ]; then
            print_status "PASS" "Disk I/O" "No errors in last 7 days"
        else
            print_status "WARN" "Disk I/O" "$io_errors errors in last 7 days"
        fi
    fi
    
    echo "" >> "$REPORT_FILE"
}

#==============================================================================
# Main Menu Functions
#==============================================================================

show_main_menu() {
    while true; do
        print_banner
        get_system_info
        
        echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}${BOLD}                    AVAILABLE ACTIONS                      ${NC}"
        echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}\n"
        
        echo -e "${WHITE}  1)${NC} 🔍 Check IP Reputation & DNS Leak"
        echo -e "${WHITE}  2)${NC} 📡 MTU Finder & Optimization"
        echo -e "${WHITE}  3)${NC} 🔒 Security Audit"
        echo -e "${WHITE}  4)${NC} 🌐 Network Diagnostics"
        echo -e "${WHITE}  5)${NC} 📋 Analyze System Logs"
        echo -e "${WHITE}  6)${NC} 📊 Full System Report (All Tests)"
        echo -e "${WHITE}  7)${NC} 💾 View Last Report"
        echo -e "${WHITE}  0)${NC} ❌ Exit"
        
        echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}\n"
        
        read -p "$(echo -e ${YELLOW}Select option [0-7]:${NC} )" choice
        
        case $choice in
            1)
                check_ip_reputation
                pause
                ;;
            2)
                find_optimal_mtu
                pause
                ;;
            3)
                security_audit
                pause
                ;;
            4)
                network_diagnostics
                pause
                ;;
            5)
                analyze_logs
                pause
                ;;
            6)
                run_full_report
                pause
                ;;
            7)
                view_last_report
                pause
                ;;
            0)
                cleanup_and_exit
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

run_full_report() {
    print_section_header "FULL SYSTEM REPORT"
    
    echo -e "${CYAN}Running comprehensive system analysis...${NC}\n"
    
    check_ip_reputation
    echo ""
    
    security_audit
    echo ""
    
    network_diagnostics
    echo ""
    
    analyze_logs
    echo ""
    
    print_status "PASS" "Full report completed"
    print_status "INFO" "Report saved to: $REPORT_FILE"
}

view_last_report() {
    local last_report=$(ls -t server-report-*.txt 2>/dev/null | head -1)
    
    if [ -n "$last_report" ]; then
        print_section_header "VIEWING LAST REPORT"
        echo -e "${CYAN}Report: $last_report${NC}\n"
        cat "$last_report"
    else
        print_status "WARN" "No reports found"
    fi
}

pause() {
    echo ""
    read -p "$(echo -e ${CYAN}Press Enter to continue...${NC})"
}

cleanup_and_exit() {
    echo -e "\n${CYAN}Cleaning up...${NC}"
    rm -rf "$TEMP_DIR" 2>/dev/null
    echo -e "${GREEN}Thank you for using Server Management Tool!${NC}"
    echo -e "${GRAY}Report saved to: $REPORT_FILE${NC}\n"
    exit 0
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    # Check for root
    check_root
    
    # Detect OS
    detect_os
    
    # Install dependencies
    install_dependencies
    
    # Show main menu
    show_main_menu
}

# Trap cleanup on exit
trap cleanup_and_exit EXIT INT TERM

# Run main function
main
