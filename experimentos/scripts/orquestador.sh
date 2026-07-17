#!/bin/bash

set -uo pipefail

export MSYS_NO_PATHCONV=1

N_REPLICACION_LDAP=1
N_OVERHEAD_TLS=1
N_FAILOVER_KDC=1
N_RECUPERACION_NODO=1
N_PARTICION_RED=1
N_THROUGHPUT=1   # cada corrida ya hace 50 requests internamente

RESUMEN_FILE="experimentos/resultados/resumen-orquestador-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p experimentos/resultados

echo "=== Orquestador de experimentos MiniIdM ===" | tee "$RESUMEN_FILE"
echo "Inicio: $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$RESUMEN_FILE"
echo "" | tee -a "$RESUMEN_FILE"


correr_experimento() {
  local NOMBRE="$1"
  local N="$2"
  local PATRON="$3"
  shift 3
  local COMANDO=("$@")

  echo "--- ${NOMBRE} (${N} corridas) ---" | tee -a "$RESUMEN_FILE"
  local VALORES=()
  local EXITOS=0

  for i in $(seq 1 "$N"); do
    echo "[orquestador] ${NOMBRE}: corrida ${i}/${N}..."
    SALIDA=$("${COMANDO[@]}" 2>&1)
    RC=$?
    if [ $RC -eq 0 ]; then
      VALOR=$(echo "$SALIDA" | grep -oP "$PATRON" | tail -1)
      if [ -n "$VALOR" ]; then
        VALORES+=("$VALOR")
        EXITOS=$((EXITOS+1))
      fi
    else
      echo "[orquestador] ${NOMBRE}: corrida ${i} FALLO (exit ${RC})" | tee -a "$RESUMEN_FILE"
    fi
  done

  if [ ${#VALORES[@]} -gt 0 ]; then
    SUMA=0
    for V in "${VALORES[@]}"; do
      SUMA=$(awk "BEGIN{print $SUMA + $V}")
    done
    PROMEDIO=$(awk "BEGIN{print $SUMA / ${#VALORES[@]}}")
    echo "[resumen] ${NOMBRE}: ${EXITOS}/${N} exitosas, promedio = ${PROMEDIO}" | tee -a "$RESUMEN_FILE"
  else
    echo "[resumen] ${NOMBRE}: 0/${N} exitosas, sin datos para promedio" | tee -a "$RESUMEN_FILE"
  fi
  echo "" | tee -a "$RESUMEN_FILE"
}

correr_experimento "Replicacion LDAP" "$N_REPLICACION_LDAP" \
  'propagacion exitosa en \K[0-9.]+(?= segundos)' \
  MSYS_NO_PATHCONV=1 docker exec client bash /experimentos/medir-replicacion-ldap.sh

correr_experimento "Overhead TLS" "$N_OVERHEAD_TLS" \
  'overhead de TLS = \K-?[0-9.]+(?= segundos)' \
  MSYS_NO_PATHCONV=1 docker exec client bash /experimentos/medir-overhead-tls.sh

correr_experimento "Throughput balanceo" "$N_THROUGHPUT" \
  'throughput = \K[0-9.]+' \
  MSYS_NO_PATHCONV=1 docker exec client bash /experimentos/medir-throughput-balanceo.sh 50

correr_experimento "Failover KDC" "$N_FAILOVER_KDC" \
  'exitoso en \K[0-9.]+' \
  bash experimentos/scripts/medir-failover-kdc.sh

correr_experimento "Recuperacion nodo (idm1/slapd)" "$N_RECUPERACION_NODO" \
  'recuperacion en \K[0-9.]+' \
  bash experimentos/scripts/medir-recuperacion-nodo.sh idm1 slapd

correr_experimento "Particion de red (idm1)" "$N_PARTICION_RED" \
  'alcanzable de nuevo tras \K[0-9.]+' \
  bash experimentos/scripts/medir-particion-red.sh

echo "=== Fin del orquestador ===" | tee -a "$RESUMEN_FILE"
echo "Fin: $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$RESUMEN_FILE"
echo "" | tee -a "$RESUMEN_FILE"
echo "Resumen consolidado guardado en: ${RESUMEN_FILE}"