#!/bin/sh

# start cron
/usr/sbin/crond

# start named in chroot
/usr/sbin/named -4 -c /etc/named.conf -t /var/named/chroot -f -u named -L /var/named/chroot/var/log/default.log

