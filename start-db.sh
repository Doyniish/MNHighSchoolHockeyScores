#!/bin/bash
# Start PostgreSQL database only (for local development)
docker compose up db -d
echo "✓ PostgreSQL is starting..."
sleep 2
echo ""
echo "Database connection details:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Username: vapor_username"
echo "  Password: vapor_password"
echo "  Database: vapor_database"
echo ""
echo "Check status with: docker compose ps"
echo "View logs with:    docker compose logs db"
echo "Stop database with: docker compose down"
