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
     - Pulls Docker images (flowiseai/flowise:3.0.4, postgres:16-alpine)
     - Starts PostgreSQL and Flowise containers
     - Initializes database with record manager tables
   - **Wait time**: 2-3 minutes for full startup

4. **Nginx Integration**
   - Copy contents of `nginx-integration.conf`
   - Add to your existing Nginx server block
   - Test config: `nginx -t`
   - Reload: `nginx -s reload` or `systemctl reload nginx`

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

   ```cmd
   cd c:\Users\thank\Documents\thankGodForJesusChrist\thankGodForWork\proj01_chatbot_edu\week04\flowisesetup\flowise-production
   ```

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

   - <https://yourdomain.com/flowise2025>

## Nginx Integration

Since you have existing Nginx with SSL, this setup only runs Flowise and PostgreSQL in Docker. Add the following to your existing Nginx server block:

```nginx
# Add these location blocks to your existing server configuration
location /flowise2025/ {
    proxy_pass http://localhost:3000/;
    proxy_http_version 1.1;
    
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Prefix /flowise2025;
    
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    
    proxy_buffering off;
    proxy_request_buffering off;
}

location /flowise2025/api/ {
    proxy_pass http://localhost:3000/api/;
    proxy_http_version 1.1;
    
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    proxy_connect_timeout 600s;
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
}

location /flowise2025/socket.io/ {
    proxy_pass http://localhost:3000/socket.io/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## Understanding the Nginx Configuration

### Socket.IO Specific Handling Explained

The Socket.IO configuration block is crucial for Flowise's real-time features:

```nginx
location /flowise2025/socket.io/ {
    proxy_pass http://localhost:3000/socket.io/;
    # ... WebSocket headers
}
```

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

**What happens without this block?**

- ❌ Chat messages would require manual page refresh to appear
- ❌ Flow execution would appear frozen
- ❌ Real-time debugging wouldn't work
- ❌ Connection status would be unreliable

**The three location blocks work together:**

1. `/flowise2025/` - Main Flowise application (UI, pages, static content)
2. `/flowise2025/api/` - REST API calls (creating flows, authentication, data operations)
3. `/flowise2025/socket.io/` - Real-time WebSocket connections (live updates, chat, debugging)

### 🔄 Nginx Proxy Concepts Explained

Understanding the key proxy directives used in the Flowise API configuration:

#### **`proxy_pass http://localhost:3000/api/;`**

- **What it does**: Forwards all requests from `/flowise2025/api/` to `http://localhost:3000/api/`
- **URL Rewriting**: The trailing slash removes the matched location prefix
  - **Client requests**: `https://yourdomain.com/flowise2025/api/v1/chatflows`
  - **Nginx forwards to**: `http://localhost:3000/api/v1/chatflows`
- **Purpose**: Routes API calls to your Flowise Docker container running on port 3000

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
- **Example**: `yourdomain.com/flowise2025/api/` → Backend sees `Host: yourdomain.com`
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

1. **Port conflicts:** Make sure ports 80 and 443 are available
2. **Docker not running:** Ensure Docker Desktop is started
3. **Permission issues:** Run cmd as administrator if needed
4. **SSL issues:** For local testing, disable SSL in nginx config

## Default Login

- Username: admin
- Password: FlowiseAdmin2025! (change this!)

## File Structure

```text
flowise-production/
├── docker-compose.yml          # Main Docker configuration (Flowise 3.0.4 + PostgreSQL)
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
