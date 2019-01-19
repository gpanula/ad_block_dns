grab_blocklist.sh should be put in /etc/cron.daily
remove-addomains.pl goes in /usr/local/bin (that is were grab_blocklist.sh expects it)

named.conf is just an example named.conf

adserver.zone & malware.zone are sample zone files.

~~~~
How it all works.....

grab_blocklist.sh grabs lists of known bad domains(e.g. zeus c&c)
then compiles them into two lists; malware & adservers
from that it creates zone definitions to be used by named(bind).

Here's an example
zone "001.bbexe.cn" { type master; notify no; check-names ignore; file "masters/malware.zone"; };

Those zone definitions are put in malware_block.txt and adserver_block.txt.

You need to include those in your named.conf.

Once grab_blocklist.sh is done with its blocklist creation it will reload named.

After named(bind) has been reloaded, lookup for those domains will return
what you have defined in the malware.zone & adserver.zone files.

In my case I've configure squid to display specific 'Access Denied' messages
depending on the ip address. e.g. 198.18.1.255 brings up a warning about possible malware site and access being denied.

Other things trying to reach 198.18.1.255 will failed because
1) explictly block at the firewall
2) 198.18.0.0/15 is set aside for network benchmark test and should not be internet routable (rfc2544)

enjoy

