# Microton Docker Compose Deployment

This stack keeps the deployment small by default: PostgreSQL, Redis, web,
streaming, and Sidekiq. Elasticsearch is available only through the `search`
profile, and media uses local Docker volume storage unless S3 is explicitly
enabled.

## 1. Create the environment file

```sh
cp .env.example .env
```

Edit `.env` before starting anything:

- Set `LOCAL_DOMAIN` to the final public domain. Do not change it later.
- Fill `DB_PASS`, `SECRET_KEY_BASE`, all three
  `ACTIVE_RECORD_ENCRYPTION_*` values, `VAPID_PRIVATE_KEY`, and
  `VAPID_PUBLIC_KEY`.
- Set SMTP values to a real mail provider before accepting users.

Useful local secret commands:

```sh
openssl rand -hex 32   # DB_PASS or each ACTIVE_RECORD_ENCRYPTION_* value
openssl rand -hex 64   # SECRET_KEY_BASE
```

Build once, then generate VAPID keys from the built image:

```sh
docker compose build web streaming
docker run --rm microton-web:latest bundle exec ruby -rwebpush -e 'key = Webpush.generate_key; puts "VAPID_PRIVATE_KEY=#{key.private_key}"; puts "VAPID_PUBLIC_KEY=#{key.public_key}"'
```

Copy the printed VAPID values into `.env`.

## 2. Prepare the database

```sh
docker compose --profile setup run --rm setup
```

## 3. Start Microton

```sh
docker compose up -d
docker compose ps
```

By default, web is exposed on `127.0.0.1:3000` and streaming on
`127.0.0.1:4000`. Put a reverse proxy in front of those ports and terminate TLS
there.

## 4. Create the first owner account

```sh
docker compose run --rm web bin/tootctl accounts create admin --email admin@example.com --confirmed --approve --role Owner
```

The command prints the generated password.

## Optional Search

Enable Elasticsearch only when full-text search is needed:

```sh
ES_ENABLED=true docker compose --profile search up -d
```

Persist `ES_ENABLED=true` in `.env` if search should stay enabled across
restarts.
