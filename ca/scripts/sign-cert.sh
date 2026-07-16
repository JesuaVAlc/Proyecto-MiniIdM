#!/bin/bash
set -euo pipefail

CA_DIR=/etc/fis-ca
NODE_NAME="$1"
CN="$2"
SAN="${3:-DNS:${NODE_NAME}}"

NODE_DIR="${CA_DIR}/issued/${NODE_NAME}"
mkdir -p "${NODE_DIR}"

if [ -f "${NODE_DIR}/${NODE_NAME}.cert.pem" ]; then
  echo "[ca1] Certificado para ${NODE_NAME} ya existe, omitiendo."
  exit 0
fi

echo "[ca1] Generando clave privada ECDSA para ${NODE_NAME}..."
openssl ecparam -name prime256v1 -genkey -noout \
  -out "${NODE_DIR}/${NODE_NAME}.key.pem"

echo "[ca1] Generando CSR para ${NODE_NAME} (CN=${CN})..."
openssl req -new -key "${NODE_DIR}/${NODE_NAME}.key.pem" \
  -out "${NODE_DIR}/${NODE_NAME}.csr.pem" \
  -subj "/C=EC/ST=Pichincha/L=Quito/O=FIS-EPN/OU=IdM-Lab/CN=${CN}"

echo "[ca1] Firmando certificado para ${NODE_NAME}..."
openssl x509 -req -in "${NODE_DIR}/${NODE_NAME}.csr.pem" \
  -CA "${CA_DIR}/certs/ca.cert.pem" \
  -CAkey "${CA_DIR}/private/ca.key.pem" \
  -CAcreateserial \
  -out "${NODE_DIR}/${NODE_NAME}.cert.pem" \
  -days 365 -sha256 \
  -extfile <(printf "subjectAltName=%s" "${SAN}")

chmod 644 "${NODE_DIR}/${NODE_NAME}.cert.pem"
chmod 600 "${NODE_DIR}/${NODE_NAME}.key.pem"

echo "[ca1] Certificado emitido: ${NODE_DIR}/${NODE_NAME}.cert.pem"
openssl x509 -in "${NODE_DIR}/${NODE_NAME}.cert.pem" -noout -subject -issuer -dates