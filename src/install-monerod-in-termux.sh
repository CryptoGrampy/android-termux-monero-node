#!/data/data/com.termux/files/usr/bin/sh

(
MONERO=~/monero-cli
MONERO_CLI=~/monero-cli/monero-cli
NODE_CONFIG=~/storage/shared/crypto/monero-cli/config
INTERNAL_NODE=~/storage/shared/crypto/monero-cli/blockchain
SD_NODE=~/storage/external-1/bitmonero
TERMUX_BOOT=~/.termux/boot
TERMUX_SHORTCUTS=~/.shortcuts
TERMUX_SCHEDULED=~/termux-scheduled
MONERO_CLI_URL=""

AUTO_UPDATE=0

# Detect Architecture

case $(uname -m) in
	arm | armv7l) MONERO_CLI_URL=https://downloads.getmonero.org/cli/androidarm7 ;;
	aarch64_be | aarch64 | armv8b | armv8l) MONERO_CLI_URL=https://downloads.getmonero.org/cli/androidarm8 ;;
	*) termux-toast -g bottom "Your device is not compatible- must be ARMv7 or v8"; exit 1 ;;
esac


# Preconfigure
if [ -d storage/downloads ]
then
echo Storage already configured. Skipping.
else
termux-setup-storage
fi

pkg upgrade -y
apt install nano wget termux-api jq -y
apt autoremove -y
apt autoclean

RESP=$(termux-dialog confirm -t "XMR Node" -i \
"This script will install the latest Monero Node software on your device

Make sure you have these apps installed (via F-Droid) before proceeding:

	- Termux Widget
	- Termux API
 	- Termux Boot (optional.
 	  Required for start-on-boot)

Are you ready to continue?" | jq '.text')
if [ "$RESP" = '"no"' ]
then
	exit 1
fi

termux-wake-lock
sleep 1

# Create Directories

mkdir -p $MONERO
mkdir -p $NODE_CONFIG
mkdir -p $TERMUX_BOOT
mkdir -p $TERMUX_SHORTCUTS
mkdir -p $TERMUX_SCHEDULED
cd $MONERO
ln  -sfT $TERMUX_SHORTCUTS widget\ scripts


# Pre-Clean Old Setup
rm -f $TERMUX_BOOT/before_start_monero_node
rm -f $TERMUX_BOOT/*XMR\ Node*
NODE_CONFIG_OLD=~/monero-cli/config
if [ -d $NODE_CONFIG_OLD ]
then
mv -u -n $NODE_CONFIG_OLD/* $NODE_CONFIG/
rm -r $NODE_CONFIG_OLD
fi


# Detect External Storage by checking for creation of Termux external-1 folder
SD=~/storage/external-1
INTERNAL_FREE=$(df | tail -1 | awk '{print $4}')
cd
if [ -d $SD ]
then
CONFIRM_EXTERNAL=$(termux-dialog confirm -t "SD confirmation" -i "Are you using an SD card?" | jq '.text')
	if [ "$CONFIRM_EXTERNAL" = '"yes"' ]
        then
        mkdir -p $SD_NODE
        NODE_DATA=$SD_NODE
        echo Using SD Card
	elif [ -e $SD_NODE/lmdb/data.mdb ]
	then
	BLOCKCHAIN=$(ls $SD_NODE/lmdb/data.mdb -l | awk '{print $5}')
		if [ $INTERNAL_FREE -gt $BLOCKCHAIN ]
                then MOVE_DATA=$(termux-dialog radio -t "Existing data detected. Move?" -v "Move my data,Leave in place" | jq '.index')
		        if  [ "$MOVE_DATA" = '0' ]
                        then
      			mkdir -p $INTERNAL_NODE
                        cp -r $SD_NODE/* $INTERNAL_NODE/
                        rm -r $SD_NODE/
                        echo Moving Blockchain to Internal Storage
                        NODE_DATA=$INTERNAL_NODE
                        sleep 1
                        else
                        echo Leaving in place
                        NODE_DATA=$SD_NODE
                        sleep 1
                        fi
		else
		echo "Not enough free space. \n$(df -h | tail -1 | awk '{print $4}') available\n45G required"
		termux-wake-unlock
		exit 1
		fi
	elif [ "$INTERNAL_FREE" -gt '50000000' ]
	then
	CONFIRM_INTERNAL=$(termux-dialog confirm -t "Internal Storage" -i \
"                       •WARNING•

All Flash Storage has a limited number of writes. This includes SD, SSD, and Internal Storage.

Should the Node use all available write cycles, the storage - or this device - will be bricked.

For this reason, external storage is recommended.

Would you like to use INTERNAL Storage?" | jq '.text')
        	if [ "$CONFIRM_INTERNAL" = '"yes"' ]
        	then
        	mkdir -p $INTERNAL_NODE
        	NODE_DATA=$INTERNAL_NODE
        	echo Using Internal Storage
        	else
        	echo  give me no choice but to exit 🛸
		termux-wake-unlock
        	exit 1
        	fi
	else
	echo "Not enough free space. \n$(df -h | tail -1 | awk '{print $4}') available\n45G required"
	termux-wake-unlock
	exit 1
	fi
elif [ "$INTERNAL_FREE" -gt '50000000' ] || [ -e $INTERNAL_NODE/lmdb/data.mdb ]
then
CONFIRM_INTERNAL=$(termux-dialog confirm -t "Internal Storage" -i \
"                       •WARNING•

All Flash Storage has a limited number of writes. This includes SD, SSD, and Internal Storage.

Should the Node use all available write cycles, the storage - or this device - will be bricked.

For this reason, external storage is recommended.

Would you like to use INTERNAL Storage?" | jq '.text')
	if [ "$CONFIRM_INTERNAL" = '"yes"' ]
	then
        mkdir -p $INTERNAL_NODE
        NODE_DATA=$INTERNAL_NODE
	echo Using Internal Storage
        else
        echo  give me no choice but to exit 🛸
	termux-wake-unlock
        exit  1
        fi
else
echo "Not enough free space. \n$(df -h | tail -1 | awk '{print $4}') available\n45G required"
termux-wake-unlock
exit 1
fi

# Create Sym links to blockchain data and config
cd $MONERO
ln -sf $NODE_DATA -T blockchain
ln -sf $NODE_CONFIG -T config

cd $NODE_CONFIG
# Create Monerod Config file
 cat << EOF > config.default
# Data directory (blockchain db and indices)
	data-dir=$NODE_DATA

# Log file
	log-file=/dev/null
	max-log-file-size=0           # Prevent monerod from creating log files

#Peer ban list
	#ban-list=$NODE_CONFIG/block.txt

# block-sync-size=50
	prune-blockchain=1            # 1 to prune

# P2P (seeding) binds
	p2p-bind-ip=0.0.0.0           # Bind to all interfaces. Default is local 127.0.0.1
	p2p-bind-port=18080           # Bind to default port

# Restricted RPC binds (allow restricted access)
# Uncomment below for access to the node from LAN/WAN. May require port forwarding for WAN access
	rpc-restricted-bind-ip=0.0.0.0
	rpc-restricted-bind-port=18089

# Unrestricted RPC binds
	rpc-bind-ip=127.0.0.1         # Bind to local interface. Default = 127.0.0.1
	rpc-bind-port=18081           # Default = 18081
	#confirm-external-bind=1      # Open node (confirm). Required if binding outside of localhost
	#restricted-rpc=1             # Prevent unsafe RPC calls.

# Services
	rpc-ssl=autodetect
  	no-zmq=1
	no-igd=1                            # Disable UPnP port mapping
	db-sync-mode=fast:async:1000000     # Switch to db-sync-mode=safe for slow but more reliable db writes

# Emergency checkpoints set by MoneroPulse operators will be enforced to workaround potential consensus bugs
# Check https://monerodocs.org/infrastructure/monero-pulse/ for explanation and trade-offs
	#enforce-dns-checkpointing=1
	disable-dns-checkpoints=1
	enable-dns-blocklist=1


# Connection Limits
	out-peers=32              # This will enable much faster sync and tx awareness; the default 8 is suboptimal nowadays
	in-peers=32               # The default is unlimited; we prefer to put a cap on this
	limit-rate-up=1048576     # 1048576 kB/s == 1GB/s; a raise from default 2048 kB/s; contribute more to p2p network
	limit-rate-down=1048576   # 1048576 kB/s == 1GB/s; a raise from default 8192 kB/s; allow for faster initial sync
EOF

# Check for existing Config
if [ -e config.txt ]
then
	DEL=$(termux-dialog radio -t "Existing configuration found" -v "Update,Keep Existing" | jq '.text')
	if [ "$DEL" != '"Update"' ]
	then
	echo "Keep existing config file.\n   Updating data-dir flag"
	cp config.txt config.old
	sleep 2
	sed -i "s|$SD_NODE|$NODE_DATA|g" config.txt
	sed -i "s|$INTERNAL_NODE|$NODE_DATA|g" config.txt
	sed -i -z "s|data-dir=\n|data-dir=$NODE_DATA\n|g" config.txt
	else
	mv config.txt config.old
	cp config.default config.txt
	echo Overwriting config file.. Done.
	fi
else
cp config.default config.txt
echo Creating config file.. Done.
fi

# Prompt to Enable Pruning
if [ "$NODE_DATA" = "$SD_NODE" ]
then
PRUNE=$(termux-dialog radio -t "Run a" -v "Recommended - Full Node     (256gb preferred),Low Storage - Pruned Node     (64gb  minimum)" | jq '.text')
	if [ "$PRUNE" = '"Low Storage - Pruned Node     (64gb  minimum)"' ]
	then
	sed -i 's/prune-blockchain=0/prune-blockchain=1/g' config.txt
	sed -i 's/#prune/prune/g' config.txt
	echo Running Pruned
	elif [ "$PRUNE" = '"Recommended - Full Node     (256gb preferred)"' ]
	then
	sed -i 's/prune-blockchain=1/prune-blockchain=0/g' config.txt
	sed -i 's/#prune/prune/g' config.txt
	echo Running Full Node 🎉
	else
	echo leaving as-is
	fi
elif [ "$INTERNAL_FREE" -lt '150000000' ]
then
sed -i 's/prune-blockchain=0/prune-blockchain=1/g' config.txt
sed -i 's/#prune/prune/g' config.txt
echo Running Pruned
else
PRUNE=$(termux-dialog radio -t "Run a" -v "Recommended - Full Node     (256gb preferred),Low Storage - Pruned Node     (64gb  minimum)" | jq '.text')
	if [ "$PRUNE" = '"Low Storage - Pruned Node     (64gb  minimum)"' ]
	then
	sed -i 's/prune-blockchain=0/prune-blockchain=1/g' config.txt
	sed -i 's/#prune/prune/g' config.txt
	echo Running Pruned
	elif [ "$PRUNE" = '"Recommended - Full Node     (256gb preferred)"' ]
	then
	sed -i 's/prune-blockchain=1/prune-blockchain=0/g' config.txt
	sed -i 's/#prune/prune/g' config.txt
	echo Running Full Node 🎉
	else
	echo leaving as-is
	fi
fi

# Create Scripts
cd $TERMUX_SHORTCUTS

  cat << EOF > Start\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh

RESP=\$(termux-dialog radio -t "Run Node in:" -v "Background,Foreground" | jq '.text')
	if [ \$RESP = '"Background"' ]
	then
	termux-wake-lock
	cd $MONERO_CLI
	./monerod --config-file $NODE_CONFIG/config.txt --detach
	sleep 15
	cp $TERMUX_SHORTCUTS/.Boot\ XMR\ Node $TERMUX_BOOT/Boot\ XMR\ Node
	termux-job-scheduler --job-id 1 -s $TERMUX_SCHEDULED/xmr_notifications
	termux-job-scheduler --job-id 2 -s $TERMUX_SCHEDULED/Update\ XMR\ Node --period-ms 86400000
	sleep 1
	fi

	if [ \$RESP = '"Foreground"' ]
	then
	termux-wake-lock
	cp $TERMUX_SHORTCUTS/.Boot\ XMR\ Node $TERMUX_BOOT/Boot\ XMR\ Node
	termux-job-scheduler --job-id 1 -s $TERMUX_SCHEDULED/xmr_notifications
	termux-job-scheduler --job-id 2 -s $TERMUX_SCHEDULED/Update\ XMR\ Node --period-ms 86400000
	cd $MONERO_CLI
	sleep 1
	./monerod --config-file $NODE_CONFIG/config.txt
fi
exit 0

EOF


  cat << EOF > .Boot\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
cd $MONERO_CLI
./monerod --config-file $NODE_CONFIG/config.txt --detach
sleep 15
cp $TERMUX_SHORTCUTS/.Boot\ XMR\ Node $TERMUX_BOOT/Boot\ XMR\ Node
termux-job-scheduler --job-id 1 -s $TERMUX_SCHEDULED/xmr_notifications
termux-job-scheduler --job-id 2 -s $TERMUX_SCHEDULED/Update\ XMR\ Node --period-ms 86400000
sleep 1
EOF

 cat << EOF > Stop\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
cd $MONERO_CLI
./monerod exit && tail --pid=\$(pidof monerod) -f /dev/null && echo 'Exited'
rm -f $TERMUX_BOOT/Boot\ XMR\ Node

termux-wake-unlock
termux-notification -i monero -c "🔴 XMR Node Shutdown" --priority low --alert-once
termux-job-scheduler --cancel --job-id 1
termux-job-scheduler --cancel --job-id 2
sleep 1
termux-toast -g middle "Stopped XMR Node"

EOF

 cat << EOF > XMR\ Node\ Status
#!/data/data/com.termux/files/usr/bin/sh
cd $MONERO_CLI
./monerod print_net_stats
./monerod status
sleep 10
EOF

 cat << 'EOF' > xmr_notifications
#!/data/data/com.termux/files/usr/bin/sh
sleep 7
REQ=$(curl -sk https://127.0.0.1:18081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H 'Content-Type: application/json')
LAST=$(date +%r)
if [ "$REQ" ]
then

EOF

# Refresh Notification handling  (not ideal method)

cp xmr_notifications xmr_notifications_released

cat << 'EOF' >> xmr_notifications
termux-job-scheduler --job-id 1 -s ~/termux-scheduled/xmr_notifications_acquired --period-ms 900000
termux-toast -g middle -b black -c green Node Running! Check Notification.
else
NOTIFICATION="🟡 Connecting...Please wait 30s($LAST)"
termux-notification -i monero -t "$NOTIFICATION" --ongoing --priority max --alert-once --button1 "SHUTDOWN NODE" --button1-action 'monero-cli/monero-cli/monerod exit | termux-wake-unlock | termux-job-scheduler --cancel --job-id 1 | termux-job-scheduler --cancel --job-id 2 | termux-toast -g middle "Stopped XMR Node" | rm .termux/boot/Boot\ XMR\ Node | termux-notification -i monero -c "🔴 XMR Node Shutdown" --priority low' --button2 "REFRESH STATUS" --button2-action 'bash -l -c termux-scheduled/xmr_notifications'
sleep 23
termux-job-scheduler --job-id 1 -s ~/termux-scheduled/xmr_notifications_acquired --period-ms 900000
fi
EOF

cat << 'EOF' >> xmr_notifications_released
DATA=$(echo $REQ | jq '.result')
	DATE=$(date -d @$(echo "$DATA" | jq '.start_time' ))
	VERSION=$(echo "$DATA" | jq -r '.version' )
	STATUS=$(echo "$DATA" | jq -r 'if .offline == false then "🟢 XMR Node Online" else "🔴 XMR Node Offline" end')
	OUTGOING_CONNECTIONS=$(echo "$DATA" | jq '.outgoing_connections_count' )
	P2P_CONNECTIONS=$(echo "$DATA" | jq '.incoming_connections_count' )
	RPC_CONNECTIONS=$(echo "$DATA" | jq '.rpc_connections_count' )
	UPDATE_AVAILABLE=$(echo "$DATA" | jq -r 'if .update_available == true then "📬️ XMR Update Available" else "" end' )
	SYNC_STATUS=$(printf %.1f $(echo "$DATA" | jq '(.height / .target_height)*100'))
	STORAGE_REMAINING=$(printf %.1f $(echo "$DATA" | jq '.free_space * 0.000000001'))
	LOCAL_IP=$(echo $(termux-wifi-connectioninfo | jq '.ip') | tr -d '"')

	NOTIFICATION=$(printf '%s\n' "⛓️ XMR-$VERSION" "🕐️ Running Since: $DATE" "🔄 Sync Progress: $SYNC_STATUS %" "📤️ OUT: $OUTGOING_CONNECTIONS / 🌱 P2P: $P2P_CONNECTIONS / 📲 RPC: $RPC_CONNECTIONS" "💾 Free Space: $STORAGE_REMAINING GB" "🔌 Local IP: ${LOCAL_IP}:18089" "$UPDATE_AVAILABLE" )

else
	STATUS="🔴 ERROR: Is your node running? ($LAST)"
	NOTIFICATION="Refresh the notification.
Otherwise, restart the node"
fi
termux-notification -i monero -c "$NOTIFICATION" -t "$STATUS ($LAST)" --ongoing --priority low --alert-once --button1 "SHUTDOWN NODE" --button1-action 'monero-cli/monero-cli/monerod exit | termux-wake-unlock | termux-job-scheduler --cancel --job-id 1 | termux-job-scheduler --cancel --job-id 2 | termux-toast -g middle "Stopped XMR Node" | rm .termux/boot/Boot\ XMR\ Node | termux-notification -i monero -c "🔴 XMR Node Shutdown" --priority low' --button2 "ACQUIRE WAKELOCK" --button2-action 'termux-wake-lock | termux-job-scheduler --job-id 1 -s ~/termux-scheduled/xmr_notifications_acquired --period-ms 900000' --button3 "REFRESH STATUS" --button3-action 'bash -l -c termux-scheduled/GET_REFRESH'
EOF


# Fill notification variables

sed -i -z "s|sleep 7\n|sleep 7\ntermux-toast -g middle -b black Node Starting Up.. Please Wait 10s.\n|g" xmr_notifications
sed -i -z "s|sleep 7\n| \n|g" xmr_notifications_released
cp xmr_notifications_released xmr_notifications_acquired
sed -i -z "s|ACQUIRE |RELEASE |g" xmr_notifications_acquired
sed -i -z "s|acquired|released|g" xmr_notifications_acquired 
sed -i -z "s|termux-wake-lock|termux-wake-unlock|g" xmr_notifications_acquired
sed -i -z "s|GET_REFRESH|xmr_notifications_acquired|g" xmr_notifications_acquired
sed -i -z "s|GET_REFRESH|xmr_notifications_released|g" xmr_notifications_released


 cat << EOF > Update\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
sleep 5
func_xmrnode_install(){
	./Stop\ XMR\ Node && echo "Monero Node Stopped"
	cd
	wget -O monero.tar.bzip2 $MONERO_CLI_URL
	tar jxvf monero.tar.bzip2
	rm monero.tar.bzip2
	rm -rf $MONERO_CLI
	mv monero-a* $MONERO_CLI
	cd $TERMUX_SHORTCUTS
	sleep 1
	termux-toast -g bottom "Starting XMR Node.."
	./Start\ XMR\ Node
}

func_xmrnode_install_prompt(){
	#Alert the user / confirm the update
	RESP=\$(termux-dialog confirm \
	-t "Update XMR Node" \
	-i "An update is available. Do you wish to install?" | jq '.text')
	if [ \$RESP = '"yes"' ]
	then
		func_xmrnode_install
	fi
}

REQ=\$(curl -sk https://127.0.0.1:18081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H 'Content-Type: application/json')
if [ "\$REQ" ]
then
	DATA=\$(echo \$REQ | jq '.result')
	UPDATE_AVAIL=\$(echo \$DATA | jq '.update_available' )
	if [ "\$UPDATE_AVAIL" = "true" ]
	then
		#Prompt user to update (currently hardcoded)
		if [ $AUTO_UPDATE = 1 ]
		then
			func_xmrnode_install
		else
			func_xmrnode_install_prompt
		fi
	else
		VERSION=\$(echo \$DATA | jq '.version')
		sleep 1
		termux-toast -g bottom "No updates available. Current version is the latest: \$VERSION"
	fi
else
  echo "Your node is either offline or still starting up.  Try again in a few minutes."
  exit 1
fi

EOF


 cat << EOF > Uninstall\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/bash
RESP=\$(termux-dialog confirm -t "Uninstall XMR Node" -i "Do you wish to remove XMR node and all its associated files? (deleting the blockchain remains optional)" | jq '.text')
#1 = Uninstall
if [ \$RESP = '"yes"' ]
then
	echo "Uninstalling Monero Termux node"

	cd $TERMUX_SHORTCUTS
	./Stop\ XMR\ Node

	rm -f Start\ XMR\ Node
	rm -f Stop\ XMR\ Node
	rm -f Update\ XMR\ Node
	rm -f XMR\ Node\ Status
	rm -rf $MONERO_CLI
	rm -f .Boot\ XMR\ Node
	rm -f $TERMUX_BOOT/*XMR\ Node*
	cd $TERMUX_SCHEDULED
	rm -f xmr_notifications*
	rm -f Update\ XMR\ Node

	cd $TERMUX_SHORTCUTS
	RESP=\$(termux-dialog radio -t "Delete Blockchain?" -v "Yes,Skip" | jq '.text')
	#'"Yes"' = Uninstall
	if [ \$RESP = '"Yes"' ]
	then
        echo "Deleting Blockchain"
	rm -rf $NODE_DATA
        fi

	RESP=\$(termux-dialog radio -t "Tidy up? (Remove Config file, Uninstall Script and Termux' Monero folder)" -v "Yes,Skip" | jq '.text')
	#'"Yes"' = Uninstall
	if [ \$RESP = '"Yes"' ]
	then
        echo "Deleting config file"
	rm -rf $NODE_CONFIG
	rm -rf $MONERO
	rm -rf Uninstall\ XMR\ Node
	fi
	exit 1
fi

EOF


# Finish Setting Up
chmod +x Start\ XMR\ Node
chmod +x Stop\ XMR\ Node
chmod +x Update\ XMR\ Node
chmod +x XMR\ Node\ Status
chmod +x .Boot\ XMR\ Node
chmod +x xmr_notifications*
chmod +x Uninstall\ XMR\ Node

cp .Boot\ XMR\ Node  $TERMUX_BOOT/Boot\ XMR\ Node
mv xmr_notifications* $TERMUX_SCHEDULED
cp Update\ XMR\ Node $TERMUX_SCHEDULED


# Start
cd $TERMUX_SHORTCUTS
./Stop\ XMR\ Node && echo "Monero Node Stopped"
cd
wget -c -O monero.tar.bzip2 $MONERO_CLI_URL
tar jxvf monero.tar.bzip2
rm monero.tar.bzip2
rm -rf $MONERO_CLI
mv monero-a* $MONERO_CLI
cd $TERMUX_SHORTCUTS
./.Boot\ XMR\ Node

echo "I'm Done! 👍.
..."
sleep 1
echo "But.."
sleep 1
echo "	
	A couple things for you to do:

1. Add the Termux:Widget to your homescreen
2. To run the node automatically @ boot:
    Install Termux:Boot from F-Droid and run it once.
3. To set a static IP to enable LAN access:
    From Android Settings, go to:
  - WiFi > edit saved network > advanced > DHCP
  - You'll need to change from "automatic" to "manual", and set the IP to:
    $(termux-wifi-connectioninfo | jq '.ip')
4. To enable P2P seeding:
  - Go to your router settings (usually 192.168.0.1 in your browser)
    Find "Port Forwarding",and forward
    "public/external" port 18080 to "internal/private" port 18080,
    Setting the "internal/private" ip to:
    $(termux-wifi-connectioninfo | jq '.ip')
4b. To enable Wallet access from WAN:
      - Forward port 18089 to 18089
5.  The config file is located on your internal storage at
       	crypto/monero-cli/config
	      ☠️ Cheers ☠️ "
)
