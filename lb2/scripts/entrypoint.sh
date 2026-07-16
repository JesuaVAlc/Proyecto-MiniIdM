#!/bin/bash
set -e

keepalived --dont-fork --log-console &

haproxy -f /etc/haproxy/haproxy.cfg -db