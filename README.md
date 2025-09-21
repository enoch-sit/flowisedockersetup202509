# Flowise Setup - Integration with Existing Nginx

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

   ```cmd
   deploy.bat
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
Run `secure-setup.bat` or manually generate secure passwords for:

- PostgreSQL database
- Flowise admin account
- Secret key for encryption

## Useful Commands

```cmd
# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop and remove all data
docker-compose down -v

# Check service status
docker-compose ps

# Monitor system
monitor.bat
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

```
flowise-production/
├── docker-compose.yml      # Main Docker configuration
├── .env                    # Environment variables
├── nginx/                  # Nginx reverse proxy config
├── init-db/               # PostgreSQL initialization
├── ssl/certs/             # SSL certificates
├── *.bat                  # Windows batch scripts
└── *.sh                   # Linux/WSL bash scripts
```
