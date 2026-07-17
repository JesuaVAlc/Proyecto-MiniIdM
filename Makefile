# =============================================================================
# Makefile 
# =============================================================================

.PHONY: help setup build up down restart ps logs clean \
        test-replicacion test-tls test-throughput test-failover \
        test-recuperacion test-particion test-all \
        kinit-demo verify-ldap verify-tls verify-ha

# -----------------------------------------------------------------------------
# Ayuda
# -----------------------------------------------------------------------------
help:
	@echo "Targets disponibles:"
	@echo "  make setup            - Copia .env.example a .env (solo si no existe)"
	@echo "  make build            - Construye todas las imagenes (docker compose build)"
	@echo "  make up               - Levanta todos los servicios en segundo plano"
	@echo "  make down             - Detiene y elimina todos los contenedores"
	@echo "  make restart          - down + up"
	@echo "  make ps               - Muestra el estado de todos los contenedores"
	@echo "  make logs             - Sigue los logs de todos los servicios"
	@echo "  make clean            - down + elimina volumenes (BORRA todos los datos persistentes)"
	@echo ""
	@echo "  make verify-ldap      - Verifica LDAP+TLS en idm1 e idm2 (openssl s_client)"
	@echo "  make verify-tls       - Verifica certificados emitidos por la CA"
	@echo "  make verify-ha        - Muestra estado de Keepalived/VIP en lb1 y lb2"
	@echo "  make kinit-demo       - Prueba kinit contra idm1 con el usuario jperez"
	@echo ""
	@echo "  make test-replicacion - Corre el experimento de replicacion LDAP"
	@echo "  make test-tls         - Corre el experimento de overhead de TLS"
	@echo "  make test-throughput  - Corre el experimento de throughput del balanceador"
	@echo "  make test-failover    - Corre el experimento de failover de KDC"
	@echo "  make test-recuperacion - Corre el experimento de recuperacion de nodo (idm1/slapd)"
	@echo "  make test-particion   - Corre el experimento de particion de red"
	@echo "  make test-all         - Corre el orquestador completo (todos los experimentos)"

# -----------------------------------------------------------------------------
# Infraestructura
# -----------------------------------------------------------------------------
setup:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "[setup] .env creado a partir de .env.example. Revisa/edita las credenciales antes de continuar."; \
	else \
		echo "[setup] .env ya existe, no se sobreescribe."; \
	fi

build: setup
	docker compose build

up: setup
	docker compose up -d
	@echo "[up] Servicios levantados. Espera ~30-60s a que idm1/idm2 terminen su inicializacion antes de correr experimentos."
	@echo "[up] Verifica con: make ps"

down:
	docker compose down

restart: down up

ps:
	docker compose ps

logs:
	docker compose logs -f

clean:
	docker compose down -v
	@echo "[clean] Contenedores y VOLUMENES eliminados. Los datos de LDAP/Kerberos se perdieron."

# -----------------------------------------------------------------------------
# Verificaciones rapidas (para que el profesor confirme cada componente
# de la rubrica sin tener que leer los scripts)
# -----------------------------------------------------------------------------
verify-ldap:
	@echo "=== Verificando LDAPS en idm1 ==="
	docker exec idm1 bash -c "echo | openssl s_client -connect idm1.fis.epn.ec:636 -CAfile /etc/fis-ca/certs/ca.cert.pem 2>/dev/null | grep 'Verify return code'"
	@echo "=== Verificando LDAPS en idm2 ==="
	docker exec idm2 bash -c "echo | openssl s_client -connect idm2.fis.epn.ec:636 -CAfile /etc/fis-ca/certs/ca.cert.pem 2>/dev/null | grep 'Verify return code'"

verify-tls:
	@echo "=== Certificados emitidos por la CA ==="
	docker exec ca1 bash -c "ls /etc/fis-ca/certs/"

verify-ha:
	@echo "=== Estado de Keepalived/VIP en lb1 ==="
	docker exec lb1 ip addr show eth0 | grep "inet "
	@echo "=== Estado de Keepalived/VIP en lb2 ==="
	docker exec lb2 ip addr show eth0 | grep "inet "

kinit-demo:
	docker exec -it idm1 kinit jperez
	docker exec -it idm1 klist

# -----------------------------------------------------------------------------
# Experimentos individuales
# -----------------------------------------------------------------------------
test-replicacion:
	docker exec client bash //experimentos/medir-replicacion-ldap.sh

test-tls:
	docker exec client bash //experimentos/medir-overhead-tls.sh

test-throughput:
	docker exec client bash //experimentos/medir-throughput-balanceo.sh 50

test-failover:
	bash experimentos/scripts/medir-failover-kdc.sh

test-recuperacion:
	bash experimentos/scripts/medir-recuperacion-nodo.sh idm1 slapd

test-particion:
	bash experimentos/scripts/medir-particion-red.sh

test-all:
	bash experimentos/scripts/orquestador.sh