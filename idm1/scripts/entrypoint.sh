#!/bin/bash
set -euo pipefail

echo "[idm1] Iniciando entrypoint..."

CA_CERT=/etc/fis-ca/certs/ca.cert.pem
COUNTER=0
until [ -f "$CA_CERT" ] || [ $COUNTER -ge 30 ]; do
  echo "[idm1] Esperando certificado de la CA... ($COUNTER/30)"
  sleep 1
  COUNTER=$((COUNTER+1))
done

if [ ! -f "$CA_CERT" ]; then
  echo "[idm1] ERROR: no se encontro el certificado de la CA tras 30s."
  exit 1
fi

/usr/local/bin/init-ldap.sh
/usr/local/bin/init-kerberos.sh

echo "[idm1] Inicializacion completa. Lanzando supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf