# Proyecto Segundo Bimestre - MiniIDM - Jesua Villacis

## Arquitectura del sistema

La infraestructura corre sobre una unica red bridge de Docker
(`fis-net`, subred `192.168.25.0/24`) con 12 servicios, cada uno con una
responsabilidad especifica:

| Nodo | IP | Responsabilidad |
|---|---|---|
| `ca1` | 192.168.25.5 | Autoridad Certificadora raiz (ECDSA/prime256v1).|
| `idm1` | 192.168.25.11 | LDAP **master** (OpenLDAP + TLS/LDAPS) y KDC **primario** de Kerberos (MIT). |
| `idm2` | 192.168.25.12 | LDAP **replica** (consumer via `syncrepl`) y KDC **secundario** de Kerberos (recibe la base de datos via `kpropd`). Provee failover de autenticacion y de directorio si `idm1` cae. |
| `lb1` | 192.168.25.20 | Balanceador de carga (HAProxy) para LDAPS, con Keepalived en rol **MASTER** por defecto (retiene la VIP `192.168.25.100`). |
| `lb2` | 192.168.25.21 | Balanceador de carga identico a `lb1`, en rol **BACKUP** de Keepalived. |
| `web1` | 192.168.25.30 | Servicio web (Apache) protegido con TLS y autenticacion Kerberos/SPNEGO. Expuesto al host en el puerto `8443`. |
| `client` | 192.168.25.40 | Contenedor de pruebasejecuta los experimentos que requieren estar "dentro" de la red `fis-net`.|
| `cadvisor` | 192.168.25.50 | Recoleccion de metricas de contenedores (CPU/memoria) para Prometheus. Expuesto en `8081`. |
| `prometheus` | 192.168.25.51 | Recoleccion y almacenamiento de metricas (LDAP, Kerberos, contenedores). Expuesto en `9090`. |
| `grafana` | 192.168.25.52 | Visualizacion de metricas via dashboards. Expuesto en `3000`. |
| `ldap-exporter-idm1` | 192.168.25.53 | Exporta metricas de LDAP de `idm1` en formato Prometheus. |
| `ldap-exporter-idm2` | 192.168.25.54 | Exporta metricas de LDAP de `idm2` en formato Prometheus. |

**Balanceo de carga:** el frontend LDAPS (puerto 636) se expone en la VIP
`192.168.25.100`, gestionada por Keepalived. HAProxy
hace balanceo round-robin en modo TCP (passthrough de TLS) entre `idm1` e
`idm2` como backends.

`Cada contenedor contiene una imagen de Ubuntu 24.04`

## Realm de Kerberos

- **Realm:** `FIS.EPN.EC`
- **KDC primario:** `idm1.fis.epn.ec`
- **KDC secundario:** `idm2.fis.epn.ec` 
- **Admin server:** `idm1.fis.epn.ec`
- Ambos KDCs estan listados en `[realms]` de `krb5.conf` en todos los nodos
  cliente, lo que permite el failover automatico.

**Principals de usuario configurados:** `jperez`, `malvan`, `dnoboa`

**Principals de servicio:** `host/idm1.fis.epn.ec`, `host/idm2.fis.epn.ec`
(usados para la autenticacion mutua de la propagacion `kprop`/`kpropd`), y
`HTTP/web1.fis.epn.ec` (usado para la autenticacion SPNEGO del servicio web).

## Directorio LDAP (DIT)

- **Base DN:** `dc=fis,dc=epn,dc=ec`
- Replicacion **master-replica** (`idm1` → `idm2`) via el overlay `syncprov`,
  con sincronizacion automatica de todo el arbol (sin intervencion manual en
  el consumer).

## Estructura del repositorio

```
.
├── ca/                      # Autoridad Certificadora raiz (ECDSA)
│   └── scripts/             # init-ca.sh, sign-cert.sh (autofirma idm1/idm2/web1)
├── idm1/                    # LDAP master + KDC primario
│   ├── config/              # krb5.conf, kdc.conf, supervisord.conf, kpropd.acl
│   └── scripts/             # init-ldap.sh, init-kerberos.sh, entrypoint.sh,
│                             # propagate-kerberos.sh, kerberos_exporter.py
├── idm2/                    # LDAP replica + KDC secundario
│   ├── config/
│   └── scripts/             # init-ldap-replica.sh, init-kerberos-replica.sh
├── lb1/ , lb2/               # HAProxy + Keepalived (balanceo LDAPS + VIP)
│   ├── config/               # haproxy.cfg, keepalived.conf
│   └── scripts/               # entrypoint.sh
├── web1/                    # Servicio web con TLS + Kerberos/SPNEGO
│   ├── app/
│   ├── config/
│   └── scripts/
├── client/                  # Contenedor de pruebas (krb5-user, ldap-utils, etc.)
│   └── config/               # krb5.conf
├── ldap-exporter/           # Exporter de metricas LDAP para Prometheus
├── monitoring/
│   ├── prometheus/          # prometheus.yml
│   └── grafana/             # provisioning/
├── experimentos/
│   ├── scripts/             # Los 6 scripts de experimentos + orquestador.sh
│   └── resultados/
│       ├── logs/            # Evidencia de cada corrida individual
│       └── resumenes/       # Resumenes consolidados del orquestador
├── docker-compose.yml
├── .env.example             # Plantilla de variables de entorno (ver nota arriba)
├── .gitattributes           # Fuerza LF en todos los archivos de texto
├── .gitignore
├── Makefile
└── README.md
```

## Uso del makefile

```bash
make setup    # crea .env a partir de .env.example (si no existe)
make build    # construye todas las imagenes
make up       # levanta todos los servicios
make ps       # verifica el estado de los contenedores
```

Ver `make help` para el listado completo de targets, incluyendo
verificaciones rapidas (`make verify-ldap`, `make verify-ha`) y los targets
de experimentos individuales.

## Resultados de las pruebas de Alta Disponibilidad

Resultados de la corrida mas reciente del orquestador de experimentos
(`experimentos/resultados/resumenes/resumen-orquestador-20260717-045052.txt`),
que ejecuta cada experimento N veces y reporta el promedio:

| Experimento | Corridas | Exito | Promedio |
|---|---|---|---|
| Replicacion LDAP (retardo de propagacion idm1 → idm2) | 5 | 5/5 | 0.0597 s |
| Overhead de TLS (LDAP plano vs LDAPS) | 5 | 5/5 | 0.00155 s |
| Throughput del balanceador (VIP, 50 requests/corrida) | 5 | 5/5 | 214.95 req/s |
| Failover de KDC (idm1 caido → kinit exitoso via idm2) | 3 | 3/3 | 0.4033 s |
| Recuperacion de nodo (kill -9 a slapd en idm1) | 3 | 3/3 | 2.0795 s |
| Particion de red (iptables DROP total en idm1) | 1 | 1/1 | 3.3249 s |



