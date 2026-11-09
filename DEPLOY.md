# Deploying vid2eu

The whole stack runs from one `docker-compose.yml`: Postgres, a one-shot migration job,
the API, the storage API, the transcoder (with ffmpeg) and the web server. Everything is
configured through a single `.env` at the repo root.

The host needs only Docker with Compose and a POSIX shell (any Linux or macOS). Node is not
needed outside the containers.

## Quick start

On the server, in an empty directory:

```sh
mkdir vid2eu && cd vid2eu
sh -c "$(curl -fsSL https://raw.githubusercontent.com/vid2eu/vid2eu/main/scripts/setup.sh)"
```

The script downloads `docker-compose.yml`, asks for each setting, writes `.env`, then pulls
and starts the images from `ghcr.io/vid2eu/vid2eu-{api,storage,transcoder,web,migrate}`.
`sh scripts/setup.sh` does the same from a clone of this repo. To install a fork, set
`VID2EU_COMPOSE_URL` and `VID2EU_IMAGE` (the image prefix, e.g. `ghcr.io/you/vid2eu`).

Then open `PUBLIC_URL` and sign in with the admin username and password the script printed.
You'll be asked to choose your own password straight away.

Re-running the script is safe. Your current values become the defaults, and it keeps the
Postgres password and JWT secret unless you choose to replace them.

| Flag | Effect |
| --- | --- |
| `--yes` | accept defaults / current values without asking |
| `--start` / `--no-start` | start the stack afterwards, or don't ask |
| `--file path` | write a different env file (pass it to compose with `--env-file`) |

## What runs where

| Service | Published | Purpose |
| --- | --- | --- |
| `web` | `WEB_BIND:WEB_HOST_PORT` (default `0.0.0.0:8080`) | site, share/embed pages, proxies `/api` and uploads |
| `api` | `API_BIND:API_HOST_PORT` (default `127.0.0.1:3000`) | auth, users, videos |
| `storage` | internal only | uploads, streaming, file deletion |
| `transcoder` | internal only | ffmpeg jobs (`TRANSCODER_CONCURRENCY`) |
| `postgres` | internal only | data in the `POSTGRES_DATA` volume |
| `migrate` | internal only | applies `packages/db/drizzle`, then exits |

Visitors only need the web server. Publish the API on a public address only if you want it
on its own domain.

## HTTPS

Put a TLS reverse proxy in front of the web port and set `PUBLIC_URL` to the `https://`
address. With Caddy on the same host, for example:

```
vid2.eu {
    reverse_proxy 127.0.0.1:8080
}
```

In that case set `WEB_BIND=127.0.0.1`, so port 8080 isn't reachable around the proxy. Raise
the proxy's request body limit and timeouts to fit `MAX_UPLOAD_SIZE_GB`. Sign-in cookies
get the `Secure` flag automatically when the visitor came in over https (`COOKIE_SECURE`
can force it either way).

## Operating it

```sh
docker compose ps                 # health of every service
docker compose logs -f api        # follow one service
docker compose pull && docker compose up -d   # update; migrations run before the services start
docker compose down               # stop (volumes are kept)
```

Back up two things: the Postgres volume, for example with
`docker compose exec postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backup.sql`, and
the storage volume or directory (`STORAGE_DATA`).

## Repositories and images

| Repo | Image (`ghcr.io/vid2eu/…`) | Contents |
| --- | --- | --- |
| [vid2eu](https://github.com/vid2eu/vid2eu) | `vid2eu-migrate` | `packages/db` (schema, client, migrations), compose file, setup script |
| [vid2eu-api](https://github.com/vid2eu/vid2eu-api) | `vid2eu-api` | auth, users, videos |
| [vid2eu-storage](https://github.com/vid2eu/vid2eu-storage) | `vid2eu-storage` | uploads, streaming |
| [vid2eu-transcoder](https://github.com/vid2eu/vid2eu-transcoder) | `vid2eu-transcoder` | ffmpeg jobs |
| [vid2eu-web](https://github.com/vid2eu/vid2eu-web) | `vid2eu-web` | site and web server |

Every repo has the same `image` workflow: a push to `main` publishes `:latest` and
`:sha-<commit>`, and a tag `v1.2.3` publishes `:1.2.3` and `:1.2`, each for x86 and ARM.
`VID2EU_TAG` in `.env` picks the tag servers run (default `latest`); the five repos are
versioned independently, so pin a tag only after tagging every repo with it.

The api, storage and transcoder repos take `@vid2eu/db` from this repo through a `core`
submodule, so each service builds against the schema commit it pins. After changing the
schema here, push it, then bump the submodule in each service that needs it:

```sh
git submodule update --remote core && git commit -am "Update core" && git push
```

The migrate image always comes from this repo's `main`, so keep migrations additive: a
service still pinned to an older schema must keep working after they run.

## Moving an existing install into Docker

Video asset paths are now stored relative to the storage root. Rows written by older
versions hold absolute paths such as `X:/vid2eu/data/storage/...`. Before moving:

```sh
# against the old database, with the old root
node packages/db/scripts/rebase-object-keys.ts X:/vid2eu/data/storage --dry-run
node packages/db/scripts/rebase-object-keys.ts X:/vid2eu/data/storage
```

Then restore the database dump into the new Postgres. Copy the storage directory into the
storage volume, or point `STORAGE_DATA` at it. On Linux, make it writable by uid 1000.

## Local development

Clone the service repos inside a clone of this one (they're git-ignored here):

```sh
git clone https://github.com/vid2eu/vid2eu && cd vid2eu
for r in api storage transcoder web; do git clone --recurse-submodules https://github.com/vid2eu/vid2eu-$r; done
npm install && npm run db:migrate        # this repo: the db package and migrations
```

Then run `npm install` and `npm run dev` in each service, each with its own `.env` as before.
The defaults (`localhost:5432`, first admin `storm` / `123`) apply whenever the new variables
aren't set. Services use the schema in their own `core` submodule, not `packages/db` here.

With the service repos in place, `sh scripts/setup.sh` and `docker compose up -d --build`
build the images from this source (through `docker-compose.override.yml`) instead of
pulling them.
