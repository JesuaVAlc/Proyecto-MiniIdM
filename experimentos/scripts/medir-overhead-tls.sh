#!/bin/bash
# =============================================================================
# Compara latencia de una query LDAP identica sobre LDAP plano vs
# LDAPS, para medir el overhead que agrega TLS.
# =============================================================================
set -uo pipefail

export LDAPTLS_CACERT=/etc/fis-ca/certs/ca.cert.pem

BASE_DN="${LDAP_BASE_DN}"
ADMIN_PASS="${LDAP_ADMIN_PASSWORD}"
OUT_FILE="/experimentos-resultados/overhead-tls-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p /experimentos-resultados

echo "[experimento] Overhead de TLS: LDAP plano vs LDAPS" | tee "$OUT_FILE"

T0=$(date +%s.%N)
ldapsearch -x -H ldap://idm1.fis.epn.ec -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -b "${BASE_DN}" -s sub "(objectclass=person)" dn >/dev/null 2>&1
T1=$(date +%s.%N)
PLANO=$(awk "BEGIN{print $T1 - $T0}")
echo "[experimento] Query LDAP plano (389): ${PLANO} segundos" | tee -a "$OUT_FILE"

T0=$(date +%s.%N)
ldapsearch -x -H ldaps://idm1.fis.epn.ec -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -b "${BASE_DN}" -s sub "(objectclass=person)" dn >/dev/null 2>&1
T1=$(date +%s.%N)
TLS=$(awk "BEGIN{print $T1 - $T0}")
echo "[experimento] Query LDAPS (636): ${TLS} segundos" | tee -a "$OUT_FILE"

OVERHEAD=$(awk "BEGIN{print $TLS - $PLANO}")
echo "[experimento] RESULTADO: overhead de TLS = ${OVERHEAD} segundos." | tee -a "$OUT_FILE"

echo "[experimento] Evidencia guardada en: ${OUT_FILE}"