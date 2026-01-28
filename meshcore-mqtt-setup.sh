#!/usr/bin/env bash
#
# MeshCore MQTT Bridge Setup Script
# Sets up the meshcore-mqtt Python bridge with interactive configuration
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_MQTT_PORT=1883
DEFAULT_MQTT_PREFIX="meshcore"
DEFAULT_MQTT_QOS=1
DEFAULT_BAUDRATE=115200
DEFAULT_TCP_PORT=5000
DEFAULT_INSTALL_DIR="$HOME/meshcore-mqtt"

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           MeshCore MQTT Bridge Setup Script                ║"
    echo "║                                                            ║"
    echo "║  Connects your MeshCore LoRa mesh to MQTT                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_info() {
    echo -e "${CYAN}    $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠  $1${NC}"
}

print_error() {
    echo -e "${RED}✗  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓  $1${NC}"
}

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${CYAN}$prompt${NC} [${GREEN}$default${NC}]: ")" value
        value="${value:-$default}"
    else
        read -rp "$(echo -e "${CYAN}$prompt${NC}: ")" value
    fi

    eval "$var_name='$value'"
}

prompt_password() {
    local prompt="$1"
    local var_name="$2"

    read -srp "$(echo -e "${CYAN}$prompt${NC}: ")" value
    echo
    eval "$var_name='$value'"
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"

    if [[ "$default" == "y" ]]; then
        read -rp "$(echo -e "${CYAN}$prompt${NC} [${GREEN}Y${NC}/n]: ")" response
        response="${response:-y}"
    else
        read -rp "$(echo -e "${CYAN}$prompt${NC} [y/${GREEN}N${NC}]: ")" response
        response="${response:-n}"
    fi

    [[ "$response" =~ ^[Yy] ]]
}

detect_package_manager() {
    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v brew &> /dev/null; then
            PKG_MANAGER="brew"
            PKG_UPDATE="brew update"
            PKG_INSTALL="brew install"
        else
            PKG_MANAGER="none"
        fi
    elif [[ -f /etc/debian_version ]]; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt update"
        PKG_INSTALL="apt install -y"
    elif [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
        if command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
            PKG_UPDATE=""
            PKG_INSTALL="dnf install -y"
        else
            PKG_MANAGER="yum"
            PKG_UPDATE=""
            PKG_INSTALL="yum install -y"
        fi
    elif [[ -f /etc/arch-release ]]; then
        PKG_MANAGER="pacman"
        PKG_UPDATE="pacman -Sy"
        PKG_INSTALL="pacman -S --noconfirm"
    else
        PKG_MANAGER="unknown"
    fi
}

install_packages() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    print_info "Installing: ${packages[*]}"

    # Determine if we need sudo
    local SUDO=""
    if [[ "$EUID" -ne 0 ]] && [[ "$PKG_MANAGER" != "brew" ]]; then
        SUDO="sudo"
    fi

    # Update package lists if needed
    if [[ -n "$PKG_UPDATE" ]]; then
        $SUDO $PKG_UPDATE
    fi

    # Install packages
    $SUDO $PKG_INSTALL "${packages[@]}"
}

check_dependencies() {
    print_step "Checking and installing dependencies..."

    detect_package_manager

    local missing_apt=()      # Debian/Ubuntu packages
    local missing_dnf=()      # RHEL/Fedora packages
    local missing_brew=()     # macOS packages
    local missing_pacman=()   # Arch packages

    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        print_warn "Python 3 not found"
        missing_apt+=("python3")
        missing_dnf+=("python3")
        missing_brew+=("python3")
        missing_pacman+=("python")
    else
        print_success "Python 3 found: $(python3 --version)"
    fi

    # Check for pip
    if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null 2>&1; then
        print_warn "pip not found"
        missing_apt+=("python3-pip")
        missing_dnf+=("python3-pip")
        # brew python includes pip
        missing_pacman+=("python-pip")
    else
        print_success "pip found"
    fi

    # Check for python3-venv (critical for virtual environments)
    if [[ "$(uname)" == "Linux" ]]; then
        if ! python3 -m venv --help &> /dev/null 2>&1; then
            print_warn "python3-venv not found"
            # Get Python version for Debian package naming
            local py_version
            py_version=$(python3 -c 'import sys; print(sys.version_info.minor)' 2>/dev/null || echo "")
            if [[ -n "$py_version" ]]; then
                missing_apt+=("python3-venv" "python3-full" "python3.${py_version}-venv")
            else
                missing_apt+=("python3-venv" "python3-full")
            fi
            missing_dnf+=("python3-libs")  # RHEL includes venv in base
            missing_pacman+=("python")     # Arch includes venv in base
        else
            print_success "python3-venv found"
        fi
    fi

    # Check for git
    if ! command -v git &> /dev/null; then
        print_warn "git not found"
        missing_apt+=("git")
        missing_dnf+=("git")
        missing_brew+=("git")
        missing_pacman+=("git")
    else
        print_success "git found"
    fi

    # Check for BLE dependencies (Linux only)
    if [[ "$(uname)" == "Linux" ]]; then
        if ! command -v bluetoothctl &> /dev/null; then
            print_warn "BlueZ (Bluetooth) not found"
            missing_apt+=("bluez")
            missing_dnf+=("bluez")
            missing_pacman+=("bluez" "bluez-utils")
        else
            print_success "BlueZ found"
        fi

        # Check if bluetooth service is running
        if command -v systemctl &> /dev/null; then
            if ! systemctl is-active --quiet bluetooth 2>/dev/null; then
                print_warn "Bluetooth service is not running"
            fi
        fi

        # libdbus is needed for BLE on Linux
        if ! ldconfig -p 2>/dev/null | grep -q libdbus; then
            missing_apt+=("libdbus-1-dev")
            missing_dnf+=("dbus-devel")
            missing_pacman+=("dbus")
        fi
    fi

    # Determine which packages to install based on detected package manager
    local packages_to_install=()
    case "$PKG_MANAGER" in
        apt) packages_to_install=("${missing_apt[@]}") ;;
        dnf|yum) packages_to_install=("${missing_dnf[@]}") ;;
        brew) packages_to_install=("${missing_brew[@]}") ;;
        pacman) packages_to_install=("${missing_pacman[@]}") ;;
    esac

    # Remove duplicates
    packages_to_install=($(echo "${packages_to_install[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        echo
        print_warn "Missing packages: ${packages_to_install[*]}"
        echo

        if [[ "$PKG_MANAGER" == "unknown" ]] || [[ "$PKG_MANAGER" == "none" ]]; then
            print_error "Could not detect package manager. Please install manually:"
            echo "  ${packages_to_install[*]}"
            exit 1
        fi

        if prompt_yes_no "Would you like to install missing packages automatically?" "y"; then
            install_packages "${packages_to_install[@]}"
            print_success "Packages installed"
            echo

            # Re-verify critical dependencies after install
            if ! command -v python3 &> /dev/null; then
                print_error "Python 3 still not available after installation. Please install manually."
                exit 1
            fi
            if ! command -v git &> /dev/null; then
                print_error "Git still not available after installation. Please install manually."
                exit 1
            fi
        else
            echo
            echo "Please install the missing packages manually:"
            case "$PKG_MANAGER" in
                apt) echo "  sudo apt update && sudo apt install -y ${packages_to_install[*]}" ;;
                dnf) echo "  sudo dnf install -y ${packages_to_install[*]}" ;;
                yum) echo "  sudo yum install -y ${packages_to_install[*]}" ;;
                brew) echo "  brew install ${packages_to_install[*]}" ;;
                pacman) echo "  sudo pacman -S ${packages_to_install[*]}" ;;
            esac
            echo
            exit 1
        fi
    fi

    # Start bluetooth service if needed (Linux)
    if [[ "$(uname)" == "Linux" ]] && command -v systemctl &> /dev/null; then
        if ! systemctl is-active --quiet bluetooth 2>/dev/null; then
            if prompt_yes_no "Bluetooth service is not running. Start it now?" "y"; then
                sudo systemctl start bluetooth
                sudo systemctl enable bluetooth
                print_success "Bluetooth service started"
            fi
        fi
    fi
}

scan_ble_devices() {
    print_step "Scanning for BLE devices..."
    print_info "This may take 10-15 seconds. Make sure your MeshCore device is powered on."
    echo

    # Create a temporary Python script for BLE scanning
    local scan_script=$(mktemp)
    cat > "$scan_script" << 'SCANEOF'
import asyncio
import sys

try:
    from bleak import BleakScanner
except ImportError:
    print("ERROR: bleak not installed. Run: pip3 install bleak")
    sys.exit(1)

async def scan():
    print("Scanning for BLE devices (10 seconds)...\n")

    meshcore_devices = []
    other_devices = []

    # Use callback to capture both device and advertisement data (includes RSSI)
    def detection_callback(device, advertisement_data):
        name = device.name or advertisement_data.local_name or "Unknown"
        rssi = advertisement_data.rssi if hasattr(advertisement_data, 'rssi') else None

        # MeshCore devices often have specific naming patterns
        if any(x in name.upper() for x in ['MESH', 'LORA', 'HELTEC', 'RAK', 'T-BEAM', 'TBEAM', 'NODE', 'COMPANION']):
            if not any(d[0] == device.address for d in meshcore_devices):
                meshcore_devices.append((device.address, name, rssi))
        elif name != "Unknown":
            if not any(d[0] == device.address for d in other_devices):
                other_devices.append((device.address, name, rssi))

    scanner = BleakScanner(detection_callback=detection_callback)
    await scanner.start()
    await asyncio.sleep(10.0)
    await scanner.stop()

    if meshcore_devices:
        print("=== Likely MeshCore Devices ===")
        for i, (addr, name, rssi) in enumerate(meshcore_devices, 1):
            rssi_str = f"(RSSI: {rssi})" if rssi is not None else ""
            print(f"  {i}. {addr}  {name}  {rssi_str}")
        print()

    if other_devices:
        print("=== Other Named Devices ===")
        # Sort by RSSI (handle None values)
        sorted_devices = sorted(other_devices, key=lambda x: x[2] if x[2] is not None else -999, reverse=True)[:10]
        for addr, name, rssi in sorted_devices:
            rssi_str = f"(RSSI: {rssi})" if rssi is not None else ""
            print(f"     {addr}  {name}  {rssi_str}")
        print()

    if not meshcore_devices and not other_devices:
        print("No BLE devices found. Make sure:")
        print("  - Your MeshCore device is powered on")
        print("  - Bluetooth is enabled on this machine")
        print("  - You're within range of the device")
        return None

    return meshcore_devices

if __name__ == "__main__":
    result = asyncio.run(scan())
SCANEOF

    # Check if bleak is installed, if not create a temp venv for scanning
    if ! python3 -c "import bleak" 2>/dev/null; then
        print_info "Installing bleak for BLE scanning..."
        local temp_venv=$(mktemp -d)
        python3 -m venv "$temp_venv"
        "$temp_venv/bin/pip" install --quiet bleak
        "$temp_venv/bin/python" "$scan_script"
        rm -rf "$temp_venv"
    else
        python3 "$scan_script"
    fi

    rm -f "$scan_script"
}

select_connection_type() {
    print_step "Select connection type"
    echo
    echo -e "  ${GREEN}1)${NC} BLE (Bluetooth Low Energy) - ${CYAN}Recommended for most setups${NC}"
    echo -e "      Connect wirelessly to your MeshCore device"
    echo
    echo -e "  ${GREEN}2)${NC} Serial (USB)"
    echo -e "      Connect via USB cable to your device"
    echo
    echo -e "  ${GREEN}3)${NC} TCP (Network)"
    echo -e "      Connect to a MeshCore device with TCP server enabled"
    echo

    while true; do
        read -rp "$(echo -e "${CYAN}Select connection type${NC} [${GREEN}1${NC}]: ")" conn_choice
        conn_choice="${conn_choice:-1}"

        case "$conn_choice" in
            1) CONNECTION_TYPE="ble"; break ;;
            2) CONNECTION_TYPE="serial"; break ;;
            3) CONNECTION_TYPE="tcp"; break ;;
            *) print_error "Invalid choice. Please enter 1, 2, or 3." ;;
        esac
    done
}

configure_ble() {
    print_step "BLE Configuration"
    echo

    if prompt_yes_no "Would you like to scan for BLE devices?" "y"; then
        scan_ble_devices
        echo
    fi

    echo -e "${YELLOW}Enter the BLE MAC address of your MeshCore device${NC}"
    echo -e "${CYAN}Format: AA:BB:CC:DD:EE:FF${NC}"
    echo

    while true; do
        prompt_with_default "BLE MAC Address" "" "BLE_ADDRESS"

        # Validate MAC address format
        if [[ "$BLE_ADDRESS" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            # Convert to uppercase
            BLE_ADDRESS=$(echo "$BLE_ADDRESS" | tr '[:lower:]' '[:upper:]')
            break
        else
            print_error "Invalid MAC address format. Please use format: AA:BB:CC:DD:EE:FF"
        fi
    done

    MESHCORE_ADDRESS="$BLE_ADDRESS"
}

configure_serial() {
    print_step "Serial Configuration"
    echo

    # List available serial ports
    echo "Available serial ports:"
    if [[ "$(uname)" == "Darwin" ]]; then
        ls /dev/cu.usb* /dev/tty.usb* 2>/dev/null | while read port; do
            echo "  $port"
        done
    else
        ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | while read port; do
            echo "  $port"
        done
    fi
    echo

    if [[ "$(uname)" == "Darwin" ]]; then
        prompt_with_default "Serial port" "/dev/cu.usbserial-0001" "SERIAL_PORT"
    else
        prompt_with_default "Serial port" "/dev/ttyUSB0" "SERIAL_PORT"
    fi

    prompt_with_default "Baud rate" "$DEFAULT_BAUDRATE" "SERIAL_BAUDRATE"

    MESHCORE_ADDRESS="$SERIAL_PORT"

    # Check if user needs to be added to dialout group (Linux only)
    if [[ "$(uname)" == "Linux" ]]; then
        if ! groups | grep -q dialout; then
            print_warn "You may need to add your user to the 'dialout' group for serial access:"
            echo "  sudo usermod -a -G dialout $USER"
            echo "  Then log out and back in."
            echo
        fi
    fi
}

configure_tcp() {
    print_step "TCP Configuration"
    echo

    prompt_with_default "MeshCore device IP address" "192.168.1.100" "TCP_ADDRESS"
    prompt_with_default "TCP port" "$DEFAULT_TCP_PORT" "TCP_PORT"

    MESHCORE_ADDRESS="$TCP_ADDRESS"
}

configure_mqtt() {
    print_step "MQTT Broker Configuration"
    echo

    prompt_with_default "MQTT broker address" "localhost" "MQTT_BROKER"
    prompt_with_default "MQTT port" "$DEFAULT_MQTT_PORT" "MQTT_PORT"

    if prompt_yes_no "Does your MQTT broker require authentication?" "n"; then
        prompt_with_default "MQTT username" "" "MQTT_USERNAME"
        prompt_password "MQTT password" "MQTT_PASSWORD"
    else
        MQTT_USERNAME=""
        MQTT_PASSWORD=""
    fi

    prompt_with_default "MQTT topic prefix" "$DEFAULT_MQTT_PREFIX" "MQTT_PREFIX"
    prompt_with_default "MQTT QoS (0, 1, or 2)" "$DEFAULT_MQTT_QOS" "MQTT_QOS"

    if prompt_yes_no "Enable TLS/SSL for MQTT?" "n"; then
        MQTT_TLS="true"
        MQTT_PORT="${MQTT_PORT:-8883}"
    else
        MQTT_TLS="false"
    fi
}

select_events() {
    print_step "Select MeshCore events to bridge"
    echo
    echo "Which events should be forwarded to MQTT?"
    echo

    # Default events
    local default_events="CONTACT_MSG_RECV,CHANNEL_MSG_RECV,BATTERY,DEVICE_INFO,NEW_CONTACT,ADVERTISEMENT,TELEMETRY_RESPONSE"

    echo -e "  ${GREEN}1)${NC} Standard (recommended) - Messages, contacts, battery, telemetry"
    echo -e "  ${GREEN}2)${NC} Minimal - Only direct and channel messages"
    echo -e "  ${GREEN}3)${NC} Everything - All available events"
    echo -e "  ${GREEN}4)${NC} Custom - Choose specific events"
    echo

    read -rp "$(echo -e "${CYAN}Select event set${NC} [${GREEN}1${NC}]: ")" event_choice
    event_choice="${event_choice:-1}"

    case "$event_choice" in
        1) MESHCORE_EVENTS="CONTACT_MSG_RECV,CHANNEL_MSG_RECV,BATTERY,DEVICE_INFO,NEW_CONTACT,ADVERTISEMENT,TELEMETRY_RESPONSE" ;;
        2) MESHCORE_EVENTS="CONTACT_MSG_RECV,CHANNEL_MSG_RECV" ;;
        3) MESHCORE_EVENTS="CONNECTED,DISCONNECTED,LOGIN_SUCCESS,CONTACT_MSG_RECV,CHANNEL_MSG_RECV,DEVICE_INFO,BATTERY,NEW_CONTACT,ADVERTISEMENT,TRACE_DATA,TELEMETRY_RESPONSE,CHANNEL_INFO,CONTACTS,SELF_INFO" ;;
        4)
            echo
            echo "Available events (comma-separated):"
            echo "  CONNECTED, DISCONNECTED, LOGIN_SUCCESS, LOGIN_FAILED,"
            echo "  CONTACT_MSG_RECV, CHANNEL_MSG_RECV, MESSAGES_WAITING,"
            echo "  DEVICE_INFO, BATTERY, NEW_CONTACT, ADVERTISEMENT,"
            echo "  TRACE_DATA, TELEMETRY_RESPONSE, CHANNEL_INFO, CONTACTS, SELF_INFO"
            echo
            prompt_with_default "Enter events" "$default_events" "MESHCORE_EVENTS"
            ;;
        *) MESHCORE_EVENTS="$default_events" ;;
    esac
}

install_bridge() {
    print_step "Installing meshcore-mqtt bridge..."

    prompt_with_default "Installation directory" "$DEFAULT_INSTALL_DIR" "INSTALL_DIR"

    if [[ -d "$INSTALL_DIR" ]]; then
        if prompt_yes_no "Directory exists. Update existing installation?" "y"; then
            cd "$INSTALL_DIR"
            git pull
        else
            print_error "Installation cancelled."
            exit 1
        fi
    else
        git clone https://github.com/ipnet-mesh/meshcore-mqtt "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    print_info "Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate

    print_info "Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r requirements.txt

    # Install bleak for BLE support
    if [[ "$CONNECTION_TYPE" == "ble" ]]; then
        pip install bleak
    fi

    print_success "Dependencies installed"
}

generate_config() {
    print_step "Generating configuration file..."

    local config_file="$INSTALL_DIR/config.json"

    # Build events array
    local events_json=$(echo "$MESHCORE_EVENTS" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')

    # Build config based on connection type
    case "$CONNECTION_TYPE" in
        ble)
            local meshcore_config="\"connection_type\": \"ble\",
    \"address\": \"$MESHCORE_ADDRESS\""
            ;;
        serial)
            local meshcore_config="\"connection_type\": \"serial\",
    \"address\": \"$MESHCORE_ADDRESS\",
    \"baudrate\": $SERIAL_BAUDRATE"
            ;;
        tcp)
            local meshcore_config="\"connection_type\": \"tcp\",
    \"address\": \"$MESHCORE_ADDRESS\",
    \"port\": $TCP_PORT"
            ;;
    esac

    # Build MQTT auth section
    local mqtt_auth=""
    if [[ -n "$MQTT_USERNAME" ]]; then
        mqtt_auth="\"username\": \"$MQTT_USERNAME\",
    \"password\": \"$MQTT_PASSWORD\","
    fi

    cat > "$config_file" << CONFIGEOF
{
  "mqtt": {
    "broker": "$MQTT_BROKER",
    "port": $MQTT_PORT,
    $mqtt_auth
    "topic_prefix": "$MQTT_PREFIX",
    "qos": $MQTT_QOS,
    "retain": false,
    "tls_enabled": $MQTT_TLS
  },
  "meshcore": {
    $meshcore_config,
    "timeout": 10,
    "auto_fetch_restart_delay": 5,
    "message_initial_delay": 15.0,
    "message_send_delay": 15.0,
    "events": [$events_json]
  },
  "log_level": "INFO"
}
CONFIGEOF

    print_success "Configuration saved to: $config_file"
}

create_systemd_service() {
    if [[ "$(uname)" != "Linux" ]]; then
        return
    fi

    print_step "Systemd Service Setup"

    if ! prompt_yes_no "Create systemd service for auto-start on boot?" "y"; then
        return
    fi

    local service_file="/etc/systemd/system/meshcore-mqtt.service"
    local service_content="[Unit]
Description=MeshCore MQTT Bridge
After=network-online.target bluetooth.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python -m meshcore_mqtt.main --config-file $INSTALL_DIR/config.json
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target"

    echo
    echo "This will create a systemd service. Requires sudo."
    echo

    echo "$service_content" | sudo tee "$service_file" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable meshcore-mqtt

    print_success "Systemd service created and enabled"
    print_info "Start with: sudo systemctl start meshcore-mqtt"
    print_info "View logs: journalctl -u meshcore-mqtt -f"
}

create_launchd_plist() {
    if [[ "$(uname)" != "Darwin" ]]; then
        return
    fi

    print_step "LaunchAgent Setup (macOS)"

    if ! prompt_yes_no "Create LaunchAgent for auto-start on login?" "y"; then
        return
    fi

    local plist_dir="$HOME/Library/LaunchAgents"
    local plist_file="$plist_dir/com.meshcore.mqtt-bridge.plist"

    mkdir -p "$plist_dir"

    cat > "$plist_file" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.meshcore.mqtt-bridge</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/venv/bin/python</string>
        <string>-m</string>
        <string>meshcore_mqtt.main</string>
        <string>--config-file</string>
        <string>$INSTALL_DIR/config.json</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/logs/stderr.log</string>
</dict>
</plist>
PLISTEOF

    mkdir -p "$INSTALL_DIR/logs"

    print_success "LaunchAgent created: $plist_file"
    print_info "Load with: launchctl load $plist_file"
    print_info "Unload with: launchctl unload $plist_file"
}

create_run_script() {
    print_step "Creating run script..."

    cat > "$INSTALL_DIR/run.sh" << RUNEOF
#!/usr/bin/env bash
# MeshCore MQTT Bridge run script
cd "$INSTALL_DIR"
source venv/bin/activate
python -m meshcore_mqtt.main --config-file config.json "\$@"
RUNEOF

    chmod +x "$INSTALL_DIR/run.sh"
    print_success "Run script created: $INSTALL_DIR/run.sh"
}

print_summary() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Setup Complete!                         ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}Installation directory:${NC} $INSTALL_DIR"
    echo -e "${GREEN}Configuration file:${NC} $INSTALL_DIR/config.json"
    echo
    echo -e "${GREEN}Connection type:${NC} $CONNECTION_TYPE"
    echo -e "${GREEN}Device address:${NC} $MESHCORE_ADDRESS"
    echo -e "${GREEN}MQTT broker:${NC} $MQTT_BROKER:$MQTT_PORT"
    echo -e "${GREEN}MQTT topic prefix:${NC} $MQTT_PREFIX"
    echo
    echo -e "${YELLOW}To start the bridge manually:${NC}"
    echo "  cd $INSTALL_DIR"
    echo "  ./run.sh"
    echo
    echo -e "${YELLOW}To test your MQTT connection:${NC}"
    echo "  mosquitto_sub -h $MQTT_BROKER -p $MQTT_PORT -t '$MQTT_PREFIX/#' -v"
    echo

    if [[ "$CONNECTION_TYPE" == "ble" ]]; then
        echo -e "${YELLOW}BLE Tips:${NC}"
        echo "  - Make sure your MeshCore device is powered on and in range"
        echo "  - On Linux, you may need to run: sudo systemctl start bluetooth"
        echo "  - First connection may take 10-30 seconds to establish"
        echo
    fi

    if prompt_yes_no "Would you like to start the bridge now?" "y"; then
        echo
        print_step "Starting MeshCore MQTT Bridge..."
        cd "$INSTALL_DIR"
        source venv/bin/activate
        python -m meshcore_mqtt.main --config-file config.json
    fi
}

# Main execution
main() {
    print_banner

    check_dependencies

    select_connection_type

    case "$CONNECTION_TYPE" in
        ble) configure_ble ;;
        serial) configure_serial ;;
        tcp) configure_tcp ;;
    esac

    configure_mqtt
    select_events
    install_bridge
    generate_config
    create_run_script

    # Platform-specific auto-start setup
    if [[ "$(uname)" == "Linux" ]]; then
        create_systemd_service
    elif [[ "$(uname)" == "Darwin" ]]; then
        create_launchd_plist
    fi

    print_summary
}

# Run main function
main "$@"
