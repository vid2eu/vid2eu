#!/bin/sh
# Interactive configuration for the vid2eu Docker stack. Needs only a POSIX shell and Docker.
#
#   sh scripts/setup.sh              walk through every setting, write .env, offer to start
#   sh scripts/setup.sh --yes        accept defaults (and keep existing values) without asking
#   sh scripts/setup.sh --start      start the stack afterwards without asking
#   sh scripts/setup.sh --no-start   never start it
#   sh scripts/setup.sh --file deploy/prod.env   (write somewhere other than .env)
#
# With the service repos cloned next to it (see DEPLOY.md) the images are built from
# source; otherwise the prebuilt ones are pulled from GHCR. Outside a checkout it doubles
# as the installer: run it in an empty directory, and it downloads docker-compose.yml
# and pulls the images, no source needed:
#
#   mkdir vid2eu && cd vid2eu && sh -c "$(curl -fsSL https://raw.githubusercontent.com/vid2eu/vid2eu/main/scripts/setup.sh)"
#
# Re-running is safe: current values become the defaults, and secrets are kept unless
# you choose to replace them.

set -eu

COMPOSE_URL=${VID2EU_COMPOSE_URL:-https://raw.githubusercontent.com/vid2eu/vid2eu/main/docker-compose.yml}
DEFAULT_IMAGE=${VID2EU_IMAGE:-ghcr.io/vid2eu/vid2eu}

if [ -t 1 ]; then
  esc=$(printf '\033')
  BOLD="$esc[1m" DIM="$esc[2m" VIOLET="$esc[35m" GREEN="$esc[32m" YELLOW="$esc[33m" RESET="$esc[0m"
else
  BOLD='' DIM='' VIOLET='' GREEN='' YELLOW='' RESET=''
fi

say() { printf '%s\n' "$*"; }
die() { say "${YELLOW}!${RESET} $*" >&2; exit 1; }
section() { printf '\n%s\n' "$VIOLET$BOLD▍$1$RESET"; }

usage() {
  cat <<'EOF'
Usage: sh scripts/setup.sh [--yes] [--start | --no-start] [--file path]

  --yes, -y     accept defaults (and keep existing values) without asking
  --start       start the stack afterwards without asking
  --no-start    never start it
  --file path   write a different env file (passed to compose with --env-file)
EOF
}

AUTO=0 START='' ENV_ARG=''
while [ $# -gt 0 ]; do
  case $1 in
    -y | --yes) AUTO=1 ;;
    --start) START=yes ;;
    --no-start) START=no ;;
    --file)
      [ $# -ge 2 ] || die '--file needs a path'
      ENV_ARG=$2
      shift
      ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
  shift
done

ROOT=$(pwd)
if [ -f "$0" ] && [ -f "$(dirname "$0")/../docker-compose.yml" ]; then
  ROOT=$(cd "$(dirname "$0")/.." && pwd)
fi
BUILD=0
if [ -f "$ROOT/docker-compose.override.yml" ] && [ -f "$ROOT/vid2eu-api/Dockerfile" ]; then BUILD=1; fi

case ${ENV_ARG:-.env} in
  /*) ENV_FILE=${ENV_ARG} ;;
  *) ENV_FILE=$ROOT/${ENV_ARG:-.env} ;;
esac

if [ "$AUTO" = 0 ] && ! (: </dev/tty) 2>/dev/null; then AUTO=1; fi

CR=$(printf '\r')
CUR_KEYS=' '

trim() {
  eval "_t=\$$1"
  _t=${_t#"${_t%%[! 	]*}"}
  _t=${_t%"${_t##*[! 	]}"}
  eval "$1=\$_t"
}

read_env() {
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%"$CR"}
    case $line in *=*) ;; *) continue ;; esac
    key=${line%%=*} value=${line#*=}
    trim key
    trim value
    case $key in '' | *[!A-Z0-9_]*) continue ;; esac
    case $value in
      \'?*\') value=${value#\'} value=${value%\'} ;;
      \"?*\") value=${value#\"} value=${value%\"} value=$(printf '%s' "$value" | sed 's/\\\(["\\$]\)/\1/g') ;;
    esac
    eval "cur_$key=\$value"
    case $CUR_KEYS in *" $key "*) ;; *) CUR_KEYS="$CUR_KEYS$key " ;; esac
  done <"$1"
}

get() { eval "printf '%s' \"\${cur_$1-\$2}\""; }
has() { eval "[ -n \"\${cur_$1+x}\" ]"; }

quote() {
  case $1 in
    *[!A-Za-z0-9_./:@,+-]*) ;;
    *) printf '%s' "$1"; return ;;
  esac
  case $1 in
    *\'*) printf '"%s"' "$(printf '%s' "$1" | sed 's/["\\$]/\\&/g')" ;;
    *) printf "'%s'" "$1" ;;
  esac
}

read_tty() {
  IFS= read -r "$1" </dev/tty || { printf '\n'; say 'Cancelled; nothing was written.'; exit 130; }
}

ask() { _secret=0; _ask "$@"; }
ask_secret() { _secret=1; _ask "$@"; }
_ask() {
  _var=$1 _label=$2 _def=$3 _check=${4:-} _help=${5:-}
  if [ "$AUTO" = 1 ]; then
    eval "$_var=\$_def"
    return 0
  fi
  if [ -n "$_help" ]; then say "$DIM  $_help$RESET"; fi
  while :; do
    if [ -z "$_def" ]; then _shown=''
    elif [ "$_secret" = 1 ]; then _shown=" $DIM[keep current]$RESET"
    else _shown=" $DIM[$_def]$RESET"; fi
    printf '  %s%s: ' "$_label" "$_shown"
    read_tty _answer
    trim _answer
    [ -n "$_answer" ] || _answer=$_def
    _error=''
    if [ -n "$_check" ]; then _error=$("$_check" "$_answer"); fi
    if [ -z "$_error" ]; then
      eval "$_var=\$_answer"
      return 0
    fi
    say "$YELLOW  ✗ $_error$RESET"
  done
}

confirm() {
  if [ "$AUTO" = 1 ]; then [ "$2" = y ]; return; fi
  if [ "$2" = y ]; then _hint='[Y/n]'; else _hint='[y/N]'; fi
  printf '  %s %s: ' "$1" "$DIM$_hint$RESET"
  read_tty _answer
  trim _answer
  case $_answer in
    '') [ "$2" = y ] ;;
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

matches() { printf '%s\n' "$1" | grep -Eq "$2"; }

is_port() {
  case $1 in '' | *[!0-9]* | ??????*) say 'Enter a port between 1 and 65535'; return 0 ;; esac
  if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then say 'Enter a port between 1 and 65535'; fi
}
is_positive() {
  awk -v v="$1" 'BEGIN { exit !(v ~ /^[0-9]*\.?[0-9]+$/ && v + 0 > 0) }' || say 'Enter a number above 0'
}
is_url() {
  if ! matches "$1" '^[A-Za-z][A-Za-z0-9+.-]*://'; then say 'Enter a full URL, e.g. https://vid2.eu'
  elif ! matches "$1" '^[Hh][Tt][Tt][Pp][Ss]?://'; then say 'Use http:// or https://'
  elif ! matches "$1" '^[^:]+://[^/?#[:space:]]+/?$'; then say 'Give only the origin, e.g. https://vid2.eu'
  fi
}
is_ident() { matches "$1" '^[A-Za-z_][A-Za-z0-9_]{0,62}$' || say 'Letters, numbers and underscores only'; }
is_username() { matches "$1" '^[a-z0-9._-]{2,32}$' || say '2-32 lowercase letters, numbers, dots, dashes or underscores'; }
is_bind() {
  matches "$1" '^([0-9]{1,3}\.){3}[0-9]{1,3}$|^\[?[0-9a-fA-F:]+\]?$' || say 'Enter an IP address, e.g. 0.0.0.0 or 127.0.0.1'
}
is_volume() { matches "$1" '[^[:space:]]' || say 'Enter a volume name or a host path'; }
is_major() { matches "$1" '^[0-9]+$' || say 'Enter a major version, e.g. 18'; }
is_project() { matches "$1" '^[a-z0-9][a-z0-9_-]*$' || say 'Lowercase letters, numbers, - and _'; }
is_image() { matches "$1" '^[a-z0-9][a-z0-9._/:-]*$' || say 'Enter an image prefix, e.g. ghcr.io/you/vid2eu'; }
is_tag() { matches "$1" '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$' || say 'Enter a tag, e.g. latest or 1.4.0'; }
is_bool_or_empty() { case $1 in '' | true | false) ;; *) say 'Enter true, false or leave empty' ;; esac; }
is_choice2() { case $1 in 1 | 2) ;; *) say 'Pick 1-2' ;; esac; }

secret() { od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'; }
password() { LC_ALL=C tr -dc 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789' </dev/urandom | head -c 16; }
cpu_count() { getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1; }

COMPOSE=''
if docker compose version >/dev/null 2>&1; then COMPOSE='docker compose'
elif docker-compose version >/dev/null 2>&1; then COMPOSE='docker-compose'; fi

compose() {
  if [ -n "$ENV_ARG" ]; then (cd "$ROOT" && $COMPOSE --env-file "$ENV_FILE" "$@")
  else (cd "$ROOT" && $COMPOSE "$@"); fi
}
compose_text() { printf '%s' "${COMPOSE:-docker compose}${ENV_ARG:+ --env-file $ENV_FILE} $*"; }

download() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else die 'Neither curl nor wget is installed.'; fi
}

trap 'printf "\n"; say "Cancelled; nothing was written."; exit 130' INT

if [ ! -f "$ROOT/docker-compose.yml" ]; then
  [ -n "$COMPOSE_URL" ] || die "No docker-compose.yml in $ROOT. Run this inside a vid2eu checkout, or set VID2EU_COMPOSE_URL to where docker-compose.yml is published."
  say "Downloading docker-compose.yml from $COMPOSE_URL"
  download "$COMPOSE_URL" "$ROOT/docker-compose.yml.part" || die 'Download failed.'
  mv "$ROOT/docker-compose.yml.part" "$ROOT/docker-compose.yml"
fi

read_env "$ENV_FILE"
FIRST_RUN=0
[ "$CUR_KEYS" = ' ' ] && FIRST_RUN=1

printf '\n%s production setup %s\n' "${BOLD}vid2eu$RESET" "$DIM→ $ENV_FILE$RESET"
if [ "$FIRST_RUN" = 1 ]; then say "${DIM}Press Enter to accept the value in brackets.$RESET"
else say "${DIM}Existing values are the defaults; secrets are kept unless you replace them.$RESET"; fi

if [ "$BUILD" = 1 ]; then
  say "${DIM}Service repos found next to this checkout: the images are built here, not pulled.$RESET"
else
  section 'Images'
  ask new_VID2EU_IMAGE 'Registry and name of the vid2eu images' "$(get VID2EU_IMAGE "$DEFAULT_IMAGE")" is_image \
    'e.g. ghcr.io/you/vid2eu pulls ghcr.io/you/vid2eu-api, -web, -storage, -transcoder and -migrate.'
  [ -n "$new_VID2EU_IMAGE" ] || die 'Set VID2EU_IMAGE to where the vid2eu images are published, e.g. VID2EU_IMAGE=ghcr.io/you/vid2eu'
  ask new_VID2EU_TAG 'Version to run' "$(get VID2EU_TAG latest)" is_tag
fi

section 'Site'
ask new_PUBLIC_URL 'Public URL visitors use' "$(get PUBLIC_URL http://localhost:8080)" is_url \
  'Used in share links, embeds and link previews. Behind a TLS reverse proxy, use the https:// address.'
new_PUBLIC_URL=${new_PUBLIC_URL%/}
ask new_WEB_HOST_PORT 'Port to publish the site on' "$(get WEB_HOST_PORT 8080)" is_port
ask new_WEB_BIND 'Address to bind it to' "$(get WEB_BIND 0.0.0.0)" is_bind \
  '0.0.0.0 = reachable from the network. 127.0.0.1 = only this machine (when a reverse proxy runs here).'

section 'First administrator'
say "$DIM  Created on first start only, while no admin exists. They must choose a new password at first sign-in.$RESET"
ask new_ADMIN_USERNAME 'Username' "$(get ADMIN_USERNAME admin)" is_username
ask new_ADMIN_NAME 'Display name' "$(get ADMIN_NAME Administrator)"
if [ -n "$(get ADMIN_PASSWORD '')" ]; then
  ask_secret new_ADMIN_PASSWORD 'Initial password' "$(get ADMIN_PASSWORD '')"
else
  ask new_ADMIN_PASSWORD 'Initial password' "$(password)" '' 'A random one is suggested; it is shown again at the end.'
fi
ask new_ADMIN_STORAGE_GB 'Their storage limit (GB)' "$(get ADMIN_STORAGE_GB 20)" is_positive

section 'Video storage'
current_storage=$(get STORAGE_DATA storage-data)
if [ "$current_storage" = storage-data ]; then storage_choice=1; else storage_choice=2; fi
if [ "$AUTO" = 0 ]; then
  if [ "$storage_choice" = 1 ]; then mark1=" $DIM(current)$RESET" mark2=''; else mark1='' mark2=" $DIM(current)$RESET"; fi
  say "    1) Docker named volume (managed by Docker)$mark1"
  say "    2) A directory on this machine$mark2"
fi
ask storage_choice 'Where should videos be stored' "$storage_choice" is_choice2
if [ "$storage_choice" = 1 ]; then
  new_STORAGE_DATA=storage-data
else
  if [ "$current_storage" = storage-data ]; then storage_default=$ROOT/data/storage; else storage_default=$current_storage; fi
  ask new_STORAGE_DATA 'Host directory' "$storage_default" is_volume \
    'Must be writable by uid 1000 (the containers run as the "node" user).'
fi
ask new_MAX_UPLOAD_SIZE_GB 'Largest single upload (GB)' "$(get MAX_UPLOAD_SIZE_GB 10)" is_positive
cpus=$(cpu_count)
suggested_concurrency=$((cpus / 4))
[ "$suggested_concurrency" -ge 1 ] || suggested_concurrency=1
[ "$suggested_concurrency" -le 2 ] || suggested_concurrency=2
ask new_TRANSCODER_CONCURRENCY 'Videos to transcode at the same time' "$(get TRANSCODER_CONCURRENCY "$suggested_concurrency")" is_positive \
  'Each job runs ffmpeg on every core; 1 is right for most servers.'

section 'Database'
ask new_POSTGRES_USER 'Postgres user' "$(get POSTGRES_USER vid2eu)" is_ident
ask new_POSTGRES_DB 'Postgres database' "$(get POSTGRES_DB vid2eu)" is_ident
if has POSTGRES_PASSWORD; then
  new_POSTGRES_PASSWORD=$(get POSTGRES_PASSWORD '')
  say "$DIM  Postgres password: keeping the current one (changing it here would not change an existing database).$RESET"
else
  new_POSTGRES_PASSWORD=$(secret 24)
  say "$DIM  Postgres password: generated.$RESET"
fi

section 'Security'
if [ -n "$(get JWT_SECRET '')" ] && ! confirm 'Replace the JWT secret? (signs everyone out)' n; then
  new_JWT_SECRET=$(get JWT_SECRET '')
else
  new_JWT_SECRET=$(secret 48)
  say "$DIM  JWT secret: generated.$RESET"
fi

advanced=0
if confirm 'Customize advanced settings (API exposure, internal ports, proxies)?' n; then advanced=1; fi

adv() {
  if [ "$advanced" = 1 ]; then ask "new_$1" "$2" "$(get "$1" "$3")" "${4:-}" "${5:-}"
  else eval "new_$1=\$(get \"\$1\" \"\$3\")"; fi
}

if [ "$advanced" = 1 ]; then section 'Advanced'; fi
adv API_BIND 'Address to publish the API on' 127.0.0.1 is_bind \
  'The site reaches the API internally. Publish it on 0.0.0.0 only if it needs its own domain.'
adv API_HOST_PORT 'Port to publish the API on' 3000 is_port
adv WEB_PORT 'Web port inside its container' 8080 is_port
adv API_PORT 'API port inside its container' 3000 is_port
adv STORAGE_PORT 'Storage API port inside its container' 3001 is_port
adv TRANSCODER_PORT 'Transcoder port inside its container' 3002 is_port
adv TRUST_PROXY 'Trust X-Forwarded-* headers from' true '' \
  '"true" when the API is only reached through the web server or your reverse proxy.'
adv COOKIE_SECURE 'Force the Secure cookie flag (true/false, empty = automatic)' '' is_bool_or_empty
adv POSTGRES_DATA 'Postgres data volume or host directory' postgres-data is_volume
adv POSTGRES_VERSION 'Postgres major version' 18 is_major
if [ "$BUILD" = 1 ]; then
  adv VID2EU_IMAGE 'Name prefix for the built images' vid2eu is_image
  adv VID2EU_TAG 'Tag for the built images' latest is_tag
  adv NODE_VERSION 'Node.js major version for the images' 26 is_major
else
  new_NODE_VERSION=$(get NODE_VERSION 26)
fi
adv COMPOSE_PROJECT_NAME 'Compose project name' vid2eu is_project

warnings=''
warn() { warnings="$warnings$1
"; }
url_scheme=$(printf '%s' "${new_PUBLIC_URL%%://*}" | tr 'A-Z' 'a-z')
url_host=${new_PUBLIC_URL#*://}
url_host=${url_host%%/*}
case $url_host in \[*) url_host=${url_host%%]*}] ;; *) url_host=${url_host%%:*} ;; esac
if [ "$url_scheme" = http ] && [ "$url_host" != localhost ] && [ "$url_host" != 127.0.0.1 ]; then
  warn 'PUBLIC_URL is plain http. Put a TLS reverse proxy in front for anything public; sign-in cookies and passwords travel unencrypted otherwise.'
fi
if [ "$url_scheme" = https ] && [ "$new_WEB_BIND" = 0.0.0.0 ]; then
  warn "With an https PUBLIC_URL, a reverse proxy usually terminates TLS. Consider WEB_BIND=127.0.0.1 so port $new_WEB_HOST_PORT isn't reachable directly."
fi
current_admin_password=$(get ADMIN_PASSWORD '')
if [ "$FIRST_RUN" = 0 ] && [ -n "$current_admin_password" ] && [ "$current_admin_password" != "$new_ADMIN_PASSWORD" ]; then
  warn 'ADMIN_PASSWORD only applies when the first admin is created; it does not change an existing account.'
fi
if [ "$new_API_BIND" != 127.0.0.1 ] && [ "$new_WEB_HOST_PORT" = "$new_API_HOST_PORT" ]; then
  warn 'The site and the API are published on the same host port.'
fi

KNOWN=' '
write_group() {
  printf '\n# %s\n' "$1"
  shift
  for key in "$@"; do
    eval "val=\${new_$key-}"
    printf '%s=%s\n' "$key" "$(quote "$val")"
    KNOWN="$KNOWN$key "
  done
}

(umask 077 && : >"$ENV_FILE.part") || die "Cannot write $ENV_FILE"
{
  printf '# vid2eu Docker configuration, written by scripts/setup.sh on %s.\n' "$(date +%Y-%m-%d)"
  printf '# Re-run the script to change it, or edit by hand. Contains secrets: keep it private.\n'
  write_group 'Images (pulled from a registry, or built from a source checkout)' VID2EU_IMAGE VID2EU_TAG
  write_group 'Site' PUBLIC_URL WEB_HOST_PORT WEB_BIND
  write_group 'First administrator (created on first start, must change password at first sign-in)' \
    ADMIN_USERNAME ADMIN_NAME ADMIN_PASSWORD ADMIN_STORAGE_GB
  write_group 'Video storage and processing' STORAGE_DATA MAX_UPLOAD_SIZE_GB TRANSCODER_CONCURRENCY
  write_group 'Database (changing the password here does not change an existing database)' \
    POSTGRES_USER POSTGRES_DB POSTGRES_PASSWORD POSTGRES_DATA POSTGRES_VERSION
  write_group 'Security' JWT_SECRET TRUST_PROXY COOKIE_SECURE
  write_group 'Ports' API_BIND API_HOST_PORT WEB_PORT API_PORT STORAGE_PORT TRANSCODER_PORT NODE_VERSION COMPOSE_PROJECT_NAME
  extra=''
  for key in $CUR_KEYS; do
    case $KNOWN in *" $key "*) ;; *) extra="$extra $key" ;; esac
  done
  if [ -n "$extra" ]; then
    printf '\n# Other settings (kept from the previous file)\n'
    for key in $extra; do printf '%s=%s\n' "$key" "$(quote "$(get "$key" '')")"; done
  fi
} >"$ENV_FILE.part"
mv "$ENV_FILE.part" "$ENV_FILE"
chmod 600 "$ENV_FILE" 2>/dev/null || true
trap - INT

printf '\n%s Wrote %s\n' "$GREEN✓$RESET" "$ENV_FILE"
printf '%s' "$warnings" | while IFS= read -r line; do say "$YELLOW!$RESET $line"; done

if [ "$BUILD" = 1 ]; then command_text=$(compose_text up -d --build) start_label='Build and start the stack now?'
else command_text="$(compose_text pull) && $(compose_text up -d)" start_label='Download and start the stack now?'; fi
started=0

if [ -z "$COMPOSE" ]; then
  printf '\n%s Docker Compose was not found. Install Docker, then run:\n  %s\n' "$YELLOW!$RESET" "$BOLD$command_text$RESET"
elif [ "$START" != no ] && { [ "$START" = yes ] || { [ "$AUTO" = 0 ] && printf '\n' && confirm "$start_label" y; }; }; then
  printf '\n%s\n\n' "$DIM\$ $command_text$RESET"
  status=0
  if [ "$BUILD" = 1 ]; then compose up -d --build || status=$?
  else compose pull && compose up -d || status=$?; fi
  if [ "$status" = 0 ]; then started=1
  else printf '\n%s Compose exited with status %s. Fix the error above and run:\n  %s\n' "$YELLOW!$RESET" "$status" "$BOLD$command_text$RESET"; fi
else
  printf '\nStart it with:\n  %s\n' "$BOLD$command_text$RESET"
fi

if [ "$started" = 1 ]; then printf '\n%s\n' "${BOLD}vid2eu is starting$RESET"; else printf '\n%s\n' "${BOLD}Next$RESET"; fi
say "  Site          $new_PUBLIC_URL  $DIM(published on $new_WEB_BIND:$new_WEB_HOST_PORT)$RESET"
say "  Sign in as    $new_ADMIN_USERNAME / $new_ADMIN_PASSWORD  $DIM(first start only; you will pick a new password)$RESET"
say "  Logs          $DIM$(compose_text logs -f)$RESET"
say "  Status        $DIM$(compose_text ps)$RESET"
