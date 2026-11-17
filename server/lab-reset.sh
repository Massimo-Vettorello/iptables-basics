#!/bin/bash
# Riporta il firewall allo stato iniziale: tutto aperto, nessuna regola.
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables -X
echo "Firewall reset (policy ACCEPT, no rule enforced)."
