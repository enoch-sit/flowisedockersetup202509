#!/bin/bash

# =============================================================================
# Flowise Password Reset Script
# Repository: enoch-sit/flowisedockersetup202509
# Author: Enoch Sit
# Date: 2025-01-25
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENV_FILE=".env"
POSTGRES_CONTAINER="flowise-postgres"

# Get database credentials from .env
POSTGRES_DB=$(grep "^POSTGRES_DB=" "$ENV_FILE" | cut -d'=' -f2 || echo "flowise_production")
POSTGRES_USER=$(grep "^POSTGRES_USER=" "$ENV_FILE" | cut -d'=' -f2 || echo "flowise_admin")

# Function to execute PostgreSQL query
exec_sql() {
    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c "$1"
}

clear
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         FLOWISE PASSWORD RESET UTILITY               ║${NC}"
echo -e "${BLUE}║         Select User to Reset Password                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Display all users
echo -e "${GREEN}Available Users in Database:${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"

# Get all users
USERS=$(exec_sql "SELECT ROW_NUMBER() OVER (ORDER BY email) || '|' || email || '|' || name || '|' || status FROM \"user\"")

if [ -z "$USERS" ]; then
    echo -e "${RED}No users found in database!${NC}"
    exit 1
fi

# Display users in a table format
printf "%-4s %-30s %-20s %-10s\n" "No." "Email" "Name" "Status"
echo "─────────────────────────────────────────────────────────────────"

IFS=$'\n'
for user in $USERS; do
    IFS='|' read -r num email name status <<< "$user"
    printf "%-4s %-30s %-20s %-10s\n" "$num" "$email" "$name" "$status"
done
echo ""

# Step 2: Get user selection
echo -e "${BLUE}Select user to reset password:${NC}"
read -p "Enter number (1-$(echo "$USERS" | wc -l)): " selection

# Validate selection
if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Invalid selection! Please enter a number.${NC}"
    exit 1
fi

# Get selected user details
SELECTED_USER=$(echo "$USERS" | sed -n "${selection}p")
if [ -z "$SELECTED_USER" ]; then
    echo -e "${RED}Invalid selection!${NC}"
    exit 1
fi

IFS='|' read -r num email name status <<< "$SELECTED_USER"

echo ""
echo -e "${YELLOW}Selected User:${NC}"
echo "  Email: $email"
echo "  Name: $name"
echo "  Status: $status"
echo ""

# Step 3: Get new password
echo -e "${GREEN}Enter new password for $name:${NC}"
read -sp "New password: " NEW_PASSWORD
echo ""
read -sp "Confirm password: " CONFIRM_PASSWORD
echo ""

if [ "$NEW_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
    echo -e "${RED}Passwords do not match!${NC}"
    exit 1
fi

# Step 4: Generate bcrypt hash
echo ""
echo -e "${YELLOW}Generating password hash...${NC}"

# Check if bcrypt is installed
if ! python3 -c "import bcrypt" 2>/dev/null; then
    echo "Installing bcrypt..."
    pip3 install bcrypt --quiet
fi

HASH=$(python3 << EOF
import bcrypt
password = b'$NEW_PASSWORD'
salt = bcrypt.gensalt(rounds=5)  # Match existing hash format
hashed = bcrypt.hashpw(password, salt)
print(hashed.decode('utf-8'))
EOF
)

if [ -z "$HASH" ]; then
    echo -e "${RED}Failed to generate password hash!${NC}"
    exit 1
fi

# Step 5: Update password in database
echo -e "${YELLOW}Updating password in database...${NC}"
UPDATE_RESULT=$(exec_sql "UPDATE \"user\" SET credential = '$HASH', \"updatedDate\" = NOW() WHERE email = '$email' RETURNING email")

if [ -n "$UPDATE_RESULT" ]; then
    echo -e "${GREEN}✓ Password successfully updated!${NC}"
    echo ""
    
    # Save password to backup file (optional)
    BACKUP_FILE=".password_$(echo $email | tr '@.' '_')_$(date +%Y%m%d_%H%M%S).txt"
    echo "Password Reset Record" > "$BACKUP_FILE"
    echo "Date: $(date)" >> "$BACKUP_FILE"
    echo "User: $email ($name)" >> "$BACKUP_FILE"
    echo "New Password: $NEW_PASSWORD" >> "$BACKUP_FILE"
    chmod 600 "$BACKUP_FILE"
    
    echo -e "${YELLOW}Password saved to: $BACKUP_FILE${NC}"
    echo -e "${YELLOW}(Keep this file secure and delete after memorizing)${NC}"
    echo ""
    
    # Step 6: Check authentication method
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    
    # Check if environment auth is active
    if grep -q "^FLOWISE_USERNAME=" "$ENV_FILE" 2>/dev/null; then
        echo -e "${RED}⚠️  WARNING: Environment authentication is ACTIVE!${NC}"
        echo -e "${YELLOW}The password you just set will NOT work until you disable it.${NC}"
        echo ""
        echo "To use the new password, do ONE of the following:"
        echo ""
        echo "Option A: Disable environment authentication:"
        echo -e "${GREEN}  sed -i 's/^FLOWISE_USERNAME/#FLOWISE_USERNAME/' .env${NC}"
        echo -e "${GREEN}  sed -i 's/^FLOWISE_PASSWORD/#FLOWISE_PASSWORD/' .env${NC}"
        echo -e "${GREEN}  docker-compose restart${NC}"
        echo ""
        echo "Option B: Keep using environment auth with:"
        ENV_USER=$(grep "^FLOWISE_USERNAME=" "$ENV_FILE" | cut -d'=' -f2)
        ENV_PASS=$(grep "^FLOWISE_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)
        echo -e "${GREEN}  Username: $ENV_USER${NC}"
        echo -e "${GREEN}  Password: $ENV_PASS${NC}"
    else
        echo -e "${GREEN}✓ Database authentication is active${NC}"
        echo ""
        echo -e "${BLUE}LOGIN CREDENTIALS:${NC}"
        echo -e "${GREEN}  URL: http://localhost:3000${NC}"
        echo -e "${GREEN}  Username: $email${NC}"
        echo -e "${GREEN}  Password: $NEW_PASSWORD${NC}"
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}Failed to update password!${NC}"
    exit 1
fi
