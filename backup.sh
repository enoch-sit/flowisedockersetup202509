#!/bin/bash

# Backup directory
BACKUP_DIR="/home/$USER/flowise-backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup database
docker-compose exec -T postgres pg_dump -U flowise_admin flowise_production > $BACKUP_DIR/flowise_db_$DATE.sql

# Backup Flowise data
docker run --rm -v flowise-production_flowise_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/flowise_data_$DATE.tar.gz -C /data .

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"