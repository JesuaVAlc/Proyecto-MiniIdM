#!/bin/bash
set -euo pipefail

echo "[web1] Iniciando entrypoint..."

CA_CERT=/etc/fis-ca/certs/ca.cert.pem
COUNTER=0
until [ -f "$CA_CERT" ] || [ $COUNTER -ge 30 ]; do
  echo "[web1] Esperando certificado de la CA... ($COUNTER/30)"
  sleep 1
  COUNTER=$((COUNTER+1))
done

if [ ! -f "$CA_CERT" ]; then
  echo "[web1] ERROR: no se encontro el certificado de la CA tras 30s."
  exit 1
fi
KEYTAB_SRC=/etc/krb5kdc/keytabs-in/web1-http.keytab
COUNTER=0
until [ -f "$KEYTAB_SRC" ] || [ $COUNTER -ge 30 ]; do
  echo "[web1] Esperando keytab HTTP publicado por idm1... ($COUNTER/30)"
  sleep 2
  COUNTER=$((COUNTER+2))
done

/usr/local/bin/init-web.sh

echo "[web1] Inicializacion completa. Lanzando Apache..."
exec apache2ctl -D FOREGROUND