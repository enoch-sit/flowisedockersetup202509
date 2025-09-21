#!/bin/bash

# Generate secure passwords
echo "Generating secure passwords..."

# Generate random password for PostgreSQL
POSTGRES_PASS=$(openssl rand -base64 32)
echo "PostgreSQL Password: $POSTGRES_PASS"

# Generate random password for Flowise
FLOWISE_PASS=$(openssl rand -base64 20)
echo "Flowise Password: $FLOWISE_PASS"

# Generate secret key
SECRET_KEY=$(openssl rand -hex 32)
echo "Secret Key: $SECRET_KEY"

# Update .env file
cat > .env << EOF
# Database Configuration
POSTGRES_DB=flowise_production
POSTGRES_USER=flowise_admin
POSTGRES_PASSWORD=$POSTGRES_PASS

# Flowise Authentication
FLOWISE_USERNAME=admin
FLOWISE_PASSWORD=$FLOWISE_PASS

# Encryption key for credentials
FLOWISE_SECRETKEY_OVERWRITE=$SECRET_KEY
EOF

echo "Passwords saved to .env file"
echo "IMPORTANT: Save these passwords in a secure location!"

# Set proper permissions
chmod 600 .env