#!/bin/bash
set -euo pipefail

MARKER=/var/lib/ldap/.initialized

echo "[idm1] Configurando OpenLDAP..."

export LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-changeme}"
export LDAP_BASE_DN="${LDAP_BASE_DN:-dc=fis,dc=epn,dc=ec}"
export HASHED_PW
HASHED_PW=$(slappasswd -s "${LDAP_ADMIN_PASSWORD}")

CONFIG_DIR=/etc/idm1-config

# Arranca LDAP 
slapd -h "ldapi:///" -u openldap -g openldap
sleep 3


envsubst < "${CONFIG_DIR}/01-base-config.ldif.template" > /tmp/01-base-config.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/01-base-config.ldif
echo "[idm1] Configuracion base (cn=config) reaplicada."


if [ -f /etc/fis-ca/issued/idm1/idm1.cert.pem ]; then
  mkdir -p /etc/ldap/certs
  cp /etc/fis-ca/issued/idm1/idm1.cert.pem /etc/ldap/certs/idm1.cert.pem
  cp /etc/fis-ca/issued/idm1/idm1.key.pem /etc/ldap/certs/idm1.key.pem
  cp /etc/fis-ca/certs/ca.cert.pem /etc/ldap/certs/ca.cert.pem
  chown openldap:openldap /etc/ldap/certs/idm1.cert.pem /etc/ldap/certs/idm1.key.pem /etc/ldap/certs/ca.cert.pem
  chmod 600 /etc/ldap/certs/idm1.key.pem
  chmod 644 /etc/ldap/certs/idm1.cert.pem /etc/ldap/certs/ca.cert.pem

  ldapmodify -Y EXTERNAL -H ldapi:/// -f "${CONFIG_DIR}/02-tls-config.ldif"
  echo "[idm1] TLS configurado para LDAP."
else
  echo "[idm1] ADVERTENCIA: certificado TLS no encontrado, LDAPS no disponible aun."
fi

if [ ! -f "$MARKER" ]; then
  ldapadd -x -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" \
    -H ldapi:/// -f "${CONFIG_DIR}/03-base-tree.ldif"

  ldapadd -x -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" \
    -H ldapi:/// -f "${CONFIG_DIR}/04-users.ldif"

  touch "$MARKER"
  echo "[idm1] Arbol LDAP inicializado correctamente."
fi

pkill slapd