FROM alpine:latest

# apply os updates
RUN apk update && apk upgrade

# install bits for ad blocking dns
RUN apk add bind bash perl dcron && \
    wget -O /etc/periodic/daily/grab_blocklists.sh https://raw.githubusercontent.com/gpanula/ad_block_dns/master/grab_blocklists.sh && \
    wget -O /usr/local/bin/remove-addomains.pl https://raw.githubusercontent.com/gpanula/ad_block_dns/master/remove-addomains.pl && \
    chmod +x /etc/periodic/daily/grab_blocklists.sh && chmod +x /usr/local/bin/remove-addomains.pl

VOLUME ["/var/named/chroot"]

COPY start.sh /start.sh

EXPOSE 53/tcp
EXPOSE 53/udp

ENTRYPOINT ["/start.sh"]
