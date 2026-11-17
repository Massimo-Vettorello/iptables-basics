# Laboratorio iptables (demo per studenti)

Basato sui temi di *Iptables Essentials* (DigitalOcean): liste/flush, policy di default,
loopback, connessioni established, SSH/HTTP/MySQL, ping, blocco IP, REJECT vs DROP, LOG, salvataggio.

## Topologia

| Container   | IP            | Ruolo                                              |
|-------------|---------------|----------------------------------------------------|
| fw-server   | 172.28.0.10   | Server col firewall: SSH 22, HTTP 80, "MySQL" 3306, "Postgres" 5432 |
| fw-client1  | 172.28.0.21   | Client/attaccante 1 (nmap, nc, curl, ssh, hping3)  |
| fw-client2  | 172.28.0.22   | Client 2 (per demo "solo questo IP")               |

Rete bridge isolata `172.28.0.0/24`. Le regole iptables vivono solo nel container server
(network namespace proprio): **non toccano il tuo host**.

## Avvio

```bash
docker compose up -d --build
# Terminale A (server)
docker exec -it fw-server bash
# Terminale B (client1)
docker exec -it fw-client1 bash
# Terminale C (client2, opzionale)
docker exec -it fw-client2 bash
```

Comandi utili: sul server `lab-show` (regole con contatori) e `lab-reset` (torna a tutto aperto);
sul client `check` (tabella OPEN / REFUSED / TIMEOUT).

Spegnere tutto: `docker compose down`.

## Scaletta della demo

**0. Stato iniziale** – (client1) `check` → tutto OPEN. (server) `iptables -L -n -v`, `iptables -S`.

**1. Policy DROP senza regole = lockout** – *Messaggio chiave: l'ordine conta.*
```bash
iptables -P INPUT DROP          # server
check                           # client1: tutto in TIMEOUT
```
`lab-reset` per recuperare. (In una VM reale, via SSH, si perderebbe l'accesso!)

**2. Regole base sicure**
```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -P INPUT DROP
```
`check` → solo SSH OPEN. Mostrare `iptables -L -n -v` e i contatori che salgono.
Spiegare perché serve ESTABLISHED (senza, le risposte non rientrano).

**3. Aprire HTTP**
```bash
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```
Client: `curl http://172.28.0.10`

**4. MySQL solo da un IP (client1 sì, client2 no)**
```bash
iptables -A INPUT -p tcp -s 172.28.0.21 --dport 3306 -j ACCEPT
```
client1: `nc -v 172.28.0.10 3306` → banner; client2: stesso comando → timeout.
Variante: interi sottoreti con `-s 172.28.0.0/24`.

**5. Ping (ICMP)**
```bash
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
```
Prima: `ping` fallisce; dopo: funziona. Poi eliminarla con `iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT`.

**6. DROP vs REJECT**
```bash
iptables -A INPUT -p tcp --dport 5432 -j REJECT --reject-with tcp-reset
```
`check` → 5432 "REFUSED" (risposta immediata) mentre le altre porte chiuse vanno in "TIMEOUT".
Discussione: con DROP l'attaccante non sa se il server esiste; con REJECT sì ma il client non resta ad aspettare.

**7. Bloccare un IP**
```bash
iptables -I INPUT 1 -s 172.28.0.22 -j DROP   # -I = inserisci in cima
```
Da client2 non passa più niente, nemmeno HTTP. Mostrare perché `-I` e non `-A`
(l'ordine di valutazione: prima regola che combacia vince).

**8. Logging**
```bash
iptables -I INPUT 1 -p tcp --dport 3306 -m limit --limit 5/min -j LOG --log-prefix "MYSQL-TRY: "
```
Lo scan lanciato da client: `nmap -Pn 172.28.0.10`.
> Nota: il log del kernel è condiviso con l'host. Si legge con `sudo dmesg -w | grep MYSQL-TRY`
> **sull'host** (Linux). Su Docker Desktop (Mac/Windows) può non essere visibile: usare
> `tcpdump -ni eth0` nel server come alternativa.

**9. Salvare e ripristinare**
```bash
iptables-save > /root/rules.v4
lab-reset
iptables-restore < /root/rules.v4
```
Spiegare che nei sistemi reali serve `iptables-persistent` / `netfilter-persistent`.

**10. Rimozione regole**
`iptables -L --line-numbers`, poi `iptables -D INPUT 3`; `iptables -F` per svuotare.

## Esercizi per gli studenti

1. Consenti solo SSH da `172.28.0.21`, tutto il resto in DROP.
2. Consenti HTTP ma limita a 10 nuove connessioni/minuto (`-m limit` o `-m hashlimit`).
3. Blocca la porta 5432 con REJECT e la 3306 con DROP; confronta i tempi con `check`.
4. Scrivi uno script che applica un set completo di regole e verifica con `check`.

## Note di sicurezza e troubleshooting

- Il server ha `root` / `student` per SSH: **solo per il laboratorio**, rete isolata, nessuna porta pubblicata sull'host.
- Se `iptables` dà errori di backend, nel server: `update-alternatives --set iptables /usr/sbin/iptables-legacy`.
- Ricorda di aprire il traffico *prima* di mettere la policy DROP; in caso di errore: `lab-reset`.
