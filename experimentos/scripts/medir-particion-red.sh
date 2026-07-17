#!/bin/bash
# =============================================================================
# Simula una particion de red total en idm1 (iptables DROP en INPUT/OUTPUT/
# FORWARD, solo loopback permitido) y mide
# si el servicio sigue disponible via idm2 durante la particion (LDAP+Kerberos)
# cuanto tarda idm1 en volver a ser alcanzable tras remover la particion
# =============================================================================
set -uo pipefail

USER="jperez"
PASS="${KRB5_USER_DEFAULT_PASSWORD:-changeme_user}"
BASE_DN="${LDAP_BASE_DN:-dc=fis,dc=epn,dc=ec}"
ADMIN_PASS="${LDAP_ADMIN_PASSWORD:-changeme123}"
OUT_FILE="experimentos/resultados/particion-red-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p experimentos/resultados

echo "[experimento] Particion de red en idm1 (iptables DROP total)" | tee "$OUT_FILE"

echo "[experimento] Aplicando particion de red en idm1..." | tee -a "$OUT_FILE"
docker exec idm1 bash -c "iptables -P INPUT DROP && iptables -P OUTPUT DROP && iptables -P FORWARD DROP && iptables -A INPUT -i lo -j ACCEPT && iptables -A OUTPUT -o lo -j ACCEPT"
T_PARTICION=$(date +%s.%N)
echo "[experimento] T0 (particion aplicada): $(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" | tee -a "$OUT_FILE"

echo "[experimento] Verificando disponibilidad LDAP via idm2 durante la particion..." | tee -a "$OUT_FILE"
docker exec idm2 ldapsearch -x -H ldaps://idm2.fis.epn.ec -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -b "${BASE_DN}" -s base "(objectclass=*)" dn >/dev/null 2>&1
LDAP_OK=$?

echo "[experimento] Verificando autenticacion Kerberos via idm2 durante la particion..." | tee -a "$OUT_FILE"
docker exec idm2 bash -c "kdestroy -A 2>/dev/null; echo '${PASS}' | kinit ${USER}" >/dev/null 2>&1
KRB_OK=$?

if [ $LDAP_OK -eq 0 ]; then
  echo "[experimento] LDAP via idm2 durante particion: DISPONIBLE" | tee -a "$OUT_FILE"
else
  echo "[experimento] LDAP via idm2 durante particion: FALLO" | tee -a "$OUT_FILE"
fi

if [ $KRB_OK -eq 0 ]; then
  echo "[experimento] Kerberos via idm2 durante particion: DISPONIBLE" | tee -a "$OUT_FILE"
else
  echo "[experimento] Kerberos via idm2 durante particion: FALLO" | tee -a "$OUT_FILE"
fi

echo "[experimento] Removiendo particion de red en idm1..." | tee -a "$OUT_FILE"
docker exec idm1 bash -c "iptables -P INPUT ACCEPT && iptables -P OUTPUT ACCEPT && iptables -P FORWARD ACCEPT && iptables -F"

MAX_INTENTOS=60
INTENTO=0
RECUPERADO=0
while [ $INTENTO -lt $MAX_INTENTOS ]; do
  docker exec idm2 ldapsearch -x -H ldaps://idm1.fis.epn.ec -D "cn=admin,${BASE_DN}" -w "${ADMIN_PASS}" -b "${BASE_DN}" -s base "(objectclass=*)" dn >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    RECUPERADO=1
    break
  fi
  sleep 0.5
  INTENTO=$((INTENTO+1))
done
T_RECUPERADO=$(date +%s.%N)

if [ $RECUPERADO -eq 1 ]; then
  TIEMPO=$(awk "BEGIN{print $T_RECUPERADO - $T_PARTICION}")
  echo "[experimento] RESULTADO: idm1 alcanzable de nuevo tras ${TIEMPO} segundos." | tee -a "$OUT_FILE"
else
  echo "[experimento] RESULTADO: FALLO -- idm1 no fue alcanzable tras 30s de remover la particion." | tee -a "$OUT_FILE"
  exit 1
fi

echo "[experimento] Evidencia guardada en: ${OUT_FILE}"