#!/bin/bash

set -e
set -u

# Config
MATRIX_NAME=matrix.bot
SYNAPSE_VOLUME=./synapse-data

# Clean
podman unshare rm -rf $SYNAPSE_VOLUME
mkdir -p $SYNAPSE_VOLUME
podman rm -f synapse || true
podman rm -f element-web || true

# Pull images
podman pull docker.io/matrixdotorg/synapse:latest
podman pull docker.io/vectorim/element-web:latest

# Generate Matrix conf
podman run -it --rm \
    -v $SYNAPSE_VOLUME:/data:Z \
    -e SYNAPSE_SERVER_NAME=$MATRIX_NAME \
    -e SYNAPSE_REPORT_STATS=no \
    docker.io/matrixdotorg/synapse:latest generate
podman unshare sed -i "/- port: 8008/a \ \ \ \ bind_addresses: ['0.0.0.0']" $SYNAPSE_VOLUME/homeserver.yaml

# Spawn the Matrix server
podman run -d --name synapse \
    -v $SYNAPSE_VOLUME:/data:Z \
    -p 127.0.0.1:8008:8008 \
    docker.io/matrixdotorg/synapse:latest

# Create admin and bot users
while true; do
    echo -n "."
    podman exec -it synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u admin -p admin -a 2>&1 >/dev/null && break
    sleep 1
done
podman exec -it synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u bot -p bot --no-admin

# Retrieve admin token to create a new room
ADMIN_TOKEN=$(curl -s -XPOST -d '{"type":"m.login.password", "user":"admin", "password":"admin"}' "http://localhost:8008/_matrix/client/v3/login" |
    jq -r '.access_token')
if [ -z $ADMIN_TOKEN ]; then
    echo -e "\e[41mFailed to get admin access_token\e[0m"
    exit 1
fi

# Create a new room
ROOM_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" -XPOST -d '{"name": "Bot Room", "preset": "private_chat", "room_alias_name": "botroom", "room_version": "9", "invite": ["@bot:'$MATRIX_NAME'"]}' "http://localhost:8008/_matrix/client/v3/createRoom" |
    jq -r '.room_id')
if [ -z $ROOM_ID ]; then
    echo -e "\e[41mFailed to create room\e[0m"
    exit 1
fi

# Let bot user join the room
BOT_TOKEN=$(curl -s -XPOST -d '{"type":"m.login.password", "user":"bot", "password":"bot"}' "http://localhost:8008/_matrix/client/v3/login" |
    jq -r '.access_token')
if [ -z $BOT_TOKEN ]; then
    echo -e "\e[41mFailed to get bot access_token\e[0m"
    exit 1
fi
curl -s -H "Authorization: Bearer $BOT_TOKEN" -XPUT -d '{"reason": "Im a bot"}' "http://localhost:8008/_matrix/client/v3/rooms/$ROOM_ID/join/" >/dev/null

# Enable encryption in room
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" -XPUT -d '{"algorithm": "m.megolm.v1.aes-sha2"}' "http://localhost:8008/_matrix/client/v3/rooms/$ROOM_ID/state/m.room.encryption/" >/dev/null

# Spawn Element-Web instance
podman run -d --name element-web -p 127.0.0.1:8080:80 --entrypoint sh docker.io/vectorim/element-web:latest -c "sed -i 's/listen  \[::\]:80;//g' /etc/nginx/conf.d/default.conf && /docker-entrypoint.sh && nginx -g 'daemon off;'"
podman exec -it element-web sed -i 's|"base_url": "https://matrix-client.matrix.org",|"base_url": "http://localhost:8008",|g' /app/config.json
podman exec -it element-web sed -i 's|"server_name": "matrix.org"|"server_name": "'$MATRIX_NAME'"|g' /app/config.json
podman exec -it element-web sed -i 's|"base_url": "https://vector.im"||g' /app/config.json
podman exec -it element-web sed -i 's|"default_theme": "light",|"default_theme": "dark",|g' /app/config.json
podman restart element-web

echo -e "\e[42;30m[+]\e[0;32m http://localhost:8080/#/room/$ROOM_ID\e[0m"
echo -e "\e[42;30m[+]\e[0;32m Room ID: $ROOM_ID\e[0m"
