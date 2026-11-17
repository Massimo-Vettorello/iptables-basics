FROM debian:bookworm-slim

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      iptables iproute2 iputils-ping netcat-openbsd nginx openssh-server \
      tcpdump procps nano less ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && echo 'root:student' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

COPY entrypoint.sh /entrypoint.sh
COPY lab-reset.sh /usr/local/bin/lab-reset
COPY lab-show.sh  /usr/local/bin/lab-show
RUN chmod +x /entrypoint.sh /usr/local/bin/lab-reset /usr/local/bin/lab-show \
    && echo '<h1>Server web del laboratorio iptables</h1>' > /var/www/html/index.html

ENTRYPOINT ["/entrypoint.sh"]
