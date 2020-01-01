#!/bin/sh

###########################################################
### This script pulls down mutliple lists of domains    ###
### Then creates a bind zone file from the lists        ###
###
### The idea is to block access to the domains by       ###
### having them resolve to something bogus	            ###
### that can easily be filtered                         ###
###
### you need to put remove-addomains.pl in /usr/local/bin
###########################################################

# hint: put this in /etc/cron.daily

# let the other daily cron job to finish
#sleep 900

# debug > 0 print debug info and don't reload named
debug=0

# if $justgrab > 0 ; then only download the domain lists
justgrab=0

# chroot named?
if [ -z "$CHROOT" ]
then
    # environment didn't set $CHROOT, lets check for chroot'ed named
    if [ -e /var/named/chroot ]
    then
        CHROOT=1
    else
        CHROOT=0
    fi
fi

# include the big lists?
# note: this bumps named memory footprint to ~750MB
biglists=0

# are we systemctl enabled?
SYSTEMCTL=$( which systemctl )
SERVICE=$( which service )

if [ -z "${SYSTEMCTL}" ]
then
    # using good old `service`
    RELOAD_NAMED="${SERVICE} named reload"
    START_NAMED="${SERVICE} named start"
    STOP_NAMED="${SERVICE} named stop"
else
    if [ $CHROOT -gt 0 ]
    then
        # working with chroot'ed named
        # and systemctl is being used
        RELOAD_NAMED="${SYSTEMCTL} reload named-chroot"
        STOP_NAMED="${SYSTEMCTL} stop named-chroot"
        START_NAMED="${SYSTEMCTL} start named-chroot"
    else
        # non-chroot'ed named and using systemctl
        RELOAD_NAMED="${SYSTEMCTL} reload named"
        STOP_NAMED="${SYSTEMCTL} stop named"
        START_NAMED="${SYSTEMCTL} start named"
    fi
fi

# if running in alpine, we'll assume it is a container
OS="$( grep ^ID /etc/os-release | cut -d= -f2 )"

if [ "${OS}" == "alpine" ]
then
  RELOAD_NAMED="kill -HUP $( ps ax | grep named | grep -v grep | awk '{ print $1 }' )"
  STOP_NAMED="kill $( ps ax | grep named | grep -v grep | awk '{ print $1 }' )"
  START_NAMED="/usr/sbin/named -4 -c /etc/named.conf -f -L /var/named/chroot/var/log/default.log -t /var/named/chroot"
fi

if [ $debug -gt 0 ]
then
    echo "CHROOT is ${CHROOT}"
    echo "RELOAD_NAMED is ${RELOAD_NAMED}"
    echo "STOP_NAMED is ${STOP_NAMED}"
    echo "START_NAMED is ${START_NAMED}"
fi


# Destination directory
# if the calling environment doesn't set DEST then look for one
if [ -z "${DEST}" ]
then
    # check first for /var/named
    if [ -e /var/named ]
    then
        DEST="/var/named/masters"
    fi
    
    # now check to see if named is being chroot'ed and we want it(CHROOT > 0)
    if [ -e /var/named/chroot ] && [ ${CHROOT} -gt 0 ]
    then
        DEST="/var/named/chroot/var/named/masters"
    fi
fi

# make sure we have a destination
if [ -z ${DEST} ]
then
    echo "!!! FAILED to find a destination directory !!!!"
    exit 5
fi

# Path and file containing the exception list aka allowed domains
# make sure allowed_domains.txt exists
if [ ! -e /etc/allowed_domains.txt ]
then
    touch /etc/allowed_domains.txt
fi

ALLOWED="/etc/allowed_domains.txt"

# Path and file containing list of custom domains to block
# make sure it exists
if [ ! -e /etc/custom_blocked_domains.txt ]
then
    touch /etc/custom_blocked_domains.txt
fi

BLOCKED="/etc/custom_blocked_domains.txt"

# the list of lists
echo 'ad,http://pgl.yoyo.org/adservers/serverlist.php?hostformat=bindconfig&showintro=0&mimetype=plaintext' > /tmp/thelist.$$
echo 'malware,http://mirror1.malwaredomains.com/files/domains.txt' >> /tmp/thelist.$$
echo 'zeus,https://zeustracker.abuse.ch/blocklist.php?download=baddomains' >> /tmp/thelist.$$
echo 'zeus,https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist' >> /tmp/thelist.$$
echo 'zeus,https://ransomwaretracker.abuse.ch/downloads/RW_DOMBL.txt' >> /tmp/thelist.$$
echo 'malware2,http://www.malwaredomainlist.com/hostslist/hosts.txt' >> /tmp/thelist.$$
# add lists from pi-hole
# ref: https://github.com/pi-hole/pi-hole/blob/master/automated%20install/basic-install.sh#L1200
# ref: https://github.com/pi-hole/pi-hole/wiki/Customising-sources-for-ad-lists
echo 'stevenblack,https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts' >> /tmp/thelist.$$ 
echo 'justdomains,https://mirror1.malwaredomains.com/files/justdomains' >> /tmp/thelist.$$
echo 'justdomains,https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt' >> /tmp/thelist.$$
echo 'justdomains,https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt' >> /tmp/thelist.$$
echo 'justdomains,https://hosts-file.net/ad_servers.txt' >> /tmp/thelist.$$

if [ $biglists -gt 0 ]
then
    echo 'notrackdomain,https://raw.githubusercontent.com/notracking/hosts-blocklists/master/domains.txt' >> /tmp/thelist.$$
    echo 'notrackhosts,https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt' >> /tmp/thelist.$$
fi


{ while read zone ; do
        
        # break out the type and url
        ztype="$( echo "$zone" | cut -d',' -f1 )"
        zurl="$( echo "$zone" | cut -d',' -f2 )"
        
        if [ $debug -gt 0 ]
        then
            echo "ztype is ${ztype}"
            echo "zurl is ${zurl}"
        fi
        
        # grab the list
        wget -q --no-check-certificate -O "/tmp/temp_${ztype}_file" "${zurl}"
        
        # backup the existing list
        if [ -e "${DEST}/${ztype}_block.txt" ]
        then
            # check if we are just downloading the domain lists
            if [ $justgrab -eq 0 ]
            then
                mv "${DEST}/${ztype}_block.txt" "${DEST}/${ztype}_block.txt.$(date +%Y%m%d)"
            fi
        fi
        
        dos2unix "/tmp/temp_${ztype}_file"
        
done } < /tmp/thelist.$$


# check to see if we are just downloading the domain lists
if [ $justgrab -gt 0 ]
then
    if [ $debug -gt 0 ]
    then
        echo "justgrab is ${justgrab}"
        echo "debug is ${debug}"
        echo "done downloading lists."
    fi
    rm /tmp/thelist.$$
    exit 5
fi

## Now convert the list into just a list of domains
if [ $debug -gt 0 ]
then
    echo Converting the lists into just a list of domains
    ls -rtl /tmp/temp*file
    # this removing any trailing dots sed 's/[\.]*$//'
fi
grep -vf ${ALLOWED} /tmp/temp_ad_file | sed y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/ | grep ^zone | cut -d' ' -f2 | sed 's/"//g' | sed 's/[ \t]*$//g' | sed 's/www\.//g' | sed 's/^www[1-9]\.//g' | sed 's/[\.]*$//g' | awk ' !x[$0]++' > /tmp/ad.domains
grep -vf ${ALLOWED} /tmp/temp_malware_file | sed y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/ | grep -v \# | awk '{ print $1 }' | sed 's/"//g' | sed 's/[ \t]*$//g' | sed 's/www\.//g' | sed 's/^www[1-9]\.//g' | sed 's/[\.]*$//g' > /tmp/malware.domains
grep -vf ${ALLOWED} /tmp/temp_zeus_file | grep -v '#' | sed y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/ | grep -v '^$' | sed 's/[ \t]*$//g' | sed 's/www\.//g' | sed 's/^www[1-9]\.//g' | sed 's/[\.]*$//g' > /tmp/zeus.domains
grep -vf ${ALLOWED} /tmp/temp_malware2_file | grep 127.0.0.1 | sed y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/ | grep -v localhost | cut -d' ' -f3 | sed 's/[ \t]*$//g' | sed 's/www\.//g' | sed 's/^www[1-9]\.//g' | sed 's/[\.]*$//g' > /tmp/malware2.domains
grep -vf ${ALLOWED} /tmp/temp_justdomains_file | grep -v \# |  awk '{ print $NF }' | grep -v localhost | sed 's/www\.//g' | sed 's/^www[1-9]\.//g' | sed 's/[[:digit:]]\+\.//g' | sort -u | sed 's/[A-Z]/\L&/g' | awk -F . 'NF!=1' | sed '/^\s*$/d' >> /tmp/ad.domains
grep -vf ${ALLOWED} /tmp/temp_stevenblack_file | grep 0.0.0.0 | awk '{ print $NF }' | grep -v 0.0.0.0 | sed 's/www\.//g' | sed 's/^www[1-9]\.//g' | sed 's/[[:digit:]]\+\.//g' | sort -u | sed 's/[A-Z]/\L&/g' | awk -F . 'NF!=1' | sed '/^\s*$/d' >> /tmp/ad.domains

if [ $biglists -gt 0 ]
then
    grep -vf ${ALLOWED} /tmp/temp_notrackdomain_file | grep -v \# | cut -d '/' -f2 | sed y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/ | sed 's/[\.]*$//g' > /tmp/notrackdomain.domains
    grep -vf ${ALLOWED} /tmp/temp_notrackhosts_file |  grep -v \# | grep -v localhost | awk '{ print $2 }' | sed y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/  | sed 's/[\.]*$//g' > /tmp/notrackhosts.domains
fi

# add our custom blocked domains
cat $BLOCKED >> /tmp/ad.domains

## Now remove dupes.
if [ $debug -gt 0 ]
then
    echo Removing Dupes now
fi

if [ -e /tmp/notrackdomain.domains ]
then
    cat /tmp/notrackdomain.domains > /tmp/malware.$$
fi

if [ -e /tmp/notrackhosts.domains ]
then
    cat /tmp/notrackhosts.domains >> /tmp/malware.$$
fi

if [ -e /tmp/malware.domains ]
then
    cat /tmp/malware.domains >> /tmp/malware.$$
fi

if [ -e /tmp/zeus.domains ]
then
    cat /tmp/zeus.domains >> /tmp/malware.$$
fi

if [ -e /tmp/malware2.domains ]
then
    cat /tmp/malware2.domains >> /tmp/malware.$$
fi

# initial sort of the complete malware list and attempt to remove dupes
sort -u /tmp/malware.$$ > /tmp/malware_t.$$

# final removal of dupes
awk ' !x[$0]++' /tmp/malware_t.$$ > /tmp/malware.domains

# clean up the temp files from deduping malware
if [ $debug -eq 0 ]
then
    rm -f /tmp/malware.$$
    rm -f /tmp/malware_t.$$
fi

# remove malware domains from the ad domain list
if [ -e /tmp/ad-domain-dupes.txt ]
then
    rm -f /tmp/ad-domain-dupes.txt
fi

if [ -e /tmp/ad_domains_removed_from_malware.txt ]
then
    rm -f /tmp/ad_domains_removed_from_malware.txt
fi

# remove-addomains.pl will remove ad domains from the malware list
# leaving us with /tmp/ad_domains_removed_from_malware.txt
/usr/local/bin/remove-addomains.pl

#grep -vf /tmp/ad-domain-dupes.txt /tmp/ad.domains | sed 's/[ \t]*$//g' | sed 's/$/" { type master; notify no; check-names ignore; file "masters\/adserver.zone"; };/g' | sed 's/^/zone "/g' > ${DEST}/ad_block.txt
cat /tmp/ad.domains | sort -u | sed 's/[ \t]*$//g' | sed 's/$/" { type master; notify no; check-names ignore; file "masters\/adserver.zone"; };/g' | sed 's/^/zone "/g' > ${DEST}/ad_block.txt

# build the malware list
#cat /tmp/malware.domains | sed 's/[ \t]*$//g' | sed 's/$/" { type master; notify no; check-names ignore; file "masters\/malware.zone"; };/g' | sed 's/^/zone "/g' > ${DEST}/malware_block.txt
cat /tmp/ad_domains_removed_from_malware.txt | sed 's/[ \t]*$//g' | sed 's/$/" { type master; notify no; check-names ignore; file "masters\/malware.zone"; };/g' | sed 's/^/zone "/g' > ${DEST}/malware_block.txt



if [ $debug -gt 0 ]
then
    ls -lrt ${DEST}/*block*
fi

## Now see if we have built non-zero byte block files
{ while read zone ; do
        
        # break out the type
        ztype=$( echo "$zone" | cut -d',' -f1 )
        
        # remove the temp files
        if [ $debug -eq 0 ]
        then
            rm -f "/tmp/temp_${ztype}_file"
            rm -f "/tmp/${ztype}.domains"
        fi
        
        if [ $debug -gt 0 ]
        then
            echo "================================================================"
            echo "Now checking the results for ${DEST}/${ztype}_block.txt"
            if [ -e "${DEST}/${ztype}_block.txt" ]
            then
                ls -lrt "${DEST}/${ztype}_block.txt"
            else
                echo "${DEST}/${ztype}_block.txt NOT FOUND"
            fi
            echo ""
        fi
        
        if [ -s "${DEST}/${ztype}_block.txt" ]
        then
            ## Success! The block file is non-zero
            if [ $debug -gt 0 ]
            then
                echo "Success! The block file ${DEST}/${ztype}_block.txt is non-zero"
            fi
            
            # remove our backup (if it exists)
            if [ -e "${DEST}/${ztype}_block.txt.old" ]
            then
                rm "${DEST}/${ztype}_block.txt.old"
            fi
            
            if [ -e "${DEST}/${ztype}_block.txt.$(date +%Y%m%d)" ]
            then
                # this just moves the current backup out of the way
                # we do this in case the named reload fails, we can roll-back
                mv "${DEST}/${ztype}_block.txt.$(date +%Y%m%d)" "${DEST}/${ztype}_block.txt.old"
            fi
        else
            if [ -e "${DEST}/${ztype}_block.txt" ]
            then
                ## Failure! The block file is zero bytes
                # remove the new block file
                if [ $debug -gt 0 ]
                then
                    echo "Failure! The block file ${DEST}/${ztype}_block.txt is zero bytes"
                fi
                
                # remove the new block file, if it exists
                if [ -e "${DEST}/${ztype}_block.txt" ]
                then
                    rm "${DEST}/${ztype}_block.txt"
                fi
                
                # put the old block file back in place, if it isn't zero bytes
                if [ -s "${DEST}/${ztype}_block.txt.$(date +%Y%m%d)" ]
                then
                    mv "${DEST}/${ztype}_block.txt.$(date +%Y%m%d)" "${DEST}/${ztype}_block.txt"
                else
                    echo "!!!! ERROR !!!! OLD ${ztype}_block.txt is ZERO Bytes"
                fi
            else
                # we are ok because it didn't exist to begin with
                # maybe it was combined in the malware zone file (e.g. zeus)
                echo "Original ${DEST}/${ztype}_block.txt NOT FOUND and we are ok with that"
            fi
        fi
        
        if [ $debug -gt 0 ]
        then
            echo "================================================================"
            echo ""
        fi
        
done } < /tmp/thelist.$$


## Cleanup temp files
if [ $debug -eq 0 ]
then
    rm -f /tmp/ad-domain-dupes.txt
    rm -f /tmp/zeus-domain-dupes.txt
    rm -f /tmp/malware.$$
    rm -f /tmp/malware_t.$$
fi


## Reload Named
if [ $debug -eq 0 ]
then
    #/etc/init.d/named reload
    ${RELOAD_NAMED}
    if [ $? -gt 0 ]
    then
        echo ah crap, named reload failed!  Rolling back.
        { while read zone ; do
                
                # break out the type
                ztype=$( echo "$zone" | cut -d',' -f1 )
                
                if [ -e "${DEST}/${ztype}_block.txt.old" ]
                then
                    rm -f "${DEST}/${ztype}_block.txt"
                    mv "${DEST}/${ztype}_block.txt.old" "${DEST}/${ztype}_block.txt"
                fi
                
        done } < /tmp/thelist.$$
        
        #/etc/init.d/named stop
        #/etc/init.d/named start
        ${STOP_NAMED}
        ${START_NAMED}
    fi
else
    echo Debug not equal to ZERO, not reloading Named
fi

rm -f /tmp/thelist.$$

exit 0
