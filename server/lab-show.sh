#!/bin/bash
# Mostra lo stato attuale delle regole con contatori.
iptables -L -n -v --line-numbers
