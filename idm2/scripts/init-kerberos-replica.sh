#!/bin/bash
set -euo pipefail

MARKER=/var/lib/krb5kdc/.initialized
SHARED=/etc/krb5kdc/shared

echo "[idm2] Inicializando KDC secundario..."

COUNTER=0
until [ -f "${SHARED}/stash" ] && [ -f "${SHARED}/idm2-host.keytab" ] || [ $COUNTER -ge 30 ]; do
  echo "[idm2] Esperando material Kerberos compartido de idm1... ($COUNTER/30)"
  sleep 2
  COUNTER=$((COUNTER+2))
done

if [ ! -f "${SHARED}/stash" ]; then
  echo "[idm2] ERROR: no se encontro el stash compartido tras 30s. Corriste init-kerberos.sh en idm1?"
  exit 1
fi

if [ ! -f "$MARKER" ]; then
  echo "[idm2] Copiando stash y keytab de host desde idm1..."
  cp "${SHARED}/stash" /etc/krb5kdc/stash
  chmod 600 /etc/krb5kdc/stash

  cp "${SHARED}/idm2-host.keytab" /etc/krb5kdc/idm2-host.keytab
  chmod 600 /etc/krb5kdc/idm2-host.keytab

  kdb5_util create -s -r FIS.EPN.EC -P "${KRB5_ADMIN_PASSWORD:-changeme_admin}" || true

  touch "$MARKER"
  echo "[idm2] KDC secundario preparado para recibir propagacion via kpropd."
else
  echo "[idm2] KDC secundario ya inicializado, omitiendo."
fi

echo "[idm2] Recuerda ejecutar propagate-kerberos.sh en idm1 para la primera sincronizacion."