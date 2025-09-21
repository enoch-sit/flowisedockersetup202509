#!/bin/bash

# Ensure scripts are executable
chmod +x secure-setup.sh deploy.sh

echo "=== Generating secure passwords and configurations ==="
# Generate secure passwords if the script exists
if [ -f "./secure-setup.sh" ]; then
    ./secure-setup.sh
fi

echo "=== Shutting down existing services and removing volumes ==="
# Stop and remove all containers, networks, and volumes for a clean slate
sudo docker-compose down -v

echo "=== Pulling the latest images ==="
# Pull the latest versions of the images specified in docker-compose.yml
sudo docker-compose pull

echo "=== Starting services in detached mode ==="
# Build images if necessary and start the services
sudo docker-compose up --build -d

echo "=== Current status of services ==="
# Check the status of the running containers
sudo docker-compose ps

echo "=== Tailing logs (press Ctrl+C to exit) ==="
# Follow the logs for all services
sudo docker-compose logs -f
