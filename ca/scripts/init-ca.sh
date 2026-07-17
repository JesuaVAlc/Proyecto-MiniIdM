#!/bin/bash
set -euo pipefail

CA_DIR=/etc/fis-ca

if [ ! -f "${CA_DIR}/certs/ca.cert.pem" ]; then
  echo "[ca1] Generando estructura de la CA raiz..."
  mkdir -p "${CA_DIR}"/{certs,private,newcerts,crl}
  chmod 700 "${CA_DIR}/private"
  touch "${CA_DIR}/index.txt"
  echo 1000 > "${CA_DIR}/serial"

  echo "[ca1] Generando clave privada ECDSA de la CA..."
  openssl ecparam -name prime256v1 -genkey -noout \
    -out "${CA_DIR}/private/ca.key.pem"
  chmod 400 "${CA_DIR}/private/ca.key.pem"

  echo "[ca1] Generando certificado autofirmado de la CA raiz..."
  openssl req -x509 -new -key "${CA_DIR}/private/ca.key.pem" \
    -days 3650 -sha256 \
    -out "${CA_DIR}/certs/ca.cert.pem" \
    -subj "/C=EC/ST=Pichincha/L=Quito/O=FIS-EPN/OU=IdM-Lab/CN=FIS Root CA"

  echo "[ca1] CA raiz lista."
else
  echo "[ca1] CA raiz ya existe, omitiendo generacion."
fi

echo "[ca1] Emitiendo/verificando certificados de los nodos conocidos..."
sign-cert.sh idm1 idm1.fis.epn.ec "DNS:idm1,DNS:idm1.fis.epn.ec,DNS:ldap.fis.epn.ec,IP:192.168.25.100"
sign-cert.sh idm2 idm2.fis.epn.ec "DNS:idm2,DNS:idm2.fis.epn.ec,DNS:ldap.fis.epn.ec,IP:192.168.25.100"
sign-cert.sh web1 web1.fis.epn.ec "DNS:web1,DNS:web1.fis.epn.ec"
echo "[ca1] Certificados de nodos listos."

exec "$@"