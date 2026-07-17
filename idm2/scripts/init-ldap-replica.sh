#!/bin/bash
set -euo pipefail

MARKER=/var/lib/ldap/.initialized

echo "[idm2] Configurando OpenLDAP (replica)..."

export LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-changeme}"
export LDAP_BASE_DN="${LDAP_BASE_DN:-dc=fis,dc=epn,dc=ec}"
export HASHED_PW
HASHED_PW=$(slappasswd -s "${LDAP_ADMIN_PASSWORD}")

CONFIG_DIR=/etc/idm2-config

# Arranca LDAP
slapd -h "ldapi:///" -u openldap -g openldap
sleep 3

envsubst < "${CONFIG_DIR}/01-base-config.ldif.template" > /tmp/01-base-config.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/01-base-config.ldif

if [ -f /etc/fis-ca/issued/idm2/idm2.cert.pem ]; then
  mkdir -p /etc/ldap/certs
  cp /etc/fis-ca/issued/idm2/idm2.cert.pem /etc/ldap/certs/idm2.cert.pem
  cp /etc/fis-ca/issued/idm2/idm2.key.pem /etc/ldap/certs/idm2.key.pem
  cp /etc/fis-ca/certs/ca.cert.pem /etc/ldap/certs/ca.cert.pem
  chown openldap:openldap /etc/ldap/certs/idm2.cert.pem /etc/ldap/certs/idm2.key.pem /etc/ldap/certs/ca.cert.pem
  chmod 600 /etc/ldap/certs/idm2.key.pem
  chmod 644 /etc/ldap/certs/idm2.cert.pem /etc/ldap/certs/ca.cert.pem

  ldapmodify -Y EXTERNAL -H ldapi:/// -f "${CONFIG_DIR}/02-tls-config.ldif"
  echo "[idm2] TLS configurado."
else
  echo "[idm2] ADVERTENCIA: certificado TLS no encontrado."
fi

envsubst < "${CONFIG_DIR}/03-syncrepl-consumer.ldif.template" > /tmp/03-syncrepl.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/03-syncrepl.ldif || \
  echo "[idm2] syncrepl ya configurado, continuando."
echo "[idm2] syncrepl consumer verificado."

if [ ! -f "$MARKER" ]; then
  touch "$MARKER"
  echo "[idm2] Marcado como inicializado (el arbol llega via syncrepl, no via ldapadd local)."
fi

ldapadd -Y EXTERNAL -H ldapi:/// -f "${CONFIG_DIR}/06-monitor-config.ldif" 2>&1 | grep -v "already exists" || true

pkill slapd