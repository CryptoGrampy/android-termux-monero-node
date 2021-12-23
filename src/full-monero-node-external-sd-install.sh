#!/data/data/com.termux/files/usr/bin/sh

(
MONERO=~/monero-cli
MONERO_CLI=~/monero-cli/monero-cli
NODE_DATA=~/storage/external-1/bitmonero
NODE_CONFIG=~/monero-cli/config
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
termux-setup-storage

RESP=$(termux-dialog confirm -t "XMR Node" -i \
"This script will install the latest Monero Node software on your device

Make sure you have these apps installed (via F-Droid) before proceeding:

	- Termux Widget
	- Termux API
 	- Termux Boot (optional. required for start-on-boot)

Are you ready to continue?" | jq '.text')
if [ "$RESP" = '"no"' ]
then
	exit 1
fi

termux-wake-lock -y
pkg update -y
pkg install nano wget termux-api jq -y

# Pre-Clean Old Setup
rm -f $TERMUX_BOOT/before_start_monero_node


# Create Directories
mkdir -p $MONERO_CLI
mkdir -p $NODE_DATA
mkdir -p $TERMUX_BOOT
mkdir -p $TERMUX_SHORTCUTS
mkdir -p $TERMUX_SCHEDULED
mkdir -p $NODE_CONFIG


# Download Blocklist
cd $NODE_CONFIG
wget -O block.txt https://gui.xmr.pm/files/block.txt
# Create Monerod Config file
 cat << EOF > config.txt
# Data directory (blockchain db and indices)
	data-dir=$NODE_DATA

# Log file
	log-file=/dev/null
	max-log-file-size=0       # Prevent monerod from creating log files

#Peer ban list
	ban-list=$NODE_CONFIG/block.txt

# block-sync-size=50
# prune-blockchain=1             #Uncomment to prune

# P2P (seeding) binds
	p2p-bind-ip=0.0.0.0          # Bind to all interfaces. Default is local 127.0.0.1
	p2p-bind-port=18080          # Bind to default port

# Restricted RPC binds (allow restricted access)
# Uncomment below for access to the node from LAN/WAN. May require port forwarding for WAN access
	rpc-restricted-bind-ip=0.0.0.0
	rpc-restricted-bind-port=18089

# Unrestricted RPC binds
	rpc-bind-ip=127.0.0.1         # Bind to local interface. Default = 127.0.0.1
	rpc-bind-port=18081           # Default = 18081
	#confirm-external-bind=1       # Open node (confirm). Required if binding outside of localhost  
	#restricted-rpc=1              # Prevent unsafe RPC calls.

  	no-zmq=1
	no-igd=1                         # Disable UPnP port mapping
	db-sync-mode=safe                # Slow but reliable db writes

# Emergency checkpoints set by MoneroPulse operators will be enforced to workaround potential consensus bugs
# Check https://monerodocs.org/infrastructure/monero-pulse/ for explanation and trade-offs
	#enforce-dns-checkpointing=1
	disable-dns-checkpoints=1
	enable-dns-blocklist=1


# Connection Limits
	out-peers=32              # This will enable much faster sync and tx awareness; the default 8 is suboptimal nowadays
	in-peers=100            # The default is unlimited; we prefer to put a cap on this
	limit-rate-up=1048576     # 1048576 kB/s == 1GB/s; a raise from default 2048 kB/s; contribute more to p2p network
	limit-rate-down=1048576   # 1048576 kB/s == 1GB/s; a raise from default 8192 kB/s; allow for faster initial sync
EOF

# Create Scripts
cd $TERMUX_SHORTCUTS

  cat << EOF > Start\ XMR\ Node\ FG
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
cp $TERMUX_SHORTCUTS/Start\ XMR\ Node $TERMUX_BOOT
termux-job-scheduler --job-id 1 -s $TERMUX_SCHEDULED/xmr_notifications --period-ms 900000
termux-job-scheduler --job-id 2 -s $TERMUX_SCHEDULED/Update\ XMR\ Node --period-ms 86400000
cd $MONERO_CLI
termux-toast -g middle "Started XMR Node..."
sleep 1
./monerod --config-file $NODE_CONFIG/config.txt

EOF

  cat << EOF > Start\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
cd $MONERO_CLI
./monerod --config-file $NODE_CONFIG/config.txt --detach
sleep 10

cp $TERMUX_SHORTCUTS/Start\ XMR\ Node $TERMUX_BOOT
termux-job-scheduler --job-id 1 -s $TERMUX_SCHEDULED/xmr_notifications --period-ms 900000
termux-job-scheduler --job-id 2 -s $TERMUX_SCHEDULED/Update\ XMR\ Node --period-ms 86400000
sleep 1
termux-toast -g middle "Started XMR Node..."
EOF

 cat << EOF > Stop\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
cd $MONERO_CLI
./monerod exit && tail --pid=\$(pidof monerod) -f /dev/null && echo 'Exited' 
rm -f $TERMUX_BOOT/Start\ XMR\ Node

termux-wake-unlock
termux-notification -i monero -c "🔴 XMR Node Offline" --priority low --alert-once
termux-job-scheduler --cancel --job-id 1
termux-job-scheduler --cancel --job-id 2
sleep 1
termux-toast -g middle "Stopped XMR Node"

EOF

 cat << EOF > XMR\ Node\ Status
#!/data/data/com.termux/files/usr/bin/sh
cd $MONERO_CLI
./monerod status
sleep 3
./monerod print_net_stats
sleep 5
cd $TERMUX_SCHEDULED
./xmr_notifications
EOF

 cat << "EOF" > xmr_notifications
#!/data/data/com.termux/files/usr/bin/sh
sleep 10
REQ=$(curl -s http://127.0.0.1:18081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H 'Content-Type: application/json')

if [ "$REQ" ]
then
	DATA=$(echo $REQ | jq '.result')
	DATE=$(echo "$DATA" | jq '.start_time' | jq -r 'todate' )
	VERSION=$(echo "$DATA" | jq -r '.version' )
	NODE_ONLINE=$(echo "$DATA" | jq -r 'if .offline == false then "🟢 XMR Node Online" else "🔴 XMR Node Offline" end')
	OUTGOING_CONNECTIONS=$(echo "$DATA" | jq '.outgoing_connections_count' )
	P2P_CONNECTIONS=$(echo "$DATA" | jq '.incoming_connections_count' )
	RPC_CONNECTIONS=$(echo "$DATA" | jq '.rpc_connections_count' )
	UPDATE_AVAILABLE=$(echo "$DATA" | jq -r 'if .update_available == true then "📬️ XMR Update Available" else "" end' )
	SYNC_STATUS=$(printf %.1f $(echo "$DATA" | jq '(.height / .target_height)*100'))
	STORAGE_REMAINING=$(printf %.1f $(echo "$DATA" | jq '.free_space * 0.000000001'))
	LOCAL_IP=$(echo $(termux-wifi-connectioninfo | jq '.ip') | tr -d '"')

	NOTIFICATION=$(printf '%s\n' "⛓️ XMR-$VERSION" "🕐️ Running Since: $DATE" "🔄 Sync Progress: $SYNC_STATUS %" "📤️ OUT: $OUTGOING_CONNECTIONS / 🌱 P2P: $P2P_CONNECTIONS / 📲 RPC: $RPC_CONNECTIONS" "💾 Free Space: $STORAGE_REMAINING GB" "🔌 Local IP: ${LOCAL_IP}:18089" "$UPDATE_AVAILABLE" )
else
	NODE_ONLINE="🔴 XMR Node Offline!"
	NOTIFICATION="RPC Error: Turn on your Node!"
fi
termux-notification -i monero -c "$NOTIFICATION"  -t "$NODE_ONLINE" --ongoing --priority low --alert-once
EOF


 cat << EOF > Update\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
func_xmrnode_install(){
	./Stop\ XMR\ Node && echo "Monero Node Stopped"
	cd
	wget -O monero.tar.bzip2 $MONERO_CLI_URL
	tar jxvf monero.tar.bzip2
	rm monero.tar.bzip2
	rm -rf $MONERO_CLI
	mv monero-a* $MONERO_CLI

        # Download Blocklist
	cd $NODE_CONFIG
	wget -O block.txt https://gui.xmr.pm/files/block.txt
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

REQ=\$(curl -s http://127.0.0.1:18081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H 'Content-Type: application/json')
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

	rm -f Start\ XMR\ Node*
	rm -f Stop\ XMR\ Node
	rm -f Update\ XMR\ Node
	rm -f XMR\ Node\ Status
	rm -rf $MONERO_CLI

	cd $TERMUX_SCHEDULED
	rm -f xmr_notifications
	rm -f Update\ XMR\ Node

	cd $TERMUX_SHORTCUTS

	RESP=\$(termux-dialog radio -t "Delete blockchain data?" -v "Yes,No" | jq '.index')

	#0 = Uninstall
	if [ \$RESP = 0 ]
	then
        echo "Deleting blockchain data"
	rm -rf $NODE_DATA
        fi


	RESP=\$(termux-dialog radio -t "Delete config file and uninstall script?" -v "Yes,No" | jq '.index')
	#0 = Uninstall
	if [ \$RESP = 0 ]
	then
        echo "Deleting config file"
	rm -rf $MONERO
	rm -rf Uninstall\ XMR\ Node
	fi
	exit 1
fi

EOF


# Finish Setting Up
chmod +x Start\ XMR\ Node*
chmod +x Stop\ XMR\ Node
chmod +x Update\ XMR\ Node
chmod +x XMR\ Node\ Status
chmod +x xmr_notifications
chmod +x Uninstall\ XMR\ Node 

cp Start\ XMR\ Node  $TERMUX_BOOT
mv xmr_notifications $TERMUX_SCHEDULED
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
./Start\ XMR\ Node

echo "I'm Done! 👍."
echo "..."
sleep 1
echo "But.."
sleep 1
echo "		A couple things for you to do:"
echo "1.  Add the Termux:Widget to your homescreen"
echo "2.  If you'd like the node to run automatically on boot"
echo "    make sure to install Termux:Boot from f-droid, and run it once."
echo "3.  To set a static IP to enable LAN access, go to:"
echo "    android settings > wifi > edit saved network > advanced > DHCP"
echo "    change from automatic to manual, and set the IP to:"
echo "    $(termux-wifi-connectioninfo | jq '.ip')"
echo "4.  To enable P2P seeding:"
echo "    Go to your router settings (usually 192.168.0.1 in your browser)"
echo "    Find 'Port Forwarding', then forward"
echo "    public/external port 18080 to internal/private port 18080,"
echo "    setting the internal ip to:"
echo "    $(termux-wifi-connectioninfo | jq '.ip')"
echo "4b. To enable Wallet access from WAN:"
echo "	  Also forward port 18089 to 18089 as well"
echo "5.  To make changes to the config file, use the command:"
echo "    nano $NODE_CONFIG/config.txt"
echo "         ☠️ Cheers ☠️ "
)
