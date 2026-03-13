#!/bin/bash
# This script will install teleport, and install nginx if you want it too on Ubuntu/Debian-based distros


################################# IMPORTANT ###################################
# NOTE THIS SCRIPT IS ONLY FOR UBUNTU/DEBIAN BASED DISTROS
# DO NOT USE ON RHEL, ROCKY, OR CentOS BASED MACHINES
################################# IMPORTANT ###################################


# Check if Podman is installed and install it if not
# For Ubuntu/Debian and similar distributions

# # Clean up any previous attempts
# podman stop teleport 2>/dev/null
# podman rm teleport 2>/dev/null
# rm -rf ~/teleport
# systemctl --user stop container-teleport.service 2>/dev/null
# systemctl --user disable container-teleport.service 2>/dev/null
# rm -f ~/.config/systemd/user/container-teleport.service
# systemctl --user daemon-reload

set -e

echo "Checking for Podman installation..."

if command -v podman &> /dev/null; then
    echo "Podman is already installed."
    podman --version
else
    echo "Podman is not installed. Installing..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        SUDO="sudo"
    else
        SUDO=""
    fi
    
    # Update package lists and install podman
    $SUDO apt update
    $SUDO apt install -y podman
    
    echo "Podman installed successfully."
    podman --version
fi

# Get the current user's home directory
USER_HOME="$HOME"

# Create Teleport directories
echo "Creating Teleport directories..."
mkdir -p ~/teleport/config
mkdir -p ~/teleport/data
echo "Teleport directories created at ~/teleport/"

# Prompt for domain
read -p "Enter the Teleport domain (e.g., teleport.int.zodu.com): " TELEPORT_DOMAIN

if [[ -z "$TELEPORT_DOMAIN" ]]; then
    echo "Error: Domain cannot be empty."
    exit 1
fi

# Ask about Nginx Proxy Manager usage upfront
echo ""
read -p "Will you be using Nginx Proxy Manager as a reverse proxy for Teleport? (y/n): " USE_NPM

if [[ "$USE_NPM" =~ ^[Yy]$ ]]; then
    TELEPORT_PUBLIC_PORT=443
    echo "Teleport will be configured to expect traffic on port 443 (via Nginx Proxy Manager)."
else
    TELEPORT_PUBLIC_PORT=3080
    echo "Teleport will be configured for direct access on port 3080."
fi

echo ""
echo "Creating Teleport configuration with domain: $TELEPORT_DOMAIN"

cat > ~/teleport/config/teleport.yaml << EOF
version: v3
teleport:
  nodename: $TELEPORT_DOMAIN
  data_dir: /var/lib/teleport
  log:
    output: stderr
    severity: INFO
    format:
      output: text
  ca_pin: ""
  diag_addr: ""
auth_service:
  enabled: true
  cluster_name: "$TELEPORT_DOMAIN"
  listen_addr: 0.0.0.0:3025
  proxy_listener_mode: multiplex
  authentication:
    second_factor: "on"
    webauthn:
      rp_id: $TELEPORT_DOMAIN
ssh_service:
  enabled: true
  commands: []
proxy_service:
  enabled: true
  web_listen_addr: 0.0.0.0:3080
  public_addr: $TELEPORT_DOMAIN:$TELEPORT_PUBLIC_PORT
  https_keypairs: []
  https_keypairs_reload_interval: 0s
  acme: {}
  trust_x_forwarded_for: true
app_service:
  enabled: true
  debug_app: true
  apps: []
EOF

echo "Teleport configuration created at ~/teleport/config/teleport.yaml"

# Pull Teleport image
echo "Pulling Teleport container image..."
podman pull public.ecr.aws/gravitational/teleport-distroless:18

# Run Teleport container in detached mode
echo "Starting Teleport container..."
podman run -d \
  --name teleport \
  --hostname $TELEPORT_DOMAIN \
  -v ~/teleport/config/teleport.yaml:/etc/teleport/teleport.yaml:ro,Z \
  -v ~/teleport/data:/var/lib/teleport:Z \
  -p 3023:3023 \
  -p 3024:3024 \
  -p 3025:3025 \
  -p 3080:3080 \
  public.ecr.aws/gravitational/teleport-distroless:18

# Wait for Teleport to start with timeout
echo "Waiting for Teleport services to start (timeout: 180 seconds)..."
sleep 2

TIMEOUT=180
ELAPSED=0
STARTED=false

while [ $ELAPSED -lt $TIMEOUT ]; do
    if podman logs teleport 2>&1 | grep -q "The new service has started successfully"; then
        STARTED=true
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo "Waiting... ($ELAPSED seconds)"
done

if [ "$STARTED" = true ]; then
    echo ""
    echo "=========================================="
    echo "Teleport is now running!"
    echo "Access the web UI at: https://$TELEPORT_DOMAIN:3080"
    echo "Container name: teleport"
    echo "To view logs: podman logs -f teleport"
    echo "To stop: podman stop teleport"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "Timeout reached, but Teleport container is running."
    echo "It may still be starting up. Check logs with:"
    echo "  podman logs -f teleport"
    echo "=========================================="
fi

# Stop the initial container so systemd can manage it
echo "Stopping initial container so systemd can manage it..."
podman stop teleport

# Create systemd user service for Teleport
echo "Creating systemd user service for Teleport..."
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/container-teleport.service << EOF
[Unit]
Description=Podman container-teleport.service
Documentation=man:podman-generate-systemd(1)
Wants=network-online.target
After=network-online.target
RequiresMountsFor=%t/containers
[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=always
TimeoutStopSec=70
ExecStartPre=/usr/bin/rm -f %t/%n.ctr-id
ExecStart=/usr/bin/podman run \\
        --cidfile=%t/%n.ctr-id \\
        --cgroups=no-conmon \\
        --rm \\
        --sdnotify=conmon \\
        --replace \\
        -d \\
        --name teleport \\
        --hostname ${TELEPORT_DOMAIN} \\
        -v ${USER_HOME}/teleport/config/teleport.yaml:/etc/teleport/teleport.yaml:ro,Z \\
        -v ${USER_HOME}/teleport/data:/var/lib/teleport:Z \\
        -p 3023:3023 \\
        -p 3024:3024 \\
        -p 3025:3025 \\
        -p 3080:3080 public.ecr.aws/gravitational/teleport-distroless:18
ExecStop=/usr/bin/podman stop \\
        --ignore -t 10 \\
        --cidfile=%t/%n.ctr-id
ExecStopPost=/usr/bin/podman rm \\
        -f \\
        --ignore \\
        --cidfile=%t/%n.ctr-id
Type=notify
NotifyAccess=all
[Install]
WantedBy=default.target
EOF

echo "Systemd user service created at ~/.config/systemd/user/container-teleport.service"

# Enable and start the systemd service
echo "Enabling and starting systemd user service..."
systemctl --user daemon-reload
systemctl --user enable container-teleport.service
systemctl --user start container-teleport.service

# Enable lingering so service runs without being logged in
echo "Enabling user lingering..."
sudo loginctl enable-linger $USER

# Wait a moment for the service to start
sleep 50

# Show status and verification
echo ""
echo "=========================================="
echo "Verifying Teleport installation..."
echo "=========================================="
echo ""
echo "Service status:"
systemctl --user status container-teleport.service --no-pager
echo ""
echo "Running containers:"
podman ps
echo ""
echo "Port 3080 listening:"
ss -tlnp | grep 3080
echo ""
echo "Testing HTTPS connection:"
curl -k https://localhost:3080
echo ""
echo "=========================================="
echo "Teleport setup complete!"
echo "Access Teleport at: https://$TELEPORT_DOMAIN:$TELEPORT_PUBLIC_PORT"
echo "=========================================="

# If not using NPM, show direct access tutorial and exit
if [[ ! "$USE_NPM" =~ ^[Yy]$ ]]; then
    CURRENT_USER=$(whoami)
    cat << EOF

══════════════════════════════════════════════════════════════════════
                         ACCESS TUTORIAL
══════════════════════════════════════════════════════════════════════

Since you're on a private subnet, use SSH tunnels to access the web UI.

──────────────────────────────────────────────────────────────────────
ACCESS TELEPORT
──────────────────────────────────────────────────────────────────────

From your local machine:

  ssh -L 3080:localhost:3080 ${CURRENT_USER}@<SERVER_IP> -p <SSH_PORT>

  Replace:
    <SERVER_IP>  = The IP address of this server
    <SSH_PORT>   = Your SSH port (default is 22)

Then open browser: https://localhost:3080
(Accept the self-signed certificate warning)

══════════════════════════════════════════════════════════════════════
                         MANAGEMENT COMMANDS
══════════════════════════════════════════════════════════════════════

Teleport (rootless, user service):
  View logs:    podman logs -f teleport
  Stop:         systemctl --user stop container-teleport.service
  Start:        systemctl --user start container-teleport.service
  Restart:      systemctl --user restart container-teleport.service
  Status:       systemctl --user status container-teleport.service

══════════════════════════════════════════════════════════════════════
EOF
    echo "Setup complete!"
    exit 0
fi

# If using NPM, show tutorial and exit
if [[ "$USE_NPM" =~ ^[Yy]$ ]]; then
    CURRENT_USER=$(whoami)
    cat << EOF

══════════════════════════════════════════════════════════════════════
                         ACCESS TUTORIAL
══════════════════════════════════════════════════════════════════════

Since you're on a private subnet, use SSH tunnels to access the web UIs.

──────────────────────────────────────────────────────────────────────
ACCESS TELEPORT DIRECTLY (for testing)
──────────────────────────────────────────────────────────────────────

From your local machine:

  ssh -L 3080:localhost:3080 ${CURRENT_USER}@<SERVER_IP> -p <SSH_PORT>

  Replace:
    <SERVER_IP>  = The IP address of this server
    <SSH_PORT>   = Your SSH port (default is 22)

Then open browser: https://localhost:3080
(Accept the self-signed certificate warning)

──────────────────────────────────────────────────────────────────────
ACCESS NGINX PROXY MANAGER ADMIN UI
──────────────────────────────────────────────────────────────────────

From your local machine:

  ssh -L 8081:localhost:81 ${CURRENT_USER}@<SERVER_IP> -p <SSH_PORT>

  Replace:
    <SERVER_IP>  = The IP address of this server
    <SSH_PORT>   = Your SSH port (default is 22)

Then open browser: http://localhost:8081

──────────────────────────────────────────────────────────────────────
CONFIGURE NGINX PROXY MANAGER FOR TELEPORT
──────────────────────────────────────────────────────────────────────

1. Log into Nginx Proxy Manager at http://localhost:8081
2. Go to Hosts → Proxy Hosts → Add Proxy Host
3. Fill in:
   • Domain Names:        ${TELEPORT_DOMAIN}
   • Scheme:              https (important - Teleport uses HTTPS)
   • Forward Hostname/IP: localhost
   • Forward Port:        3080
   • ☑ Block Common Exploits
   • ☑ Websockets Support (critical for Teleport)
4. Click Save

══════════════════════════════════════════════════════════════════════
                         MANAGEMENT COMMANDS
══════════════════════════════════════════════════════════════════════

Teleport (rootless, user service):
  View logs:    podman logs -f teleport
  Stop:         systemctl --user stop container-teleport.service
  Start:        systemctl --user start container-teleport.service
  Restart:      systemctl --user restart container-teleport.service
  Status:       systemctl --user status container-teleport.service

══════════════════════════════════════════════════════════════════════
EOF
    echo "Setup complete!"
    exit 0
fi

# Continue with Nginx Proxy Manager installation
echo ""
echo "=========================================="
echo "Installing Nginx Proxy Manager..."
echo "=========================================="

# Create Nginx Proxy Manager directories
echo "Creating Nginx Proxy Manager directories..."
sudo mkdir -p /opt/nginx-proxy-manager/data
sudo mkdir -p /opt/nginx-proxy-manager/letsencrypt
echo "Nginx Proxy Manager directories created at /opt/nginx-proxy-manager/"

# Pull Nginx Proxy Manager image as root
echo "Pulling Nginx Proxy Manager image..."
sudo podman pull docker.io/jc21/nginx-proxy-manager:latest

# Run Nginx Proxy Manager container initially to verify it works
echo "Starting Nginx Proxy Manager container..."
sudo podman run -d \
  --name nginx-proxy-manager \
  -p 80:80 \
  -p 81:81 \
  -p 443:443 \
  -v /opt/nginx-proxy-manager/data:/data:Z \
  -v /opt/nginx-proxy-manager/letsencrypt:/etc/letsencrypt:Z \
  docker.io/jc21/nginx-proxy-manager:latest

# Wait for container to start
sleep 3

# Show container status and logs
echo ""
echo "Running containers (root):"
sudo podman ps
echo ""
echo "Nginx Proxy Manager logs:"
sudo podman logs nginx-proxy-manager

# Stop the container so systemd can manage it
echo ""
echo "Stopping container so systemd can manage it..."
sudo podman stop nginx-proxy-manager
sudo podman rm nginx-proxy-manager

# Create systemd system service for Nginx Proxy Manager
echo "Creating systemd system service for Nginx Proxy Manager..."
sudo tee /etc/systemd/system/container-nginx-proxy-manager.service > /dev/null << 'EOF'
[Unit]
Description=Podman container-nginx-proxy-manager.service
Documentation=man:podman-generate-systemd(1)
Wants=network-online.target
After=network-online.target
RequiresMountsFor=/run/containers/storage

[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=always
TimeoutStopSec=70
ExecStartPre=/usr/bin/rm -f /%t/%n.ctr-id
ExecStart=/usr/bin/podman run \
        --cidfile=/%t/%n.ctr-id \
        --cgroups=no-conmon \
        --rm \
        --sdnotify=conmon \
        -d \
        --name nginx-proxy-manager \
        -p 80:80 \
        -p 81:81 \
        -p 443:443 \
        -v /opt/nginx-proxy-manager/data:/data:Z \
        -v /opt/nginx-proxy-manager/letsencrypt:/etc/letsencrypt:Z \
        docker.io/jc21/nginx-proxy-manager:latest
ExecStop=/usr/bin/podman stop \
        --ignore -t 10 \
        --cidfile=/%t/%n.ctr-id
ExecStopPost=/usr/bin/podman rm \
        -f \
        --ignore \
        --cidfile=/%t/%n.ctr-id
Type=notify
NotifyAccess=all

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the systemd service
echo "Enabling and starting systemd service for Nginx Proxy Manager..."
sudo systemctl daemon-reload
sudo systemctl enable container-nginx-proxy-manager.service
sudo systemctl start container-nginx-proxy-manager.service

# Wait for service to start
sleep 3

# Show status
echo ""
echo "Nginx Proxy Manager service status:"
sudo systemctl status container-nginx-proxy-manager.service --no-pager
echo ""
echo "Running containers (root):"
sudo podman ps

echo ""
echo "=========================================="
echo "Nginx Proxy Manager setup complete!"
echo "=========================================="

# Get current username for tutorial
CURRENT_USER=$(whoami)

cat << EOF

══════════════════════════════════════════════════════════════════════
                         ACCESS TUTORIAL
══════════════════════════════════════════════════════════════════════

Since you're on a private subnet, use SSH tunnels to access the web UIs.

──────────────────────────────────────────────────────────────────────
ACCESS TELEPORT DIRECTLY (for testing)
──────────────────────────────────────────────────────────────────────

From your local machine:

  ssh -L 3080:localhost:3080 ${CURRENT_USER}@<SERVER_IP> -p <SSH_PORT>

  Replace:
    <SERVER_IP>  = The IP address of this server
    <SSH_PORT>   = Your SSH port (default is 22)

Then open browser: https://localhost:3080
(Accept the self-signed certificate warning)

──────────────────────────────────────────────────────────────────────
ACCESS NGINX PROXY MANAGER ADMIN UI
──────────────────────────────────────────────────────────────────────

From your local machine:

  ssh -L 8081:localhost:81 ${CURRENT_USER}@<SERVER_IP> -p <SSH_PORT>

  Replace:
    <SERVER_IP>  = The IP address of this server
    <SSH_PORT>   = Your SSH port (default is 22)

Then open browser: http://localhost:8081

Default credentials:
  • Email:    admin@example.com
  • Password: changeme

──────────────────────────────────────────────────────────────────────
CONFIGURE NGINX PROXY MANAGER FOR TELEPORT
──────────────────────────────────────────────────────────────────────

1. Log into Nginx Proxy Manager at http://localhost:8081
2. Change the default password when prompted
3. Go to Hosts → Proxy Hosts → Add Proxy Host
4. Fill in:
   • Domain Names:        ${TELEPORT_DOMAIN}
   • Scheme:              https (important - Teleport uses HTTPS)
   • Forward Hostname/IP: localhost
   • Forward Port:        3080
   • ☑ Block Common Exploits
   • ☑ Websockets Support (critical for Teleport)
5. Click Save

══════════════════════════════════════════════════════════════════════
                         MANAGEMENT COMMANDS
══════════════════════════════════════════════════════════════════════

Teleport (rootless, user service):
  View logs:    podman logs -f teleport
  Stop:         systemctl --user stop container-teleport.service
  Start:        systemctl --user start container-teleport.service
  Restart:      systemctl --user restart container-teleport.service
  Status:       systemctl --user status container-teleport.service

Nginx Proxy Manager (root, system service):
  View logs:    sudo podman logs -f nginx-proxy-manager
  Stop:         sudo systemctl stop container-nginx-proxy-manager.service
  Start:        sudo systemctl start container-nginx-proxy-manager.service
  Restart:      sudo systemctl restart container-nginx-proxy-manager.service
  Status:       sudo systemctl status container-nginx-proxy-manager.service

══════════════════════════════════════════════════════════════════════
EOF