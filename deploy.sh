#!/bin/bash

# Make scripts executable
chmod +x secure-setup.sh deploy.sh

# Generate secure passwords
./secure-setup.sh

# Pull latest images
docker-compose pull

# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f