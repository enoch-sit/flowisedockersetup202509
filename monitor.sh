#!/bin/bash

# Check container status
echo "=== Container Status ==="
docker-compose ps

# Check disk usage
echo -e "\n=== Disk Usage ==="
docker system df

# Check logs for errors
echo -e "\n=== Recent Errors ==="
docker-compose logs --tail=50 | grep -i error

# Database connection test
echo -e "\n=== Database Status ==="
docker-compose exec postgres pg_isready -U flowise_admin

# Check Flowise health
echo -e "\n=== Flowise Health ==="
curl -s -o /dev/null -w "%{http_code}" https://yourdomain.com/flowise2025/