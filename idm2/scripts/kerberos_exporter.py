import os
import re
import time
import logging
from prometheus_client import start_http_server, Counter

logging.basicConfig(level=logging.INFO, format="[kerberos-exporter] %(message)s")
log = logging.getLogger(__name__)

KRB5_LOG = os.environ.get("KRB5_LOG", "/var/log/krb5kdc.log")
NODE_NAME = os.environ.get("NODE_NAME", "unknown")
SCAN_INTERVAL = int(os.environ.get("SCAN_INTERVAL", "5"))
METRICS_PORT = int(os.environ.get("METRICS_PORT", "9331"))

kerberos_requests_total = Counter(
    "kerberos_requests_total",
    "Kerberos KDC requests parsed from krb5kdc.log",
    ["node", "req_type", "result"],
)

LINE_RE = re.compile(
    r"\b(AS_REQ|TGS_REQ)\b.*?\s(\d{1,3}(?:\.\d{1,3}){3}):\s+(\w+):"
)

def wait_for_log():
    while not os.path.exists(KRB5_LOG):
        log.info(f"esperando a que exista {KRB5_LOG}...")
        time.sleep(2)

def follow_log():
    wait_for_log()
    with open(KRB5_LOG, "r") as f:
        f.seek(0, os.SEEK_END)  # solo contar eventos nuevos desde que arranca el exporter
        while True:
            line = f.readline()
            if not line:
                time.sleep(SCAN_INTERVAL)
                continue
            match = LINE_RE.search(line)
            if match:
                req_type, _client_ip, result = match.groups()
                kerberos_requests_total.labels(
                    node=NODE_NAME, req_type=req_type, result=result
                ).inc()

if __name__ == "__main__":
    start_http_server(METRICS_PORT)
    log.info(f"exporter listening on :{METRICS_PORT}, tailing {KRB5_LOG}, node={NODE_NAME}")
    follow_log()