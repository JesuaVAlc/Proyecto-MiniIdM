#!/bin/bash
# =============================================================================
# Mide throughput del balanceador HAProxy/Keepalived: N binds LDAPS
# concurrentes/secuenciales contra la VIP, contando exitos por segundo.
# =============================================================================
set -uo pipefail

export LDAPTLS_CACERT=/etc/fis-ca/certs/ca.cert.pem

BASE_DN="${LDAP_BASE_DN}"
ADMIN_PASS="${LDAP_ADMIN_PASSWORD}"
VIP="192.168.25.100"
N_REQUESTS="${1:-50}"
OUT_FILE="/experimentos-resultados/throughput-balanceo-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p /experimentos-resultados

echo "[experimento] Throughput del balanceador (VIP ${VIP}), ${N_REQUESTS} requests" | tee "$OUT_FILE"

EXITOS=0
T_INICIO=$(date +%s.%N)

for i in $(seq 1 "$N_REQUESTS"); do
  ldapsearch -x -H "ldaps://${VIP}" -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -b "${BASE_DN}" -s base "(objectclass=*)" dn >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    EXITOS=$((EXITOS+1))
  fi
done

T_FIN=$(date +%s.%N)
DURACION=$(awk "BEGIN{print $T_FIN - $T_INICIO}")
THROUGHPUT=$(awk "BEGIN{print $EXITOS / $DURACION}")

echo "[experimento] Requests exitosos: ${EXITOS}/${N_REQUESTS}" | tee -a "$OUT_FILE"
echo "[experimento] Duracion total: ${DURACION} segundos" | tee -a "$OUT_FILE"
echo "[experimento] RESULTADO: throughput = ${THROUGHPUT} requests/segundo." | tee -a "$OUT_FILE"

echo "[experimento] Evidencia guardada en: ${OUT_FILE}"