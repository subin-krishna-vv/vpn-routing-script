# VPN Routing Script
This project contains a Bash script to manage custom VPN routing rules dynamically based on Forticlinet VPN.

## Features
- Handles conflicting default VPN routes.
- Routes specific networks, websites, and EC2 instances through the VPN.
- Ensures source NAT for VPN traffic.

## Usage
Run the script with sudo permissions:
```bash
sudo ./vpn-routing-script.sh [--verbose]

