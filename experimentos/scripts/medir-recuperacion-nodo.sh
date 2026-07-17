#!/bin/bash
# =============================================================================
# Mide el tiempo de recuperacion de un nodo tras un crash forzado (kill -9).
# =============================================================================
set -uo pipefail

SERVICIO="${1:-idm1}"
PROCESO="${2:-slapd}"
OUT_FILE="experimentos/resultados/logs/recuperacion-nodo-${SERVICIO}-${PROCESO}-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p experimentos/resultados/logs

echo "[experimento] Tiempo de recuperacion: kill -9 a '${PROCESO}' en '${SERVICIO}'" | tee "$OUT_FILE"

docker exec "$SERVICIO" bash -c "kill -9 \$(pgrep ${PROCESO})"
T_INICIO=$(date +%s.%N)
echo "[experimento] T0 (kill -9 enviado): $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$OUT_FILE"

MAX_INTENTOS=60
INTENTO=0
RECUPERADO=0

while [ $INTENTO -lt $MAX_INTENTOS ]; do
  ESTADO=$(docker exec "$SERVICIO" supervisorctl status "$PROCESO" 2>/dev/null | grep -o "RUNNING")
  if [ "$ESTADO" == "RUNNING" ]; then
    RECUPERADO=1
    break
  fi
  sleep 0.5
  INTENTO=$((INTENTO+1))
done

T_FIN=$(date +%s.%N)
echo "[experimento] T1 (proceso RUNNING de nuevo): $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$OUT_FILE"

if [ $RECUPERADO -eq 1 ]; then
  TIEMPO=$(awk "BEGIN{print $T_FIN - $T_INICIO}")
  echo "[experimento] RESULTADO: recuperacion en ${TIEMPO} segundos." | tee -a "$OUT_FILE"
else
  echo "[experimento] RESULTADO: FALLO -- el proceso no volvio a RUNNING tras 30s." | tee -a "$OUT_FILE"
  exit 1
fi

echo "[experimento] Evidencia guardada en: ${OUT_FILE}"