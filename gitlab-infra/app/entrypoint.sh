#!/bin/sh

# Attendre que la DB soit prête si PostgreSQL
if [ "$DB_ENGINE" = "postgresql" ] && [ -n "$DB_HOST" ]; then
  echo "Waiting for database at $DB_HOST:${DB_PORT:-5432}..."
  while ! python -c "
import socket, sys, os
try:
    socket.create_connection((os.environ['DB_HOST'], int(os.environ.get('DB_PORT', 5432))), timeout=2)
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; do
    echo "DB not ready, retrying in 2s..."
    sleep 2
  done
  echo "Database is ready!"
fi

# Appliquer les migrations
echo "Running migrations..."
python manage.py migrate --noinput

# Collecter les static files (pour whitenoise)
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Créer le superuser admin si les variables sont définies
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
  echo "Creating superuser if not exists..."
  python manage.py createsuperuser --noinput --username "$DJANGO_SUPERUSER_USERNAME" --email "$DJANGO_SUPERUSER_EMAIL" 2>/dev/null || echo "Superuser already exists"
fi

# Créer le dossier de backup
mkdir -p /app/backups

# Lancer l'app
exec "$@"
