# Backend tests

The backend (`Bomberman-2.0-Backend`) has a Vitest suite. The frontend has no tests.

## What the suite covers

- `test/unit/`: single classes (`Bomb`, `Player`, `Spoil`). No server, no socket.
- `test/integration/`: a real server in the test process and real socket.io clients. Tests cover the HTTP routes, the handshake, the lobby, movement, bombs, spoils, win conditions and disconnects.

Tests check the behaviour that [mechanics.md](mechanics.md), [socket-contract.md](socket-contract.md) and [entities.md](entities.md) describe.

## Run the tests

Run these in `Bomberman-2.0-Backend/`:

| Command | Action |
| --- | --- |
| `npm test` | `vitest run`. Must exit 0. |
| `npm run test:watch` | Vitest in watch mode. |
| `npm run typecheck` | `tsc --noEmit`. It also checks `test/`, through `tsconfig.test.json`. |

`make ci` in the workspace root runs `npm test` in the backend, between `typecheck` and `build`. The `checks` CI job runs the same steps.

## Setup

- `vitest.config.ts` maps every `tsconfig.json` path alias (`@entity`, `@constants`, ...) to `src/`, never to `dist/`.
- `test/setup/global.ts` runs before each test file. It sets `DB_HOST` to a closed-port placeholder and sets the Cloudinary variables to `""`.
- Never use `.env`. Tests use only `mongodb-memory-server`.
- Tests never import `src/app.ts`. `startTestServer()` builds the server from `src/db` and `src/server`.

## Helpers

`test/helpers/server.ts`:

- `startTestServer(): Promise<TestServer>`. It starts an in-memory MongoDB and sets the `DB_HOST` URI. Then it imports `src` and listens on a random port. `TestServer` is `{ url, io, stop() }`. Start one server per test file. Call `stop()` in `afterAll`.

`test/helpers/players.ts`:

- `uniqueName(prefix?): string`. A name that no other test uses. Games and players live in module-level maps, so tests must not share names.
- `createUser(url, { name, email }): Promise<void>`. Calls `POST /api/v1/auth`, as the client does after sign-in.
- `connectPlayer(url, { name, email, socketId? }): Promise<TestPlayer>`. Connects with the handshake `auth`. `TestPlayer` is `{ socket, id, name, email }`.
- `waitFor<T>(socket, event, timeoutMs = 3000): Promise<T>`. Resolves with the first argument of the next `event`.
- `expectNoEvent(socket, event, ms = 500): Promise<void>`. Rejects if the event arrives.
- `emitAck<T>(socket, event, ...args): Promise<T>`. Emits and resolves with the acknowledgement.
- `startTwoPlayerGame(url, opts?)`. Drives two players to a running game. It returns `{ p1, p2, gameId, game }`. `opts` is `mapName`, `isPortalsEnabled`, `isDelaySpoilEnabled`.
- `disconnectAllPlayers()`. `stop()` calls it.

## Example

```ts
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { startTwoPlayerGame, waitFor } from "../helpers/players";
import { TestServer, startTestServer } from "../helpers/server";

describe("example", () => {
  let server: TestServer;

  beforeAll(async () => {
    server = await startTestServer();
  });

  afterAll(async () => {
    await server?.stop();
  });

  it("sends a bomb to both players", async () => {
    const { p1, p2, gameId } = await startTwoPlayerGame(server.url);
    const seen = waitFor<{ playerId: string }>(p2.socket, "show bomb");
    p1.socket.emit("create bomb", { playerId: p1.id, gameId, col: 1, row: 1 });
    expect((await seen).playerId).toBe(p1.id);
  });
});
```

## Rules

- **Emails.** The HTTP route checks the email with Joi `.email()`. Use `@example.com`. A `.local` address gets `422`.
- **Handshake write.** The server does not await the `storeSocketID` database write in the handshake. If a test needs the `User` `socketID` (database fallback, stats), poll the database until it is set. Never rely on timing.
- **Randomness.** The server runs in the test process. `vi.spyOn(Math, "random")` controls the spoil roll and the spoil type. Restore the spy after the test.
- **Spoils.** Take spoils only from cells with `destroyed: true` (a broken box). Do not assert spoils on empty cells or walls.
- **Time.** Use real time, never fake timers. The bomb fuse is `INITIAL_DELAY` (2000 ms). `end game` arrives about 5 s after a win. Give every wait a timeout that names the event.
- **End a match through deaths.** Never wait for the 180 s timer.
- **Disconnects.** A disconnect from a running 2-player game ends the match (`end game`). `player disconnect` needs 3 or more players.
- **Own events.** The sender of `update player position` also receives its own `move player`.
- **Unknown game.** The `get current game` acknowledgement for an unknown game arrives as `null`.

## Where a new test goes

- Logic in one class, no socket: `test/unit/<class>.test.ts`.
- An event, a route or a flow between players: `test/integration/<area>.test.ts`. Use one file for each area. Each file starts its own server.
- A change to backend game logic, a socket event or an HTTP route adds or updates a test in the same PR.
