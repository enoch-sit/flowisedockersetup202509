@echo off
echo === Container Status ===
docker-compose ps

echo.
echo === Disk Usage ===
docker system df

echo.
echo === Recent Errors ===
docker-compose logs --tail=50 | findstr /i error

echo.
echo === Database Status ===
docker-compose exec postgres pg_isready -U flowise_admin

echo.
echo === Monitoring Complete ===
pause