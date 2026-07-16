#!/bin/bash
set -euo pipefail

echo "[idm2] Iniciando entrypoint..."

CA_CERT=/etc/fis-ca/certs/ca.cert.pem
COUNTER=0
until [ -f "$CA_CERT" ] || [ $COUNTER -ge 30 ]; do
  echo "[idm2] Esperando certificado de la CA... ($COUNTER/30)"
  sleep 1
  COUNTER=$((COUNTER+1))
done

if [ ! -f "$CA_CERT" ]; then
  echo "[idm2] ERROR: no se encontro el certificado de la CA tras 30s."
  exit 1
fi

COUNTER=0
until nc -z idm1 636 2>/dev/null || [ $COUNTER -ge 30 ]; do
  echo "[idm2] Esperando a que idm1:636 este disponible... ($COUNTER/30)"
  sleep 2
  COUNTER=$((COUNTER+1))
done

/usr/local/bin/init-ldap-replica.sh

echo "[idm2] Inicializacion completa. Lanzando supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf