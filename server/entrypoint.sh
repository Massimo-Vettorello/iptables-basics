#!/bin/bash
# Avvia i servizi "bersaglio" da proteggere con iptables.
service nginx start                      # HTTP  80
/usr/sbin/sshd                           # SSH   22
# Finti servizi: rispondono con un banner così si vede quando la porta è raggiunta
(while true; do echo "fake-mysql" | nc -l -p 3306 -q0 >/dev/null 2>&1; done) &   # MySQL 3306
(while true; do echo "fake-postgres" | nc -l -p 5432 -q0 >/dev/null 2>&1; done) & # PostgreSQL 5432
echo "Server pronto. IP: $(hostname -i)"
exec sleep infinity
