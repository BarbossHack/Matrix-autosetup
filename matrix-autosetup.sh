#!/bin/bash

set -e
set -u

# Config
MATRIX_NAME=matrix.world
SYNAPSE_VOLUME=./volumes/synapse-data
ADMIN_TOKEN_FILE=./volumes/admin_token
ROOM_ID_FILE=./volumes/room_id

# Clean
rm -f $ADMIN_TOKEN_FILE $ROOM_ID_FILE
podman unshare rm -rf $SYNAPSE_VOLUME
mkdir -p $SYNAPSE_VOLUME
podman rm -f synapse || true
podman rm -f element-web || true

# Generate Matrix conf
podman run -it --rm \
    -v $SYNAPSE_VOLUME:/data:Z \
    -e SYNAPSE_SERVER_NAME=$MATRIX_NAME \
    -e SYNAPSE_REPORT_STATS=no \
    docker.io/matrixdotorg/synapse:latest generate

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
curl -s -XPOST -d '{"type":"m.login.password", "user":"admin", "password":"admin"}' "http://localhost:8008/_matrix/client/v3/login" |
    jq -r '.access_token' >$ADMIN_TOKEN_FILE

# Create a new room
curl -s -H "Authorization: Bearer $(cat $ADMIN_TOKEN_FILE)" -XPOST -d '{"name": "Bot Room", "preset": "private_chat", "room_alias_name": "botroom", "room_version": "9", "invite": ["@bot:'$MATRIX_NAME'"]}' "http://localhost:8008/_matrix/client/v3/createRoom" |
    jq -r '.room_id' >$ROOM_ID_FILE

# Enable encryption in room
curl -s -H "Authorization: Bearer $(cat $ADMIN_TOKEN_FILE)" -XPUT -d '{"algorithm": "m.megolm.v1.aes-sha2"}' "http://localhost:8008/_matrix/client/v3/rooms/$(cat $ROOM_ID_FILE)/state/m.room.encryption/" >/dev/null

# Spawn Element-Web instance
podman run -d --name element-web -p 127.0.0.1:8080:80 -v ./volumes/element-web.json:/app/config.json:Z docker.io/vectorim/element-web
echo -e "\e[42;30m[+]\e[0;32m http://localhost:8080/#/room/#botroom:$MATRIX_NAME\e[0m"
