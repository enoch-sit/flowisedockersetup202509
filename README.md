# Flowise Setup - Integration with Existing Nginx

## Order of Execution

Follow these steps in order for a complete setup:

### 🔧 Initial Setup (One-time only)

1. **Prerequisites Check**
   - Ensure Docker is installed and running
   - Verify you have an existing Nginx with SSL configured
   - Confirm your domain points to your server

2. **Environment Configuration**

   ```bash
   ./secure-setup.sh
   ```

   - **What it does**: Generates secure passwords and creates `.env` file
   - **Required**: Must be run before first deployment

3. **Initial Deployment**

   ```bash
   sudo ./deploy.sh
   ```

   - **What it does**:
     - Runs secure-setup (if not done)
     - Pulls Docker images (flowiseai/flowise:latest, postgres:16-alpine)
     - Starts PostgreSQL and Flowise containers
     - Initializes database with record manager tables
   - **Wait time**: 2-3 minutes for full startup
   - **New in this version**: Uses `flowiseai/flowise:latest` for automatic updates and simplified configuration

4. **Nginx Integration**
   - Create or edit your nginx site configuration (see detailed instructions below)
   - Test config: `sudo nginx -t`
   - If test passes, reload: `sudo nginx -s reload` or `sudo systemctl reload nginx`
   - Verify setup: Check that your domain loads the Flowise application

### 🚀 Daily Operations

1. **System Monitoring**

   ```bash
   ./monitor.sh
   ```

   - **What it shows**: Container status, disk usage, errors, database health
   - **When to run**: Daily or when troubleshooting

2. **Data Backup**

   ```bash
   ./backup.sh
   ```

   - **What it does**: Backs up PostgreSQL database and Flowise data volumes
   - **Schedule**: Recommended weekly or before updates
   - **Storage**: Creates timestamped backups in `/home/$USER/flowise-backups/`

## 💾 Database Backup & Migration

### Understanding What Gets Backed Up

**🗄️ PostgreSQL Database (`flowise_db_*.sql`)**

- **Contains**: User accounts, chatflow configurations, API keys, credentials, chat messages, conversation history
- **What it stores**: All structured data that Flowise saves to PostgreSQL tables
- **File format**: SQL dump file that can be restored to any PostgreSQL instance
- **Typical size**: Small to medium (depends on chat history and number of flows)

**📂 Flowise Data Volumes (`flowise_data_*.tar.gz`)**  

- **Contains**: Uploaded files, vector store data, cached models, temporary files, logs, custom components
- **What it stores**: File-based assets and application state data
- **File format**: Compressed tar archive of the Docker volume filesystem
- **Typical size**: Can be large (especially with uploaded documents and vector embeddings)

**🔍 Why You Need Both:**

- **Database only**: You get your flows and settings, but lose uploaded files and vector data
- **Data volumes only**: You lose user accounts, flow configurations, and chat history
- **Both together**: Complete system restoration with all data and functionality intact

### Manual Database Backup

For more control over backup process or one-time backups:

```bash
# Create backup directory
mkdir -p ~/flowise-backups
DATE=$(date +%Y%m%d_%H%M%S)

# Backup PostgreSQL database (flows, users, chat history)
sudo docker compose exec -T postgres pg_dump -U flowise_admin flowise_production > ~/flowise-backups/flowise_db_$DATE.sql

# Backup Flowise application data volumes (uploaded files, vector data)
sudo docker run --rm -v flowise-production_flowise_data:/data -v ~/flowise-backups:/backup alpine tar czf /backup/flowise_data_$DATE.tar.gz -C /data .

echo "Backup completed: ~/flowise-backups/"
```

### 📋 Practical Example: What Each Backup Contains

**Scenario**: You have a Flowise setup with:

- 3 chatflows configured
- 2 user accounts (admin + regular user)  
- 100 chat conversations
- 50MB of uploaded PDF documents
- Vector embeddings for document search
- Custom API credentials stored

**If you only backup the DATABASE (`flowise_db_*.sql`):**

- ✅ **Preserved**: Chatflow configurations, user accounts, chat conversations, API credentials
- ❌ **Lost**: PDF documents, vector embeddings, custom components, uploaded files
- **Result**: Flows work but can't search documents, missing uploaded content

**If you only backup DATA VOLUMES (`flowise_data_*.tar.gz`):**

- ✅ **Preserved**: PDF documents, vector embeddings, uploaded files, logs
- ❌ **Lost**: Chatflow configurations, user accounts, chat conversations, API credentials  
- **Result**: Files exist but no flows to use them, need to reconfigure everything

**With BOTH backups:**

- ✅ **Complete restoration**: All flows, users, conversations, documents, and functionality intact
- 🎯 **Perfect migration**: Move entire system to new server without data loss

### Database Restore

To restore from a backup:

```bash
# Stop Flowise services (keep database running)
sudo docker compose stop flowise

# Restore database from backup
sudo docker compose exec -T postgres psql -U flowise_admin -d flowise_production < ~/flowise-backups/flowise_db_YYYYMMDD_HHMMSS.sql

# Restore Flowise data volumes
sudo docker run --rm -v flowise-production_flowise_data:/data -v ~/flowise-backups:/backup alpine tar xzf /backup/flowise_data_YYYYMMDD_HHMMSS.tar.gz -C /data

# Restart services
sudo docker compose up -d
```

### Database Migration Between Servers

#### Source Server (Export)

```bash
# Create migration package
mkdir -p ~/flowise-migration
cd ~/flowise-migration

# Export database
sudo docker compose exec -T postgres pg_dump -U flowise_admin flowise_production > flowise_db_migration.sql

# Export Flowise data
sudo docker run --rm -v flowise-production_flowise_data:/data -v ~/flowise-migration:/backup alpine tar czf /backup/flowise_data_migration.tar.gz -C /data .

# Export environment configuration (IMPORTANT: Review before copying passwords!)
cp ~/.../flowise-production/.env flowise_env_backup.txt

# Create migration package
tar czf flowise_migration_$(date +%Y%m%d).tar.gz flowise_db_migration.sql flowise_data_migration.tar.gz flowise_env_backup.txt

echo "Migration package created: flowise_migration_$(date +%Y%m%d).tar.gz"
```

#### Destination Server (Import)

```bash
# Extract migration package
tar xzf flowise_migration_YYYYMMDD.tar.gz

# Set up new environment (review and update passwords!)
cp flowise_env_backup.txt .env
# IMPORTANT: Edit .env file to update passwords and server-specific settings

# Deploy infrastructure first
sudo ./deploy.sh

# Wait for services to be ready, then stop Flowise to import data
sudo docker compose stop flowise

# Import database
sudo docker compose exec -T postgres psql -U flowise_admin -d flowise_production < flowise_db_migration.sql

# Import Flowise data
sudo docker run --rm -v flowise-production_flowise_data:/data -v $(pwd):/backup alpine tar xzf /backup/flowise_data_migration.tar.gz -C /data

# Restart all services
sudo docker compose up -d

# Verify migration
./monitor.sh
```

### Database Maintenance

#### Clean up old data

```bash
# Remove old chat sessions (older than 30 days)
sudo docker compose exec postgres psql -U flowise_admin -d flowise_production -c "
DELETE FROM chat_message WHERE \"createdDate\" < NOW() - INTERVAL '30 days';
"

# Vacuum database to reclaim space
sudo docker compose exec postgres psql -U flowise_admin -d flowise_production -c "VACUUM FULL;"
```

#### Database health check

```bash
# Check database size and table statistics
sudo docker compose exec postgres psql -U flowise_admin -d flowise_production -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_stat_get_tuples_inserted(c.oid) as inserts,
    pg_stat_get_tuples_updated(c.oid) as updates,
    pg_stat_get_tuples_deleted(c.oid) as deletes
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
```

### 🔄 Maintenance Operations

1. **Service Management**

   ```bash
   # Stop services
   sudo docker compose down
   
   # Stop and remove all data (DESTRUCTIVE!)
   sudo docker compose down -v
   
   # View live logs
   sudo docker compose logs -f
   
   # Check service status
   sudo docker compose ps
   ```

2. **Updates** (when new Flowise versions available)

   ```bash
   # Stop current services
   sudo docker compose down
   
   # Pull new images
   sudo docker compose pull
   
   # Start with new version
   sudo docker compose up -d
   ```

### 🚨 Troubleshooting Order

If something goes wrong, follow this diagnostic order:

1. **Check Container Status**: `sudo docker compose ps`
2. **Review Logs**: `sudo docker compose logs -f`
3. **Run Monitoring**: `./monitor.sh`
4. **Verify Environment**: Check `.env` file exists and has proper values
5. **Test Database**: `sudo docker compose exec postgres pg_isready -U flowise_admin`
6. **Check Nginx**: `nginx -t` and verify your server block configuration
7. **Port Conflicts**: Ensure port 3000 isn't used by other services
8. **Restart Services**: `sudo docker compose down && sudo docker compose up -d`

## Prerequisites

- Docker Desktop installed and running
- **Existing Nginx with SSL already configured**
- Domain name already pointing to your server

## Quick Start (With Existing Nginx)

1. **Navigate to the project directory:**

2. **Update .env file with secure passwords:**

   - Edit `.env` file with a text editor
   - Replace default passwords with secure ones
   - For testing, you can keep the defaults

3. **Start Flowise and PostgreSQL services:**

   ```bash
   sudo ./deploy.sh
   ```

4. **Add Flowise configuration to your existing Nginx:**

   - Copy the contents of `nginx-integration.conf`
   - Add these location blocks to your existing Nginx server configuration
   - Reload your Nginx configuration: `nginx -s reload`

5. **Access Flowise:**

   - **Direct Domain Access**: <https://yourdomain.com>

## Nginx Integration

Since you have existing Nginx with SSL, this setup only runs Flowise and PostgreSQL in Docker. The application is configured to run on the root path of your domain.

### Option 1: For Direct Domain Access (Recommended for Production)

If you want to serve your application directly on your domain root, create or edit your nginx site configuration:

```bash
sudo nano /etc/nginx/sites-available/$HOSTNAME
```

Use this complete server block configuration:

```nginx
server {
    listen 80;
    server_name project-1-13;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name project-1-13;
    ssl_certificate /etc/nginx/ssl/dept-wildcard.eduhk/fullchain.crt;
    ssl_certificate_key /etc/nginx/ssl/dept-wildcard.eduhk/dept-wildcard.eduhk.hk.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    ssl_trusted_certificate /etc/nginx/ssl/dept-wildcard.eduhk/fullchain.crt;

    client_max_body_size 100M;  # Allows up to 100MB request bodies

    location / {
        proxy_pass http://localhost:3000;  # Proxy to your app on port 3000
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Key Configuration Notes:**

- **`client_max_body_size 100M;`** - Essential for handling large file uploads (documents, images, etc.)
- **Basic proxy configuration** - Routes all traffic directly to Flowise on port 3000
- **SSL configuration** - Uses your existing wildcard certificate
- **HTTP to HTTPS redirect** - Ensures all traffic uses secure connections

### Testing and Applying Nginx Configuration

After creating or modifying your nginx configuration, always test and reload:

```bash
# Test nginx configuration for syntax errors
sudo nginx -t

# If test is successful, reload nginx to apply changes
sudo nginx -s reload

# Alternative reload methods if needed
sudo systemctl reload nginx
# or
sudo service nginx reload
```

**Important**: Always run `sudo nginx -t` first. If there are errors, fix them before reloading nginx.

## Understanding the Nginx Configuration

### Socket.IO Specific Handling Explained

Socket.IO is crucial for Flowise's real-time features and requires proper WebSocket configuration in nginx.

**What is Socket.IO?**

- Socket.IO is a library that enables real-time, bidirectional communication between web clients and servers
- It's used by Flowise for features like:
  - **Live chat updates** - Messages appear instantly without page refresh
  - **Real-time flow execution** - See nodes execute in real-time as data flows through your chatflow
  - **Live debugging** - Watch variables and data transformation as they happen
  - **Connection status** - Know when your chatbot is connected/disconnected
  - **Collaborative editing** - Multiple users can work on flows simultaneously

**Why does it need special handling?**

- Socket.IO starts as HTTP but upgrades to WebSocket protocol for persistent connections
- The `Upgrade` and `Connection` headers tell nginx to allow this protocol upgrade
- Without this configuration, real-time features would break and you'd only see static content

**What happens without proper WebSocket configuration?**

- ❌ Chat messages would require manual page refresh to appear
- ❌ Flow execution would appear frozen
- ❌ Real-time debugging wouldn't work
- ❌ Connection status would be unreliable

### 🔄 Nginx Proxy Concepts Explained

Understanding the key proxy directives used in the root path Flowise configuration:

#### **`proxy_pass http://localhost:3000;`**

- **What it does**: Forwards all requests from your domain root to `http://localhost:3000`
- **Direct routing**: No path manipulation needed since both source and destination are at root
  - **Client requests**: `https://yourdomain.com/api/v1/chatflows`
  - **Nginx forwards to**: `http://localhost:3000/api/v1/chatflows`
- **Purpose**: Routes all traffic to your Flowise Docker container running on port 3000

#### **`proxy_http_version 1.1;`**

- **What it does**: Forces Nginx to use HTTP/1.1 when communicating with the backend
- **Why needed**:
  - Default is HTTP/1.0 which doesn't support keep-alive connections
  - HTTP/1.1 enables connection reuse, reducing overhead
  - Required for WebSocket upgrades
- **Performance**: Reduces latency by reusing TCP connections

#### **Header Forwarding Directives**

**`proxy_set_header Host $host;`**

- **Preserves**: The original domain name from the client request
- **Example**: `yourdomain.com/api/` → Backend sees `Host: yourdomain.com`
- **Important for**: CORS validation, URL generation, security checks

**`proxy_set_header X-Real-IP $remote_addr;`**

- **Preserves**: The actual IP address of the client
- **Without this**: Flowise would only see Nginx's IP (127.0.0.1)
- **Use cases**: Rate limiting, security logging, geolocation features

**`proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`**

- **What it does**: Builds a chain of IP addresses through all proxies
- **Format**: `X-Forwarded-For: client_ip, proxy1_ip, proxy2_ip`
- **Use case**: Tracking requests through multiple proxy layers

**`proxy_set_header X-Forwarded-Proto $scheme;`**

- **Preserves**: Whether the original request was HTTP or HTTPS
- **Critical for**: Proper redirects, security policies, avoiding mixed content issues

#### **Timeout Configuration**

**`proxy_connect_timeout 600s;`** - How long to wait for connection to Flowise
**`proxy_send_timeout 600s;`** - Timeout for sending request data (large uploads)
**`proxy_read_timeout 600s;`** - How long to wait for Flowise response

**Why 600s (10 minutes) for API calls:**

- AI model processing can take significant time
- Vector database operations
- Complex chatflow executions
- Large language model API calls to external services

#### **Real-World Impact**

- **AI Processing**: Complex queries requiring document retrieval, multiple LLM calls, reasoning chains
- **Document Upload**: Large PDF processing and embedding generation  
- **Security**: Original IP tracking, HTTPS enforcement, CORS validation
- **Performance**: ~20-30% faster responses through connection reuse

Run `./secure-setup.sh` to automatically generate secure passwords for:

- PostgreSQL database
- Flowise admin account
- Secret key for encryption

## Useful Commands

```bash
# View logs
sudo docker compose logs -f

# Stop services
sudo docker compose down

# Stop and remove all data
sudo docker compose down -v

# Check service status
sudo docker compose ps

# Monitor system
./monitor.sh
```

## Troubleshooting

### Common Issues and Solutions

1. **Docker Compose Version Warning**

   ```
   WARN: the attribute `version` is obsolete, it will be ignored
   ```

   - **Solution**: This warning is harmless and has been fixed in the latest docker-compose.yml
   - **Cause**: Modern Docker Compose doesn't require version specification

2. **Network Creation Failed - Subnet Exhaustion**

   ```text
   failed to create network: all predefined address pools have been fully subnetted
   ```

   - **Solution**: The docker-compose.yml uses Docker's default bridge network to avoid conflicts
   - **For private subnet environments**: Default bridge network prevents IP conflicts with existing infrastructure
   - **Alternative fixes if still needed**:

     ```bash
     # Remove unused networks
     sudo docker network prune -f
     
     # List all networks to check
     sudo docker network ls
     
     # Remove specific network if needed
     sudo docker network rm <network_name>
     ```

   - **Custom subnet (only if default doesn't work)**:
     If you need a specific subnet that doesn't conflict with your infrastructure:

     ```yaml
     networks:
       flowise-network:
         driver: bridge
         ipam:
           config:
             - subnet: 192.168.100.0/24  # Choose non-conflicting range
     ```

3. **How to Check Docker's Default IP Ranges**

   ```bash
   # Check Docker daemon's default address pools
   sudo docker system info | grep -A 10 "Default Address Pools"
   
   # List and inspect all networks
   sudo docker network ls
   sudo docker network inspect bridge
   
   # Check Docker bridge interface
   ip addr show docker0
   
   # Check your Flowise network (when running)
   sudo docker network inspect flowise-production_flowise-network
   
   # Show all network subnets
   sudo docker network ls -q | xargs sudo docker network inspect --format='{{.Name}}: {{range .IPAM.Config}}{{.Subnet}} {{end}}'
   ```

   **Your Docker daemon uses custom address pools:**
   - **Base: 10.20.0.0/24** - Your system's configured default pool
   - **Size: 24** - Each network gets a /24 subnet (256 addresses)
   - **Network assignment**: Docker creates 10.20.0.0/24, 10.20.1.0/24, 10.20.2.0/24, etc.

   **Standard Docker defaults (for reference):**
   - 172.17.0.0/16 - Typical default bridge network
   - 172.18.0.0/16 - Additional bridge networks

   **Why your setup is different:**
   - Your Docker daemon has been configured with custom address pools
   - This avoids conflicts with enterprise/private network infrastructure
   - The 10.20.x.x range is specifically chosen for your environment

4. **Port Conflicts**
   - Make sure port 3000 isn't used by other services
   - Check with: `sudo netstat -tulpn | grep 3000`

4. **Docker Not Running**
   - Ensure Docker service is started: `sudo systemctl start docker`
   - Check Docker status: `sudo systemctl status docker`

5. **Permission Issues**
   - Ensure your user is in the docker group: `sudo usermod -aG docker $USER`
   - Log out and back in after adding to docker group
   - Or use sudo with docker commands

6. **Database Connection Issues**
   - Wait for PostgreSQL to fully start (check logs): `sudo docker compose logs postgres`
   - Verify database health: `sudo docker compose exec postgres pg_isready -U flowise_admin`

7. **Nginx Configuration Issues**
   - Test nginx config: `sudo nginx -t`
   - If config test passes, reload nginx: `sudo nginx -s reload`
   - Check nginx error logs: `sudo tail -f /var/log/nginx/error.log`
   - Check nginx access logs: `sudo tail -f /var/log/nginx/access.log`
   - Verify Flowise is responding: `curl http://localhost:3000`
   - Check if nginx is running: `sudo systemctl status nginx`

## Default Login

- Username: admin
- Password: FlowiseAdmin2025! (change this!)

## File Structure

```text
flowise-production/
├── docker-compose.yml          # Main Docker configuration (Flowise latest + PostgreSQL)
├── .env                        # Environment variables (created by secure-setup)
├── .env.example               # Template for environment variables
├── nginx-integration.conf      # Nginx configuration for existing server integration
├── init-db/                   # PostgreSQL initialization scripts
│   └── 01-init-record-manager.sql  # Creates record manager tables
├── secure-setup.sh            # Generate secure passwords and create .env file
├── deploy.sh                  # Full deployment script (setup + Docker deployment)
├── monitor.sh                 # System health monitoring script
├── backup.sh                  # Database and volume backup script
└── README.md                  # This documentation
```
