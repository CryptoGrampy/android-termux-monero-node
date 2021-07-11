(
CLI=~/monero-cli
DATA=~/storage/external-1/bitmonero
BOOT=~/.termux/boot
SHRT=~/.shortcuts
SCHD=~/termux-scheduled

# Setup

termux-setup-storage
termux-wake-lock -y
pkg update -y
pkg install wget termux-api jq -y

# Dirs

mkdir -p $CLI
mkdir -p $DATA
mkdir -p $BOOT
mkdir -p $SHRT 
mkdir -p $SCHD 

# Scripts

cd $SHRT

  cat << EOF > Start\ XMR\ Node 
#!/data/data/com.termux/files/usr/bin/sh
cd $CLI
./monerod --data-dir $DATA --db-sync-mode safe:sync --enable-dns-blocklist --in-peers 10 --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --rpc-bind-ip 127.0.0.1 --rpc-bind-port 18081 --no-igd --no-zmq --detach
sleep 10
termux-job-scheduler --job-id 1 -s $SCHD/xmr_notifications --period-ms 900000
EOF

 cat << EOF > Stop\ XMR\ Node
#!/data/data/com.termux/files/usr/bin/sh
cd $CLI
./monerod exit && tail --pid=$(pidof monerod) -f /dev/null && echo 'Exited' 
sleep 5
EOF

 cat << EOF > XMR\ Node\ Status
#!/data/data/com.termux/files/usr/bin/sh
cd $CLI
./monerod status
sleep 10
cd $SCHD
./xmr_notifications
EOF

 cat << "EOF" > xmr_notifications
REQ=$(curl -s http://127.0.0.1:18081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H 'Content-Type: application/json')

if [ "$REQ" ]
then
DATA=$(echo $REQ | jq '.result')
DATE=$(echo "$DATA" | jq '.start_time' | jq -r 'todate' )
VER=$(echo "$DATA" | jq -r '.version' )
ON=$(echo "$DATA" | jq -r 'if .offline == false then "🟢 XMR Node Online" else "🔴 XMR Node Offline" end')
OUT=$(echo "$DATA" | jq '.outgoing_connections_count' )
P2P=$(echo "$DATA" | jq '.incoming_connections_count' )
RPC=$(echo "$DATA" | jq '.rpc_connections_count' )
UP=$(echo "$DATA" | jq -r 'if .update_available == true then "📬️ XMR Update Available" else "" end' )
SYNC=$(printf %.1f $(echo "$DATA" | jq '(.height / .target_height)*100'))
STOR=$(printf %.1f $(echo "$DATA" | jq '.free_space * 0.000000001'))

NOTIF=$(printf '%s\n' "⛓️ XMR-$VER" "🕐️ Running Since: $DATE" "🔄 Sync Progress: $SYNC %" "📤️ OUT: $OUT / 🌱 P2P: $P2P / 📲 RPC: $RPC" "💾 Free Space: $STOR GB" "$UP")
else
ON="🔴 XMR Node Offline"
NOTIF="RPC Error: Turn on your Node!"
fi
termux-notification -i monero -c "$NOTIF"  -t "$ON" --ongoing --priority low --alert-once
EOF

 cat << EOF > $BOOT/before_start_monero_node
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
EOF

  cat << EOF > Update\ XMR\ Node 
#!/data/data/com.termux/files/usr/bin/sh
./Stop\ XMR\ Node && echo "Monero Node Stopped"
cd
wget -O monero.tar.bzip2 https://downloads.getmonero.org/cli/androidarm8
tar jxvf monero.tar.bzip2
rm monero.tar.bzip2
rm -rf $CLI
mv monero-a* $CLI
cd $SHRT
./Start\ XMR\ Node
EOF

chmod +x Start\ XMR\ Node
chmod +x Stop\ XMR\ Node
chmod +x Update\ XMR\ Node
chmod +x xmr_notifications

cp Start\ XMR\ Node $BOOT
mv xmr_notifications $SCHD

# Start

cd $SHRT
./Update\ XMR\ Node

echo "Done! 👍"
)