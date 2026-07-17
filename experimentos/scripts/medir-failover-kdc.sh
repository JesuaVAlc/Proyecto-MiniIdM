#!/bin/bash
# =============================================================================
# Mide la latencia de failover del KDC: detiene idm1 y mide cuanto tarda
# un kinit en obtener un ticket exitoso via idm2.
# =============================================================================
set -uo pipefail

USER="jperez"
PASS="${KRB5_USER_DEFAULT_PASSWORD:-changeme_user}"
OUT_FILE="experimentos/resultados/logs/failover-kdc-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p experimentos/resultados/logs

echo "[experimento] Latencia de failover del KDC (idm1 -> idm2)" | tee "$OUT_FILE"

docker exec idm1 bash -c "kdestroy -A 2>/dev/null; echo '${PASS}' | kinit ${USER}" >/dev/null 2>&1
echo "[experimento] Ticket inicial contra idm1: OK" | tee -a "$OUT_FILE"

echo "[experimento] Deteniendo idm1..." | tee -a "$OUT_FILE"
docker compose stop idm1 >/dev/null 2>&1

T_INICIO=$(date +%s.%N)
echo "[experimento] T0 (idm1 detenido, iniciando kinit contra idm2): $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$OUT_FILE"

docker exec idm2 bash -c "kdestroy -A 2>/dev/null; echo '${PASS}' | kinit ${USER}" >/dev/null 2>&1
RESULT=$?

T_FIN=$(date +%s.%N)
echo "[experimento] T1 (kinit completado): $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$OUT_FILE"

echo "[experimento] Restaurando idm1..." | tee -a "$OUT_FILE"
docker compose start idm1 >/dev/null 2>&1

if [ $RESULT -eq 0 ]; then
  LATENCIA=$(awk "BEGIN{print $T_FIN - $T_INICIO}")
  echo "[experimento] RESULTADO: failover exitoso en ${LATENCIA} segundos." | tee -a "$OUT_FILE"
else
  echo "[experimento] RESULTADO: FALLO -- kinit contra idm2 no tuvo exito." | tee -a "$OUT_FILE"
  exit 1
fi

echo "[experimento] Evidencia guardada en: ${OUT_FILE}"