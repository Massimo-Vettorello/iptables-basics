# iptables demo

Based on the topics of *Iptables Essentials* [(DigitalOcean)](https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands#iptables-vs-ufw): listing/flushing rules, default policies,
loopback, established connections, SSH/HTTP/MySQL, ping, blocking IPs, REJECT vs DROP, logging, saving rules.

## Topology

| Container   | IP            | Role                                                |
|-------------|---------------|-----------------------------------------------------|
| fw-server   | 172.28.0.10   | Server with the firewall: SSH 22, HTTP 80, "MySQL" 3306, "Postgres" 5432 |
| fw-client1  | 172.28.0.21   | Client/attacker 1 (nmap, nc, curl, ssh, hping3)     |
| fw-client2  | 172.28.0.22   | Client 2 (for the "this IP only" demos)             |

Isolated bridge network `172.28.0.0/24`. The iptables rules live only inside the server container
(its own network namespace): **they do not touch your host**.

## Getting started

```bash
docker compose up -d --build
# Terminal A (server)
docker exec -it fw-server bash
# Terminal B (client1)
docker exec -it fw-client1 bash
# Terminal C (client2, optional)
docker exec -it fw-client2 bash
```

Handy commands: on the server `lab-show` (rules with counters), `lab-log` (live NFLOG output) and `lab-reset` (back to everything open);
on the client `check` (OPEN / REFUSED / TIMEOUT table).

Shut everything down: `docker compose down`.

## Demo outline

**0. Initial state** – (client1) `check` → everything OPEN. (server) `iptables -L -n -v`, `iptables -S`.

**1. DROP policy with no rules = lockout** – *Key message: order matters.*
```bash
iptables -P INPUT DROP          # server
check                           # client1: everything TIMEOUT
```
Run `lab-reset` to recover. (On a real VM, over SSH, you would lose access!)

**2. Safe baseline rules**
```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -P INPUT DROP
```
`check` → only SSH OPEN. 

`iptables -L -n -v` will show how byte counter and packet counter grows with increasing request from the clients.


**3. Open HTTP**
```bash
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```
Client: `curl http://172.28.0.10` → check before and after setting up the command.

**4. MySQL from a single IP (client1 yes, client2 no)**
```bash
iptables -A INPUT -p tcp -s 172.28.0.21 --dport 3306 -j ACCEPT
```
client1: `nc -v 172.28.0.10 3306` → banner; client2: same command → timeout.
Variant: whole subnets with `-s 172.28.0.0/24`.

**5. Ping (ICMP)**
```bash
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
```
Before: `ping` fails; after: it works. Then remove it with `iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT`.

**6. DROP vs REJECT**
```bash
iptables -A INPUT -p tcp --dport 5432 -j REJECT --reject-with tcp-reset
```
`check` → 5432 "REFUSED" (immediate reply) while the other closed ports show "TIMEOUT".
With DROP the attacker cannot tell whether the host exists; with REJECT they can, but the client doesn't hang waiting.

**7. Block an IP**
```bash
iptables -I INPUT 1 -s 172.28.0.22 -j DROP   # -I = insert at the top
```
From client2 nothing gets through anymore, not even HTTP.

**8. Logging (with NFLOG + tcpdump)**
> Why not `-j LOG`? Inside a container the kernel does not write LOG entries to its log
> (and on Docker Desktop the host is a VM). `NFLOG` works everywhere instead: the packet is
> sent to a "group" that you read with `tcpdump`.

Terminal A (server): insert the rule **at the top** (otherwise earlier ACCEPT/DROP rules bypass it) and start listening
```bash
iptables -I INPUT 1 -p tcp --dport 3306 -j NFLOG --nflog-group 1 --nflog-prefix "MYSQL-TRY: "
lab-log 1                       # = tcpdump -l -nn -i nflog:1
```
Terminal B (client1): run the scan
```bash
nmap -Pn -p 22,80,3306,5432 172.28.0.10
```
Terminal A shows the SYN packets to port 3306. Cross-check without logs: `iptables -L INPUT -n -v`
→ the `pkts` counter of the NFLOG rule goes up with every scan.
To tell several rules apart, use different groups (`--nflog-group 1`, `2`...) and `lab-log 2`.

*Alternative with classic `LOG`:* Linux hosts only, with
`sudo sysctl -w net.netfilter.nf_log_all_netns=1` and then `sudo dmesg -w | grep MYSQL-TRY` on the host.

**9. Save and restore**
```bash
iptables-save > /root/rules.v4
lab-reset
iptables-restore < /root/rules.v4
```
Explain that real systems need `iptables-persistent` / `netfilter-persistent`.

**10. Removing rules**
`iptables -L --line-numbers`, then `iptables -D INPUT 3`; `iptables -F` to flush everything.

## Student exercises

1. Allow SSH only from `172.28.0.21`, DROP everything else.
2. Allow HTTP but limit it to 10 new connections per minute (`-m limit` or `-m hashlimit`).
3. Block port 5432 with REJECT and port 3306 with DROP; compare the timings with `check`.
4. Write a script that applies a complete rule set and verify it with `check`.

## Security notes and troubleshooting

- The server has `root` / `student` for SSH: **lab use only**, isolated network, no ports published on the host.
- If `iptables` complains about the backend, on the server: `update-alternatives --set iptables /usr/sbin/iptables-legacy`.
- Remember to open the traffic you need *before* setting the DROP policy; if you make a mistake: `lab-reset`.
