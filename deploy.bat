@echo off
echo Deploying Flowise...

REM Generate secure passwords (run secure-setup first)
call secure-setup.bat

REM Pull latest images
docker-compose pull

REM Start services
docker-compose up -d

REM Check status
docker-compose ps

echo.
echo Deployment complete! Check logs with: docker-compose logs -f
pause