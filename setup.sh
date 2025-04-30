#!/bin/bash
#
# Jenkins Docker Setup Script
# This script helps set up the Jenkins Docker environment for Java, Python, and Go builds

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
  echo -e "${2}${1}${NC}"
}

# Print header
print_header() {
  echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
  print_header "Checking Prerequisites"
  
  local missing_deps=0
  
  # Check Docker
  if command_exists docker; then
    print_message "✅ Docker is installed" "${GREEN}"
    docker_version=$(docker --version | cut -d ' ' -f3 | sed 's/,//')
    print_message "   Version: $docker_version" "${BLUE}"
  else
    print_message "❌ Docker is not installed. Please install Docker first." "${RED}"
    print_message "   https://docs.docker.com/get-docker/" "${YELLOW}"
    missing_deps=1
  fi
  
  # Check Docker Compose
  if command_exists docker-compose; then
    print_message "✅ Docker Compose is installed" "${GREEN}"
    compose_version=$(docker-compose --version | cut -d ' ' -f3 | sed 's/,//')
    print_message "   Version: $compose_version" "${BLUE}"
  else
    print_message "❌ Docker Compose is not installed. Please install Docker Compose first." "${RED}"
    print_message "   https://docs.docker.com/compose/install/" "${YELLOW}"
    missing_deps=1
  fi
  
  # Check Git
  if command_exists git; then
    print_message "✅ Git is installed" "${GREEN}"
    git_version=$(git --version | cut -d ' ' -f3)
    print_message "   Version: $git_version" "${BLUE}"
  else
    print_message "❌ Git is not installed. Please install Git first." "${RED}"
    print_message "   https://git-scm.com/downloads" "${YELLOW}"
    missing_deps=1
  fi
  
  if [ $missing_deps -eq 1 ]; then
    print_message "\nPlease install the missing dependencies and run this script again." "${YELLOW}"
    exit 1
  fi
  
  return 0
}

# Create necessary directories
create_directories() {
  print_header "Creating Directories"
  
  if [ ! -d "jenkins-init-scripts" ]; then
    mkdir -p jenkins-init-scripts
    print_message "✅ Created jenkins-init-scripts directory" "${GREEN}"
  else
    print_message "✅ jenkins-init-scripts directory already exists" "${GREEN}"
  fi
  
  # Create a sample init script if directory is empty
  if [ ! "$(ls -A jenkins-init-scripts)" ]; then
    cat > jenkins-init-scripts/basic-security.groovy << 'EOL'
#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

// Create admin user if it doesn't exist
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
if (hudsonRealm.getAllUsers().isEmpty()) {
    print "Creating admin user"
    hudsonRealm.createAccount("admin", "admin")
    instance.setSecurityRealm(hudsonRealm)
    
    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)
    
    instance.save()
    print "Admin user created"
}
else {
    print "Admin user already exists"
}
EOL
    print_message "✅ Created sample init script for basic security" "${GREEN}"
  fi
  
  return 0
}

# Check Docker daemon status
check_docker_daemon() {
  print_header "Checking Docker Daemon"
  
  if ! docker info > /dev/null 2>&1; then
    print_message "❌ Docker daemon is not running" "${RED}"
    print_message "Please start Docker and run this script again" "${YELLOW}"
    exit 1
  else
    print_message "✅ Docker daemon is running" "${GREEN}"
  fi
  
  return 0
}

# Set permissions
set_permissions() {
  print_header "Setting Permissions"
  
  # Make setup.sh executable
  chmod +x setup.sh
  print_message "✅ Made setup.sh executable" "${GREEN}"
  
  return 0
}

# Validate configuration files
validate_configs() {
  print_header "Validating Configuration Files"
  
  # Check if Dockerfile exists
  if [ -f "Dockerfile" ]; then
    print_message "✅ Dockerfile exists" "${GREEN}"
  else
    print_message "❌ Dockerfile is missing" "${RED}"
    print_message "Please create a Dockerfile before continuing" "${YELLOW}"
    exit 1
  fi
  
  # Check if docker-compose.yml exists
  if [ -f "docker-compose.yml" ]; then
    print_message "✅ docker-compose.yml exists" "${GREEN}"
  else
    print_message "❌ docker-compose.yml is missing" "${RED}"
    print_message "Please create a docker-compose.yml file before continuing" "${YELLOW}"
    exit 1
  fi
  
  # Check if plugins.txt exists
  if [ -f "plugins.txt" ]; then
    print_message "✅ plugins.txt exists" "${GREEN}"
    plugin_count=$(wc -l < plugins.txt | tr -d ' ')
    print_message "   $plugin_count plugins will be installed" "${BLUE}"
  else
    print_message "❌ plugins.txt is missing" "${RED}"
    print_message "Please create a plugins.txt file before continuing" "${YELLOW}"
    exit 1
  fi
  
  return 0
}

# Start Jenkins
start_jenkins() {
  print_header "Starting Jenkins"
  
  print_message "Starting Jenkins container..." "${BLUE}"
  
  if docker-compose up -d; then
    print_message "✅ Jenkins has been started successfully" "${GREEN}"
  else
    print_message "❌ Failed to start Jenkins" "${RED}"
    print_message "Please check the logs for more information: docker-compose logs" "${YELLOW}"
    exit 1
  fi
  
  return 0
}

# Show final instructions
show_instructions() {
  print_header "Setup Complete"
  
  print_message "Jenkins is now running!" "${GREEN}"
  print_message "\nAccess Jenkins at: http://localhost:8080/jenkins" "${BLUE}"
  print_message "\nInitial admin password can be retrieved with:" "${BLUE}"
  print_message "docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword" "${YELLOW}"
  
  # Try to get the initial admin password
  sleep 5
  if docker ps | grep -q jenkins; then
    print_message "\nWaiting for Jenkins to initialize..." "${BLUE}"
    for i in {1..12}; do
      if docker exec jenkins ls /var/jenkins_home/secrets/initialAdminPassword > /dev/null 2>&1; then
        password=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
        if [ ! -z "$password" ]; then
          print_message "\nInitial Admin Password: $password" "${GREEN}"
          break
        fi
      fi
      print_message "." "${BLUE}"
      sleep 5
    done
  fi
  
  print_message "\nRefer to the README.md file for detailed configuration instructions." "${BLUE}"
  
  return 0
}

# Main function
main() {
  print_message "Jenkins Docker Setup Script" "${BLUE}"
  print_message "This script will set up Jenkins with Java, Python, and Go build support" "${BLUE}"
  
  check_prerequisites
  check_docker_daemon
  create_directories
  set_permissions
  validate_configs
  
  print_message "\nAll checks passed! Ready to start Jenkins." "${GREEN}"
  read -p "Do you want to start Jenkins now? [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    start_jenkins
    show_instructions
  else
    print_message "\nSetup completed without starting Jenkins." "${YELLOW}"
    print_message "Run 'docker-compose up -d' when you're ready to start Jenkins." "${BLUE}"
  fi
  
  return 0
}

# Run the main function
main

