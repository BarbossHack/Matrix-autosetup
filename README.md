# Matrix autosetup

Just a tiny script to quickly setup a Matrix server, for bot development purpose.

## Requirements

```bash
sudo dnf install -y podman jq
```

## Usage

```bash
bash matrix-autosetup.sh
```

It will :

- create the matrix server and element-web interface
- register two users (`admin:admin` and `bot:bot`)
- create a room (`#botroom`) with these two users
- activate e2e encryption in this room

You can then login on [http://localhost:8080/#/login](http://localhost:8080/#/login)

## Doc

[https://spec.matrix.org/latest/client-server-api/](https://spec.matrix.org/latest/client-server-api/)
