#!/bin/bash
set -euo pipefail

MARKER=/var/lib/krb5kdc/.initialized
STASH_FILE=/etc/krb5kdc/stash

echo "[idm1] Inicializando KDC para el realm FIS.EPN.EC..."

export KRB5_ADMIN_PASSWORD="${KRB5_ADMIN_PASSWORD:-changeme_admin}"
export KRB5_USER_DEFAULT_PASSWORD="${KRB5_USER_DEFAULT_PASSWORD:-changeme_user}"

CONFIG_DIR=/etc/idm1-config

cp "${CONFIG_DIR}/kadm5.acl" /etc/krb5kdc/kadm5.acl

if [ -f "$MARKER" ]; then
  if [ ! -f "$STASH_FILE" ]; then
    echo "[idm1] Base de datos existente pero stash file ausente, regenerando..."
    kdb5_util stash -P "${KRB5_ADMIN_PASSWORD}"
    echo "[idm1] Stash file regenerado."
  else
    echo "[idm1] Kerberos ya inicializado y stash presente, omitiendo."
  fi
else
  kdb5_util create -s -r FIS.EPN.EC -P "${KRB5_ADMIN_PASSWORD}"

  echo "[idm1] Creando principal administrativo..."
  kadmin.local -q "addprinc -pw ${KRB5_ADMIN_PASSWORD} admin/admin"

  echo "[idm1] Creando principals de usuarios..."
  while IFS= read -r username; do
    [ -z "$username" ] && continue
    kadmin.local -q "addprinc -pw ${KRB5_USER_DEFAULT_PASSWORD} ${username}"
    echo "[idm1]   -> principal creado: ${username}@FIS.EPN.EC"
  done < "${CONFIG_DIR}/users.txt"

  echo "[idm1] Creando principal de servicio para LDAP..."
  kadmin.local -q "addprinc -randkey ldap/idm1.fis.epn.ec"
  kadmin.local -q "ktadd -k /etc/krb5kdc/ldap.keytab ldap/idm1.fis.epn.ec"
  chown openldap:openldap /etc/krb5kdc/ldap.keytab 2>/dev/null || true
  chmod 640 /etc/krb5kdc/ldap.keytab

  touch "$MARKER"
  echo "[idm1] Kerberos inicializado correctamente."
fi