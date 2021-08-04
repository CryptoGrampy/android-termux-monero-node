#!/data/data/com.termux/files/usr/bin/sh

(
MONERO_CLI=~/monero-cli
NODE_DATA=~/storage/external-1/bitmonero
TERMUX_BOOT=~/.termux/boot
TERMUX_SHORTCUTS=~/.shortcuts
TERMUX_SCHEDULED=~/termux-scheduled

# Setup

termux-setup-storage
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
EOF

 cat << EOF > Stop\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
cd $MONERO_CLI
./monerod exit && tail --pid=$(pidof monerod) -f /dev/null && echo 'Exited' 
rm -f $TERMUX_BOOT/Start\ XMR\ Node

termux-wake-unlock
termux-notification -i monero -c "🔴 XMR Node Offline" --priority low --alert-once
termux-job-scheduler --cancel --job-id 1

sleep 5
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
./Stop\ XMR\ Node && echo "Monero Node Stopped"
cd
wget -O monero.tar.bzip2 https://downloads.getmonero.org/cli/androidarm8
tar jxvf monero.tar.bzip2
rm monero.tar.bzip2
rm -rf $MONERO_CLI
mv monero-a* $MONERO_CLI
cd $TERMUX_SHORTCUTS
./Start\ XMR\ Node
EOF

chmod +x Start\ XMR\ Node
chmod +x Stop\ XMR\ Node
chmod +x Update\ XMR\ Node
chmod +x xmr_notifications

cp Start\ XMR\ Node $TERMUX_BOOT
mv xmr_notifications $TERMUX_SCHEDULED

# Start

cd $TERMUX_SHORTCUTS
./Update\ XMR\ Node

echo "Done! 👍"
)