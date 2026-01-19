#!/bin/bash
# CCDC Load Balancer Quick Deploy Script
# This script helps quickly deploy either Nginx or HAProxy in a CCDC environment

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== CCDC Load Balancer Deployment Tool ===${NC}\n"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Function to deploy Nginx
deploy_nginx() {
    echo -e "${GREEN}Deploying Nginx reverse proxy...${NC}"
    
    mkdir -p nginx-proxy/{ssl,logs,web1,web2}
    cd nginx-proxy
    
    # Create a simple index page for backends
    echo "<h1>Backend Server 1</h1>" > web1/index.html
    echo "<h1>Backend Server 2</h1>" > web2/index.html
    
    # Generate self-signed certificate for testing
    if [ ! -f ssl/cert.pem ]; then
        echo -e "${YELLOW}Generating self-signed SSL certificate...${NC}"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem -out ssl/cert.pem \
            -subj "/C=US/ST=State/L=City/O=CCDC/CN=localhost"
    fi
    
    # Note: Docker Compose and config files should be created separately
    echo -e "${GREEN}Nginx deployment directory created at: $(pwd)${NC}"
    echo -e "${YELLOW}Make sure to copy the docker-compose.yml and nginx.conf files here${NC}"
    echo -e "${YELLOW}Then run: docker-compose up -d${NC}"
}

# Function to deploy HAProxy
deploy_haproxy() {
    echo -e "${GREEN}Deploying HAProxy load balancer...${NC}"
    
    mkdir -p haproxy-lb/{ssl,app1,app2,app3}
    cd haproxy-lb
    
    # Create simple pages for backends
    echo "<h1>Application Server 1</h1>" > app1/index.html
    echo "<h1>Application Server 2</h1>" > app2/index.html
    echo "<h1>Application Server 3 (Backup)</h1>" > app3/index.html
    
    # Generate self-signed certificate
    if [ ! -f ssl/combined.pem ]; then
        echo -e "${YELLOW}Generating self-signed SSL certificate...${NC}"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem -out ssl/cert.pem \
            -subj "/C=US/ST=State/L=City/O=CCDC/CN=localhost"
        cat ssl/cert.pem ssl/key.pem > ssl/combined.pem
    fi
    
    echo -e "${GREEN}HAProxy deployment directory created at: $(pwd)${NC}"
    echo -e "${YELLOW}Make sure to copy the docker-compose.yml and haproxy.cfg files here${NC}"
    echo -e "${YELLOW}Then run: docker-compose up -d${NC}"
}

# Function to create monitoring script
create_monitor_script() {
    cat > monitor_lb.sh << 'EOF'
#!/bin/bash
# Quick monitoring script for load balancer

echo "=== Container Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n=== Recent Logs (last 20 lines) ==="
docker-compose logs --tail=20

echo -e "\n=== Network Connectivity Test ==="
echo "Testing HTTP (port 80):"
curl -I -s http://localhost | head -1

echo "Testing HTTPS (port 443):"
curl -I -s -k https://localhost | head -1

if command -v ss &> /dev/null; then
    echo -e "\n=== Active Connections ==="
    ss -tan | grep -E ':(80|443)' | wc -l
    echo "connections to ports 80/443"
fi
EOF
    chmod +x monitor_lb.sh
    echo -e "${GREEN}Created monitoring script: monitor_lb.sh${NC}"
}

# Function to create emergency shutdown script
create_emergency_script() {
    cat > emergency_shutdown.sh << 'EOF'
#!/bin/bash
# Emergency shutdown script for CCDC
echo "WARNING: This will stop all load balancer containers"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    echo "Stopping containers..."
    docker-compose down
    echo "Containers stopped. Logs preserved in ./logs directory"
else
    echo "Cancelled."
fi
EOF
    chmod +x emergency_shutdown.sh
    echo -e "${GREEN}Created emergency shutdown script: emergency_shutdown.sh${NC}"
}

# Function to create quick config backup
create_backup_script() {
    cat > backup_config.sh << 'EOF'
#!/bin/bash
# Quick configuration backup
BACKUP_DIR="config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r *.conf *.cfg *.yml "$BACKUP_DIR/" 2>/dev/null
echo "Configuration backed up to: $BACKUP_DIR"
EOF
    chmod +x backup_config.sh
    echo -e "${GREEN}Created backup script: backup_config.sh${NC}"
}

# Main menu
echo "Select load balancer to deploy:"
echo "1) Nginx (good for web apps, easier configuration)"
echo "2) HAProxy (better for pure load balancing, more features)"
echo "3) Create utility scripts only"
echo "4) Exit"
read -p "Choice [1-4]: " choice

case $choice in
    1)
        deploy_nginx
        create_monitor_script
        create_emergency_script
        create_backup_script
        ;;
    2)
        deploy_haproxy
        create_monitor_script
        create_emergency_script
        create_backup_script
        ;;
    3)
        create_monitor_script
        create_emergency_script
        create_backup_script
        echo -e "${GREEN}Utility scripts created in current directory${NC}"
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy the appropriate configuration files to the deployment directory"
echo "2. Review and customize the configuration for your environment"
echo "3. Update backend server addresses in the config"
echo "4. Run 'docker-compose up -d' to start the containers"
echo "5. Use './monitor_lb.sh' to check status"
echo -e "\n${YELLOW}Important for CCDC:${NC}"
echo "- Change default passwords in configs (HAProxy stats, etc.)"
echo "- Review and adjust rate limiting based on scoring engine traffic"
echo "- Test failover by stopping backend containers"
echo "- Monitor logs for suspicious activity"
echo "- Keep backups of working configurations"