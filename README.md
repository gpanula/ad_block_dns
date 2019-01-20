# ad_block_dns

ad and malware blocking dns

## quick setup

grab_blocklist.sh should be put in /etc/cron.daily
remove-addomains.pl goes in /usr/local/bin (that is were grab_blocklist.sh expects it)
install dos2unix

named.conf is just an example named.conf

adserver.zone & malware.zone are sample zone files.

## How it all works

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

## firewall-cmd to rate limit dns any queries

```bash
firewall-cmd --permanent --zone public --direct --add-rule ipv4 filter INPUT 0 -p udp -m udp --dport 53 -m string --hex-string "|00ff0001|" --algo bm --to 65535 -m recent --set --name dnsanyquery --rsource
firewall-cmd --permanent --zone public --direct --add-rule ipv4 filter INPUT 1 -p udp -m udp --dport 53 -m string --hex-string "|00ff0001|" --algo bm --to 65535 -m recent --rcheck --seconds 60 --hitcount 5 --name dnsanyquery --rsource -j DROP
firewall-cmd --reload
```

Then to confirm they are added

```bash
iptables --list -n
```

The rules should up like

```bash
Chain INPUT_direct (1 references)
target     prot opt source               destination         
           udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:53 STRING match  "|00ff0001|" ALGO name bm TO 65535 recent: SET name: dnsanyquery side: source
DROP       udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:53 STRING match  "|00ff0001|" ALGO name bm TO 65535 recent: CHECK seconds: 60 hit_count: 5 name: dnsanyquery side: source
```
