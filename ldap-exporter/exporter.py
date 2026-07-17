import os
import time
import logging
from ldap3 import Server, Connection, NONE, SIMPLE
from ldap3.core.exceptions import LDAPException
from prometheus_client import start_http_server, Gauge

logging.basicConfig(level=logging.INFO, format="[ldap-exporter] %(message)s")
log = logging.getLogger(__name__)

LDAP_HOST = os.environ.get("LDAP_HOST", "idm1")
LDAP_PORT = int(os.environ.get("LDAP_PORT", "389"))
LDAP_BIND_DN = os.environ.get("LDAP_BIND_DN", "cn=admin,dc=fis,dc=epn,dc=ec")
LDAP_BIND_PASSWORD = os.environ.get("LDAP_BIND_PASSWORD", "")
SCRAPE_INTERVAL = int(os.environ.get("SCRAPE_INTERVAL", "10"))
METRICS_PORT = int(os.environ.get("METRICS_PORT", "9330"))

ldap_up = Gauge("ldap_up", "Whether the LDAP server responded to the last scrape (1) or not (0)", ["instance"])
ldap_current_connections = Gauge("ldap_current_connections", "Current open connections", ["instance"])
ldap_operations_completed_total = Gauge("ldap_operations_completed_total", "Completed operations by type", ["instance", "op"])

OPERATIONS_RDN = {
    "Bind": "cn=Bind,cn=Operations,cn=Monitor",
    "Search": "cn=Search,cn=Operations,cn=Monitor",
    "Add": "cn=Add,cn=Operations,cn=Monitor",
    "Delete": "cn=Delete,cn=Operations,cn=Monitor",
    "Modify": "cn=Modify,cn=Operations,cn=Monitor",
}

def scrape():
    instance = LDAP_HOST
    try:
        server = Server(LDAP_HOST, port=LDAP_PORT, get_info=NONE)
        conn = Connection(
            server,
            user=LDAP_BIND_DN,
            password=LDAP_BIND_PASSWORD,
            authentication=SIMPLE,
            check_names=False,
            auto_bind=True,
        )

        conn.search(
            "cn=Current,cn=Connections,cn=Monitor",
            "(objectclass=*)",
            attributes=["monitorCounter"],
        )
        if conn.entries:
            ldap_current_connections.labels(instance=instance).set(
                int(conn.entries[0].monitorCounter.value)
            )

        for op_name, dn in OPERATIONS_RDN.items():
            conn.search(dn, "(objectclass=*)", attributes=["monitorOpCompleted"])
            if conn.entries:
                ldap_operations_completed_total.labels(instance=instance, op=op_name).set(
                    int(conn.entries[0].monitorOpCompleted.value)
                )

        conn.unbind()
        ldap_up.labels(instance=instance).set(1)
        log.info(f"scrape OK ({instance})")

    except LDAPException as e:
        ldap_up.labels(instance=instance).set(0)
        log.warning(f"scrape FAILED ({instance}): {e}")

if __name__ == "__main__":
    start_http_server(METRICS_PORT)
    log.info(f"exporter listening on :{METRICS_PORT}, target={LDAP_HOST}:{LDAP_PORT}, interval={SCRAPE_INTERVAL}s")
    while True:
        scrape()
        time.sleep(SCRAPE_INTERVAL)