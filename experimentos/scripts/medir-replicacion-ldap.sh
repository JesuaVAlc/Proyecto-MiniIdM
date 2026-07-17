#!/bin/bash
set -uo pipefail

export LDAPTLS_CACERT=/etc/fis-ca/certs/ca.cert.pem

USER_DN="uid=jperez,ou=people,${LDAP_BASE_DN}"
OUT_FILE="/experimentos-resultados/replicacion-ldap-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p /experimentos-resultados

MARCA="sync-test-$(date +%s%N)"

echo "[experimento] Retardo de propagacion LDAP (idm1 -> idm2)" | tee "$OUT_FILE"
echo "[experimento] Marca de prueba: ${MARCA}" | tee -a "$OUT_FILE"

T_INICIO=$(date +%s.%N)
echo "[experimento] T0 (escritura en idm1): $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$OUT_FILE"

ldapmodify -x -H ldaps://idm1.fis.epn.ec -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" <<EOF >/dev/null 2>&1
dn: ${USER_DN}
changetype: modify
replace: description
description: ${MARCA}
EOF

if [ $? -ne 0 ]; then
  echo "[experimento] ERROR: no se pudo escribir en idm1." | tee -a "$OUT_FILE"
  exit 1
fi

echo "[experimento] Escritura confirmada en idm1. Sondeando idm2..." | tee -a "$OUT_FILE"

MAX_INTENTOS=100
INTENTO=0
ENCONTRADO=0

while [ $INTENTO -lt $MAX_INTENTOS ]; do
  RESULTADO=$(ldapsearch -x -H ldaps://idm2.fis.epn.ec -b "${USER_DN}" -s base "description" 2>/dev/null | grep "description: ${MARCA}")
  if [ -n "$RESULTADO" ]; then
    ENCONTRADO=1
    break
  fi
  sleep 0.1
  INTENTO=$((INTENTO+1))
done

T_FIN=$(date +%s.%N)
echo "[experimento] T1 (deteccion en idm2): $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$OUT_FILE"

if [ $ENCONTRADO -eq 1 ]; then
  RETARDO=$(echo "$T_FIN - $T_INICIO" | bc 2>/dev/null || awk "BEGIN{print $T_FIN - $T_INICIO}")
  echo "[experimento] RESULTADO: propagacion exitosa en ${RETARDO} segundos (${INTENTO} sondeos de 0.1s)." | tee -a "$OUT_FILE"
else
  echo "[experimento] RESULTADO: FALLO -- el cambio no se propago tras ${MAX_INTENTOS} intentos (10s)." | tee -a "$OUT_FILE"
  exit 1
fi

echo "[experimento] Evidencia guardada en: ${OUT_FILE}"