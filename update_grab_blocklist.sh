#!/bin/sh

# put this in /etc/cron.weekly  to pulled latest version of grab_blocklist.sh

/bin/wget -q -O /etc/cron.daily/grab_blocklists.sh https://raw.githubusercontent.com/gpanula/ad_block_dns/master/grab_blocklists.sh && sed 's/biglists=0/biglists=1/' -i /etc/cron.daily/grab_blocklists.sh

exit 0
