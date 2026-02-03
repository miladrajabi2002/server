# Server Management & Audit Tool 🚀

A comprehensive server monitoring and security audit tool for Linux systems with advanced features.

## Features ✨

### 1. System Information Dashboard 📊
- Beautiful graphical display of system specs
- CPU, RAM, and Disk information
- IP addresses (IPv4/IPv6)
- Network interface status
- System uptime and load

### 2. IP Reputation Check 🔍
- Clean/Dirty IP detection
- Fraud score analysis
- Proxy/VPN detection
- DNS Blacklist checking
- DNS Leak testing
- Geolocation and ISP information
- Integration with multiple reputation services:
  - IPQualityScore
  - AbuseIPDB
  - Spamhaus, SpamCop, SORBS
  - Custom DNS leak tests

### 3. MTU Finder & Optimizer 📡
- Automatic optimal MTU detection
- Custom MTU testing
- Automatic and permanent MTU configuration
- IPv4 and IPv6 support
- Binary search algorithm for efficiency

### 4. Security Audit 🔒
Comprehensive security checks including:
- SSH configuration (root login, password auth, port)
- Firewall status (UFW, firewalld, iptables, nftables)
- Fail2ban/CrowdSec intrusion prevention
- Failed login attempts monitoring
- Security updates availability
- Open ports analysis
- SUID files detection
- Password policy enforcement
- Sudo logging configuration

### 5. Network Diagnostics 🌐
- DNS resolution testing
- Ping and latency tests
- Traceroute analysis
- Download speed test
- Connection quality assessment

### 6. Log Analysis 📋
- System error analysis
- Authentication log review
- Disk I/O error detection
- Recent event summary

## Supported Operating Systems 🐧

✅ Ubuntu 18.04, 20.04, 22.04, 24.04
✅ Debian 9, 10, 11, 12
✅ CentOS 7, 8, 9
✅ RHEL 7, 8, 9
✅ Fedora

## Installation 💻

### Quick Install (Recommended):
```bash
# Download and install in one command
curl -fsSL https://raw.githubusercontent.com/miladrajabi2002/server/main/install.sh | sudo bash
```

### Manual Installation:
```bash
# Download the script
wget https://raw.githubusercontent.com/miladrajabi2002/server/main/server

# Make it executable
chmod +x server

# Move to system path
sudo mv server /usr/local/bin/

# Run it
sudo server
```

### From Source:
```bash
# Clone the repository
git clone https://github.com/miladrajabi2002/server.git
cd server-tool

# Install
sudo bash install.sh
```

## Usage 🎯

Simply run:
```bash
sudo server
```

### Menu Options:
1. **IP Reputation Check** - Check if your server IP is clean
2. **MTU Optimization** - Find and set optimal MTU
3. **Security Audit** - Complete security assessment
4. **Network Diagnostics** - Network connectivity tests
5. **Log Analysis** - System log review
6. **Full Report** - Run all tests and generate report
7. **View Last Report** - Display previous report
0. **Exit** - Close the tool

## Requirements 📦

The script automatically installs these dependencies:
- curl
- wget
- jq
- bc
- net-tools
- dnsutils (or bind-utils)
- traceroute

## Reports 📄

All reports are saved as:
```
server-report-YYYYMMDD_HHMMSS.txt
```

Location: Current directory

## Security 🔐

- Script must be run with root/sudo privileges
- No sensitive information is stored
- Original configuration files are backed up before changes
- All modifications require user confirmation

## Examples 💡

### Check IP Reputation:
```bash
sudo server
# Select option 1
# Review fraud score, blacklist status, and DNS configuration
```

### Optimize MTU:
```bash
sudo server
# Select option 2
# Choose auto-detect
# Follow prompts to test and apply optimal MTU
```

### Complete Security Audit:
```bash
sudo server
# Select option 6
# Review comprehensive security report
```

## Understanding Results 📚

### IP Reputation Score:
- **80-100%**: Clean IP ✅
- **60-79%**: Moderate issues ⚠️
- **0-59%**: Dirty IP or blacklisted ❌

### Security Status:
- **PASS**: Everything is good ✅
- **WARN**: Needs attention ⚠️
- **FAIL**: Critical security issue ❌

### MTU Values:
- Default MTU is usually 1500
- Optimal MTU improves network performance
- Script automatically detects best value

## Troubleshooting 🔧

### Script won't run:
```bash
sudo chmod +x /usr/local/bin/server
sudo server
```

### Dependencies not installing:
```bash
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install -y curl wget jq bc net-tools dnsutils traceroute

# CentOS/RHEL:
sudo yum install -y curl wget jq bc net-tools bind-utils traceroute
```

### Permission denied:
Always use `sudo`:
```bash
sudo server
```

## Advanced Usage 🔬

### Custom MTU Testing:
The tool can test specific MTU values and multiple destinations for accuracy.

### IP Reputation APIs:
Integrates with multiple services for comprehensive IP analysis:
- Free tier APIs for basic checking
- Multiple blacklist databases
- Geographic and ISP information

### Security Hardening:
The audit provides actionable recommendations:
- SSH hardening
- Firewall configuration
- Intrusion prevention setup
- Update management

## Future Features 🚀

Planned improvements:
- [ ] Auto-fix for security issues
- [ ] Email notifications
- [ ] Web dashboard
- [ ] Continuous monitoring
- [ ] Telegram bot integration
- [ ] Custom alert rules
- [ ] Historical trending

## Contributing 🤝

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## Reporting Issues 🐛

Found a bug? Please open an issue with:
- Your OS and version
- Steps to reproduce
- Expected vs actual behavior
- Error messages (if any)

## License 📜

MIT License - Free to use for everyone

## Credits ✍️

- Version: 1.0.0
- Inspired by various security and monitoring tools
- Built with Bash for maximum compatibility

## Disclaimer ⚠️

This tool is for monitoring and improving server security. It does not make changes without user confirmation. Always test in a non-production environment first.

## Support 💬

For questions or support:
- Open an issue on GitHub
- Check existing issues for solutions
- Read the FAQ section

---

**Made with ❤️ for system administrators and DevOps engineers**

**Note**: Always backup your configuration files before making changes. This tool is provided as-is without warranty.
