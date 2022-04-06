# Matrix autosetup

Just a tiny script to quickly setup a [Matrix.org](https://matrix.org/) server, for bot development purpose.

## Requirements

```bash
sudo dnf install -y podman jq
```

## Usage

```bash
bash matrix-autosetup.sh
```

It will :

- spawn the matrix server and element-web interface
- register two users (`admin:admin` and `bot:bot`)
- create a private room (`#botroom`) with these two users
- activate e2e encryption in this room

You will then be able to login on [http://localhost:8080/#/login](http://localhost:8080/#/login)

## Doc

[https://spec.matrix.org/latest/client-server-api/](https://spec.matrix.org/latest/client-server-api/)
