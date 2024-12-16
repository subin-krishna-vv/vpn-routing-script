#!/bin/bash

# Set default configurations (can be overridden by environment variables or config file)
VPN_GATEWAY="${VPN_GATEWAY:-<vpn gateway>}"  # Replace with actual VPN gateway IP
VPN_INTERFACE="${VPN_INTERFACE:-vpn}"  # Example: ppp0 or vpn
WEBSITES=("example1.com" "example2.com")
OFFICE_SUBNET="${OFFICE_SUBNET:-10.0.0.0/8}"
EC2_INSTANCES=("ip-1" "ip-2")

# Enable debug logging with --verbose
DEBUG=false
if [[ "$1" == "--verbose" ]]; then
    DEBUG=true
fi

log() {
    local level="$1"
    shift
    echo "[$level] $*"
}

debug() {
    if $DEBUG; then
        log "DEBUG" "$*"
    fi
}

# Check for required commands
check_command() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Command '$cmd' is required but not found. Aborting."
            exit 1
        fi
    done
}

# Check if the script is run as a sudo user
check_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        log "ERROR" "This script must be run as root or with sudo permissions. Aborting."
        exit 1
    fi
}

check_command "ip" "getent" "iptables"
check_sudo

# Function to delete a default route through VPN dynamically
remove_default_vpn_route() {
    debug "Removing conflicting default route through VPN..."
    local default_vpn_route
    default_vpn_route=$(ip route show | grep "^default" | grep "$VPN_INTERFACE" | awk '{print $3}')
    if [[ -n "$default_vpn_route" ]]; then
        sudo ip route del default via "$default_vpn_route" dev "$VPN_INTERFACE"
        log "INFO" "Removed default route via $default_vpn_route on $VPN_INTERFACE."
    else
        debug "No default route through VPN found."
    fi
}

# Function to add a route
add_route() {
    local target="$1"
    if ! ip route show | grep -q "$target"; then
        sudo ip route add "$target" dev "$VPN_INTERFACE"
        log "INFO" "Added route for $target through VPN."
    else
        debug "Route for $target already exists. Skipping..."
    fi
}

# Remove conflicting default route
remove_default_vpn_route

# Route office network traffic through the VPN
log "INFO" "Adding route for office network ($OFFICE_SUBNET)..."
add_route "$OFFICE_SUBNET"

# Add routes for each website
for website in "${WEBSITES[@]}"; do
    ip=$(getent ahosts "$website" | grep "STREAM" | awk '{print $1}' | head -n 1)
    if [[ -n "$ip" ]]; then
        log "INFO" "Routing $website ($ip) through VPN..."
        add_route "$ip"
    else
        log "WARNING" "Failed to resolve IP for $website."
    fi
done

# Add routes for each EC2 instance
for ec2_ip in "${EC2_INSTANCES[@]}"; do
    log "INFO" "Routing EC2 instance ($ec2_ip) through VPN..."
    add_route "$ec2_ip"
done

# Ensure source NAT for VPN traffic
log "INFO" "Applying NAT for VPN traffic..."
sudo iptables -t nat -C POSTROUTING -o "$VPN_INTERFACE" -j MASQUERADE 2>/dev/null || \
    sudo iptables -t nat -A POSTROUTING -o "$VPN_INTERFACE" -j MASQUERADE

log "INFO" "Routing setup completed."

