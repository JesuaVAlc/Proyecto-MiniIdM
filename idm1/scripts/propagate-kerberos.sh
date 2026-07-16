#!/bin/bash
set -euo pipefail

echo "[idm1] Generando dump de la base de datos Kerberos..."
kdb5_util dump /etc/krb5kdc/shared/kdc-dump.dump

echo "[idm1] Propagando a idm2 via kprop..."
kprop -f /etc/krb5kdc/shared/kdc-dump.dump -s /etc/krb5kdc/idm1-host.keytab -d idm2.fis.epn.ec

echo "[idm1] Propagacion completada."