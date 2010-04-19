#!/bin/bash
#
# Please re-write me in python.
#

set -x

EXT_DEV=eth1
SDL_URL="http://www.spamhaus.org/drop/drop.lasso"

SDL="/etc/iptables/spamhaus-drop.list"
SDL_PREV="/etc/iptables/spamhaus-drop_prev.list"

# Spamhaus Drop List: http://www.spamhaus.org/drop/
if [ ! -r $SDL ]; then
        wget -q -O $SDL -N -T 5 $SDL_URL
elif grep -q 'Spamhaus DROP List' $SDL; then
        mv $SDL $SDL_PREV
        wget -q -O $SDL -N -T 5 $SDL_URL
fi

if grep -q 'Spamhaus DROP List' $SDL; then
        if [ $SDL -nt $SDL_PREV ]; then
                echo "New DROP list downloaded.  Updating iptables rules."
                if iptables -t raw -L SDL_IN -vn 2>&1 | grep -q 'No chain/target/match by that name'
                        then iptables -t raw -N SDL_IN; new_in=1
                        else iptables -t raw -F SDL_IN; new_in=0
                fi
                if iptables -t raw -L SDL_OUT -vn 2>&1 | grep -q 'No chain/target/match by that name'
                        then iptables -t raw -N SDL_OUT; new_out=1
                        else iptables -t raw -F SDL_OUT; new_out=0
                fi
                sed -e 's/;.*//g' $SDL | grep -v '^[[:space:]]*$' | while read SBL
                do
                        # TODO Make rules persistent so we don't lose the counters
                        # TODO Can use "iptables-save | grep '-A SDL_IN'" and itterate,
                        #      then use the -c option to set the values
                        iptables -t raw -A SDL_IN -i $EXT_DEV -s $SBL -j DROP
                        iptables -t raw -A SDL_OUT -o $EXT_DEV -d $SBL -j DROP
                done
                iptables -t raw -A SDL_IN -j RETURN
                iptables -t raw -A SDL_OUT -j RETURN

                # Delete any existing SDL jump rules
                iptables -t raw -D PREROUTING -i eth1 -j SDL_IN
                iptables -t raw -D OUTPUT -o eth1 -j SDL_OUT

                # Add our SDL jump rules
                iptables -t raw -A PREROUTING -i eth1 -j SDL_IN
                iptables -t raw -A OUTPUT -o eth1 -j SDL_OUT
        else
                echo "DROP list unchanged.  Leaving rules intact"
                exit 0
        fi
else
        echo "Couldn't download new spamhaus drop list. Aborting."
        exit 1
fi
