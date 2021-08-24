#!/data/data/com.termux/files/usr/bin/sh

(
MONERO_CLI=~/monero-cli
NODE_DATA=~/storage/external-1/bitmonero
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

# Setup

termux-setup-storage

RESP=$(termux-dialog confirm -t "XMR Node" -i \
"This script will install the latest Monero Node software on your device.

Make sure you have these apps installed (via F-Droid) before proceeding:

 	- Termux Boot
	- Termux Widget

Are you ready to continue?" | jq '.text')
if [ "$RESP" = '"no"' ]
then
	exit 1
fi

termux-wake-lock -y
pkg update -y
pkg install wget termux-api jq -y

# Cleanup

rm -f $TERMUX_BOOT/before_start_monero_node

# Dirs

mkdir -p $MONERO_CLI
mkdir -p $NODE_DATA
mkdir -p $TERMUX_BOOT
mkdir -p $TERMUX_SHORTCUTS 
mkdir -p $TERMUX_SCHEDULED 

# Scripts

cd $TERMUX_SHORTCUTS

  cat << EOF > Start\ XMR\ Node 
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
cd $MONERO_CLI
./monerod --data-dir $NODE_DATA --db-sync-mode safe:sync --enable-dns-blocklist --in-peers 10 --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --rpc-bind-ip 127.0.0.1 --rpc-bind-port 18081 --no-igd --no-zmq --detach
sleep 10

cp $TERMUX_SHORTCUTS/Start\ XMR\ Node $TERMUX_BOOT
termux-job-scheduler --job-id 1 -s $TERMUX_SCHEDULED/xmr_notifications --period-ms 900000
termux-job-scheduler --job-id 2 -s $TERMUX_SCHEDULED/Update\ XMR\ Node --period-ms 86400000

termux-toast -g "Started XMR Node..."
EOF

 cat << EOF > Stop\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
cd $MONERO_CLI
./monerod exit && tail --pid=$(pidof monerod) -f /dev/null && echo 'Exited' 
rm -f $TERMUX_BOOT/Start\ XMR\ Node

termux-wake-unlock
termux-notification -i monero -c "🔴 XMR Node Offline" --priority low --alert-once
termux-job-scheduler --cancel --job-id 1
termux-job-scheduler --cancel --job-id 2

termux-toast -g bottom "Stopped XMR Node"

EOF

 cat << EOF > XMR\ Node\ Status
#!/data/data/com.termux/files/usr/bin/sh
cd $MONERO_CLI
./monerod status
sleep 10
cd $TERMUX_SCHEDULED
./xmr_notifications
EOF

 cat << "EOF" > xmr_notifications
#!/data/data/com.termux/files/usr/bin/sh

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

NOTIFICATION=$(printf '%s\n' "⛓️ XMR-$VERSION" "🕐️ Running Since: $DATE" "🔄 Sync Progress: $SYNC_STATUS %" "📤️ OUT: $OUTGOING_CONNECTIONS / 🌱 P2P: $P2P_CONNECTIONS / 📲 RPC: $RPC_CONNECTIONS" "💾 Free Space: $STORAGE_REMAINING GB" "$UPDATE_AVAILABLE")
else
NODE_ONLINE="🔴 XMR Node Offline"
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
	cd $TERMUX_SHORTCUTS
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
		termux-toast -g bottom "No updates available. Current version is the latest: \$VERSION"
	fi
else
  exit 1
fi

EOF

 cat << EOF > Uninstall\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
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

	cd $HOME/termux-scheduled
	rm -f xmr_notifications
	rm -f Update\ XMR\ Node

	cd $HOME/.shortcuts
	RESP=\$(termux-dialog radio -t "Delete blockchain data?" -v "Yes,No" | jq '.index')

	#1 = Uninstall

	if [ \$RESP == 1 ]
	then
		rm -rf $NODE_DATA
	fi
	rm -rf Uninstall\ XMR\ Node
	exit 1
fi
EOF

chmod +x Start\ XMR\ Node
chmod +x Stop\ XMR\ Node
chmod +x Update\ XMR\ Node
chmod +x XMR\ Node\ Status
chmod +x xmr_notifications
chmod +x Uninstall\ XMR\ Node 

cp Start\ XMR\ Node $TERMUX_BOOT
mv xmr_notifications $TERMUX_SCHEDULED
cp Update\ XMR\ Node $TERMUX_SCHEDULED

# Start

cd $TERMUX_SHORTCUTS
./Stop\ XMR\ Node && echo "Monero Node Stopped"
cd 
wget -O monero.tar.bzip2 $MONERO_CLI_URL
tar jxvf monero.tar.bzip2
rm monero.tar.bzip2
rm -rf $MONERO_CLI
mv monero-a* $MONERO_CLI
cd $TERMUX_SHORTCUTS
./Start\ XMR\ Node

echo "Done! 👍"
)
