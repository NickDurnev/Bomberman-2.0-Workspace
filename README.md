# Bomberman workspace

Workspace repo for the multiplayer Bomberman game. It holds only docs and agent configuration. The game code lives in two submodules: `Bomberman-2.0` (frontend) and `Bomberman-2.0-Backend` (backend).

## Prerequisites

- Docker (with Docker Compose). Local MongoDB runs in a container on `127.0.0.1:27017`.
- Node 22 and npm.
- A Google OAuth client (web application) with `http://localhost:3000` as an authorised JavaScript origin. Login is Google only.
- `.env` files. Never commit them.
  - `Bomberman-2.0/.env`: copy `Bomberman-2.0/.env.example` and set `VITE_CLIENT_ID` to the OAuth client ID. `make frontend` sets `VITE_SERVER_BASE_URL` to the local backend.
  - `Bomberman-2.0-Backend/.env`: optional for local runs. `make backend` sets `DB_HOST` to the local MongoDB and leaves Cloudinary unset.

## Get started

```sh
git clone --recurse-submodules https://github.com/NickDurnev/Bomberman-2.0-Workspace.git
cd Bomberman-2.0-Workspace
make setup   # init submodules, install deps, build backend dist
make dev     # MongoDB, backend on :4000, frontend on :3000
```

Run `make help` to list the available commands. Start at [docs/README.md](docs/README.md) for the architecture.
