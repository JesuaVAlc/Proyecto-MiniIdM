#!/bin/bash

set -uo pipefail

N_REPLICACION_LDAP=5
N_OVERHEAD_TLS=5
N_FAILOVER_KDC=3
N_RECUPERACION_NODO=3
N_PARTICION_RED=1
N_THROUGHPUT=5

RESUMEN_FILE="experimentos/resultados/resumenes/resumen-orquestador-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p experimentos/resultados/resumenes

trap 'echo "[orquestador] Salida detectada -- verificando que idm1 este arriba..."; docker compose start idm1 >/dev/null 2>&1; echo "[orquestador] idm1 restaurado (si estaba detenido)."' EXIT


esperar_idm1_estable() {
  local TIMEOUT_SEGUNDOS=90
  local INTENTO=0
  local MAX_INTENTOS=$((TIMEOUT_SEGUNDOS * 2))  # polling cada 0.5s
  local T_INICIO=$(date +%s.%N)

  echo "[orquestador] Esperando a que idm1 se estabilice (kadmind, kerberos-exporter, krb5kdc, slapd en RUNNING)..."

  while [ $INTENTO -lt $MAX_INTENTOS ]; do
    local ESTADO
    ESTADO=$(docker exec idm1 supervisorctl status 2>/dev/null)
    if echo "$ESTADO" | grep -q "kadmind.*RUNNING" && \
       echo "$ESTADO" | grep -q "kerberos-exporter.*RUNNING" && \
       echo "$ESTADO" | grep -q "krb5kdc.*RUNNING" && \
       echo "$ESTADO" | grep -q "slapd.*RUNNING"; then
      local T_FIN=$(date +%s.%N)
      local TIEMPO=$(awk "BEGIN{print $T_FIN - $T_INICIO}")
      echo "[orquestador] idm1 estabilizado en ${TIEMPO} segundos."
      return 0
    fi
    sleep 0.5
    INTENTO=$((INTENTO+1))
  done

  echo "[orquestador] ADVERTENCIA: idm1 no se estabilizo tras ${TIMEOUT_SEGUNDOS}s. Continuando de todas formas (revisar manualmente)."
  return 1
}

echo "=== Verificacion previa de contenedores ==="
NODOS_ESPERADOS=(ca1 idm1 idm2 lb1 lb2 web1 client)
ALGUNO_CAIDO=0
for NODO in "${NODOS_ESPERADOS[@]}"; do
  ESTADO=$(docker inspect -f '{{.State.Running}}' "$NODO" 2>/dev/null)
  if [ "$ESTADO" != "true" ]; then
    echo "[orquestador] ADVERTENCIA: ${NODO} no esta corriendo."
    ALGUNO_CAIDO=1
  fi
done

if [ $ALGUNO_CAIDO -eq 1 ]; then
  echo "[orquestador] Levantando todos los servicios antes de continuar..."
  docker compose up -d
  sleep 5
fi
esperar_idm1_estable
echo ""

echo "=== Orquestador de experimentos MiniIdM ===" | tee "$RESUMEN_FILE"
echo "Inicio: $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$RESUMEN_FILE"
echo "" | tee -a "$RESUMEN_FILE"


correr_experimento() {
  local NOMBRE="$1"
  local N="$2"
  local PATRON="$3"
  local ESPERAR_IDM1="$4"
  shift 4
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
      else
        echo "[orquestador] ${NOMBRE}: corrida ${i} exit=0 pero el patron no matcheo -- revisar regex" | tee -a "$RESUMEN_FILE"
        echo "--- salida cruda de esa corrida ---" | tee -a "$RESUMEN_FILE"
        echo "$SALIDA" | tee -a "$RESUMEN_FILE"
        echo "--- fin salida cruda ---" | tee -a "$RESUMEN_FILE"
      fi
    else
      echo "[orquestador] ${NOMBRE}: corrida ${i} FALLO (exit ${RC})" | tee -a "$RESUMEN_FILE"
      echo "--- salida cruda del fallo ---" | tee -a "$RESUMEN_FILE"
      echo "$SALIDA" | tee -a "$RESUMEN_FILE"
      echo "--- fin salida cruda ---" | tee -a "$RESUMEN_FILE"
    fi

    if [ "$ESPERAR_IDM1" == "true" ]; then
      esperar_idm1_estable
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
  false \
  docker exec client bash //experimentos/medir-replicacion-ldap.sh

correr_experimento "Overhead TLS" "$N_OVERHEAD_TLS" \
  'overhead de TLS = \K-?[0-9.]+(?= segundos)' \
  false \
  docker exec client bash //experimentos/medir-overhead-tls.sh

correr_experimento "Throughput balanceo" "$N_THROUGHPUT" \
  'throughput = \K[0-9.]+' \
  false \
  docker exec client bash //experimentos/medir-throughput-balanceo.sh 50


correr_experimento "Failover KDC" "$N_FAILOVER_KDC" \
  'exitoso en \K[0-9.]+' \
  true \
  bash experimentos/scripts/medir-failover-kdc.sh

correr_experimento "Recuperacion nodo (idm1/slapd)" "$N_RECUPERACION_NODO" \
  'recuperacion en \K[0-9.]+' \
  true \
  bash experimentos/scripts/medir-recuperacion-nodo.sh idm1 slapd

correr_experimento "Particion de red (idm1)" "$N_PARTICION_RED" \
  'alcanzable de nuevo tras \K[0-9.]+' \
  true \
  bash experimentos/scripts/medir-particion-red.sh

echo "=== Fin del orquestador ===" | tee -a "$RESUMEN_FILE"
echo "Fin: $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$RESUMEN_FILE"
echo "" | tee -a "$RESUMEN_FILE"
echo "Resumen consolidado guardado en: ${RESUMEN_FILE}"