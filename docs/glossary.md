# Glossary

Terms used in the code and in these docs. One term, one meaning. Where the code uses two names for one thing, both are given.

| Term | Meaning |
| --- | --- |
| **Blasted cell** (`BlastedCell`, client `ICell`) | One cell reached by a detonation: `{ row, col, type, destroyed, spoil, portal }`. Computed by the server in `Bomb.detonate()`. See [mechanics.md](mechanics.md#blast). |
| **Bomb queue** | The per-connection list of bombs waiting for their fuse, on the bomb owner's `Play` instance, checked every 100 ms. |
| **Box** | Destructible cell, tile id 5, `DESTRUCTIBLE_CELL`. Stops a blast and becomes empty. |
| **Chain reaction** | A blast that detonates another bomb (`detonate bomb by blast`). Intended. |
| **Delay** (fuse delay) | Time from bomb creation to detonation, per player on the server: 2000 ms, −200 ms per `DELAY` spoil, min 200 ms. |
| **Delay spoil** | The `DELAY` spoil type (3). In the drop pool only when the game has `isDelaySpoilEnabled`. |
| **Game** | Server class for one lobby slot and, after start, one match. Client side it is the `GameData` payload. |
| **Game room** | The socket.io room named with the game id. All per-game broadcasts go to it. |
| **Ghosting** (event ghosting) | One server event handled several times because old listeners were never removed. See [known-traps.md](known-traps.md#event-ghosting-from-a-listener-leak). |
| **Handshake auth** | The `auth` object of the socket.io connection: `socketId`, `email`, `name`, `picture`. See [socket-contract.md](socket-contract.md#handshake-auth). |
| **Layer info** (`layer_info`) | The first layer of the server's map JSON, kept on `Game`: tile data, size and the layer properties (`max_players`, `spawns`, `wall`, `box`). |
| **Lobby** / **lobby room** (`lobby_room`) | The menu list of pending games and the socket.io room that receives its updates. |
| **Pending game** | A `Game` in `pendingGames` (lobby or waiting room, before `start game`). |
| **Play instance** (`Play`, `client.playInstance`) | Per-connection server object with the gameplay handlers and the bomb queue. Released with `destroy()` on disconnect. |
| **Player id** / custom id (`client.customId`, `Player.id`, `socket_id`) | The stable UUID stored in browser localStorage under `socket_id` and sent in the handshake. Identifies a player everywhere in game state and is the key of `PlayStats.userId` and of the skin texture. Not the socket.io connection id. |
| **Portal** | A teleport cell. Appears when a blast hits one of the map's fixed portal cells (`*_PORTAL_SPAWNS`) and portals are enabled. |
| **Portal cell** / **portal spawn** | One of the fixed `(row, col)` cells in `SMALL_MAP_PORTAL_SPAWNS` / `DEFAULT_MAP_PORTAL_SPAWNS`. |
| **Power** | Blast range in cells from the bomb, per player on the server: 1, +1 per `POWER` spoil. |
| **`prevGameInfo`** | The finished `Game` with a `noKillPhrase` on each player without kills, sent with `player win` and `end game` and shown in the results modal (`EndGameModal`). |
| **Running game** | A `Game` in `runningGames` (between `start game` and `end game`). |
| **Shadow map** (`shadow_map`) | The server's grid of the map: wall 1, box 5, empty 6. The blast reads and changes it. |
| **Skin** (`Player.skin`) | The URL of a player's avatar image. Loaded as a Phaser texture with the player id as key. |
| **Spawn** | A player start position from the map's `spawns` layer property. The player appears one cell up and left of the listed `(row, col)` (see [maps.md](maps.md#layer-properties)). |
| **Spoil** | A power-up: `SPEED` 0, `POWER` 1, `BOMBS` 2, `DELAY` 3. See [mechanics.md](mechanics.md#spoils-power-ups). |
| **Tombstone** | The marker left where a player died: `{ row, col }` under a `tombId` on the server, a `Tombstone` sprite on the client. |
| **Top 3** | Flag that gives `POINTS_PER_TOP3` when a death leaves exactly 3 players alive. |
| **Wall** | Indestructible cell, tile id 1, `NON_DESTRUCTIBLE_CELL`. Stops a blast. |
