#!/bin/bash
set -euo pipefail

echo "[web1] Preparando certificados y keytab..."

mkdir -p /etc/apache2/certs /etc/apache2/keytabs

if [ -f /etc/fis-ca/issued/web1/web1.cert.pem ]; then
  cp /etc/fis-ca/issued/web1/web1.cert.pem /etc/apache2/certs/web1.cert.pem
  cp /etc/fis-ca/issued/web1/web1.key.pem /etc/apache2/certs/web1.key.pem
  cp /etc/fis-ca/certs/ca.cert.pem /etc/apache2/certs/ca.cert.pem
  chown www-data:www-data /etc/apache2/certs/*
  chmod 600 /etc/apache2/certs/web1.key.pem
  chmod 644 /etc/apache2/certs/web1.cert.pem /etc/apache2/certs/ca.cert.pem
  echo "[web1] Certificados TLS listos."
else
  echo "[web1] ERROR: certificado de web1 no encontrado en /etc/fis-ca/issued/web1/"
  echo "[web1] Ejecuta: docker exec ca1 sign-cert.sh web1 web1.fis.epn.ec \"DNS:web1,DNS:web1.fis.epn.ec\""
  exit 1
fi

if [ -f /etc/krb5kdc/keytabs-in/web1-http.keytab ]; then
  cp /etc/krb5kdc/keytabs-in/web1-http.keytab /etc/apache2/keytabs/web1-http.keytab
  chown www-data:www-data /etc/apache2/keytabs/web1-http.keytab
  chmod 600 /etc/apache2/keytabs/web1-http.keytab
  echo "[web1] Keytab de servicio HTTP listo."
else
  echo "[web1] ERROR: keytab HTTP no encontrado en /etc/krb5kdc/keytabs-in/"
  echo "[web1] Verifica que idm1 haya publicado HTTP/web1.fis.epn.ec correctamente."
  exit 1
fi