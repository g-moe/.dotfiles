#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"

. "$LIB_DIR/lib.sh"

HOME_DIR="${HOME:-}"
SSH_DIR="$HOME_DIR/.ssh"
SSH_CONFIG="$SSH_DIR/config"

host_alias=''
host_name=''
remote_user=''
port='22'
key_path=''
pub_key_path=''

expand_home() {
  local path="$1"

  case "$path" in
    '~')
      printf '%s\n' "$HOME_DIR"
      ;;
    '~/'*)
      printf '%s\n' "$HOME_DIR/${path#~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

ensure_ready() {
  [[ -n "$HOME_DIR" ]] || die 'HOME is not set.'

  if [[ "$(id -u)" -eq 0 ]]; then
    die 'Do not run this with sudo.'
  fi

  has ssh-keygen || die 'ssh-keygen was not found.'

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
}

host_exists() {
  awk 'tolower($1)=="host" {for (i=2; i<=NF; i++) print $i}' "$SSH_CONFIG" | grep -Fxq "$1"
}

remove_host_block() {
  local tmp_config
  tmp_config="$(mktemp)"

  awk -v target="$host_alias" '
    function flush_block() {
      if (block != "" && !drop_block) {
        printf "%s", block
      }
      block = ""
      drop_block = 0
    }

    tolower($1) == "host" {
      flush_block()
      block = $0 ORS
      for (i = 2; i <= NF; i++) {
        if ($i == target) {
          drop_block = 1
        }
      }
      next
    }

    tolower($1) == "match" {
      flush_block()
      print
      next
    }

    block != "" {
      block = block $0 ORS
      next
    }

    {
      print
    }

    END {
      flush_block()
    }
  ' "$SSH_CONFIG" > "$tmp_config"

  cat "$tmp_config" > "$SSH_CONFIG"
  rm -f "$tmp_config"
}

read_host_details() {
  log_section 'Host'

  host_alias="$(read_value 'SSH alias, like prod or homelab')"
  [[ -n "$host_alias" ]] || die 'SSH alias is required.'
  [[ "$host_alias" =~ ^[A-Za-z0-9._-]+$ ]] || die 'Use only letters, numbers, dots, underscores, and dashes in the alias.'

  if host_exists "$host_alias"; then
    if ! ask_binary "Host '$host_alias' already exists. Overwrite it?" 'n'; then
      die 'Host setup canceled.'
    fi

    remove_host_block
    log "Removed old Host $host_alias from $SSH_CONFIG"
  fi

  host_name="$(read_value 'Server hostname or IP')"
  [[ -n "$host_name" ]] || die 'Server hostname or IP is required.'

  remote_user="$(read_value 'SSH user' "${USER:-}")"
  [[ -n "$remote_user" ]] || die 'SSH user is required.'

  port="$(read_value 'SSH port' '22')"
  [[ "$port" =~ ^[0-9]+$ ]] || die 'SSH port must be a number.'
}

read_key_details() {
  local choice default_key

  log_section 'Key'

  choice="$(ask_choice 'SSH key:' \
    'Skip' \
    'Generate a new key for this host' \
    'Use an existing key')"

  case "$choice" in
    0)
      log 'Skipped.'
      exit 0
      ;;
    1)
      default_key="$SSH_DIR/id_ed25519_$host_alias"
      key_path="$(expand_home "$(read_value 'Private key path' "$default_key")")"
      pub_key_path="$key_path.pub"

      if [[ -e "$key_path" || -e "$pub_key_path" ]]; then
        if ! ask_binary "Key already exists. Overwrite $key_path?" 'n'; then
          die 'Key generation canceled.'
        fi

        rm -f "$key_path" "$pub_key_path"
      fi

      log 'Generating SSH key.'
      log 'ssh-keygen will ask whether you want a passphrase.'
      ssh-keygen -t ed25519 -f "$key_path" -C "$remote_user@$host_name ($host_alias)"
      chmod 600 "$key_path"
      chmod 644 "$pub_key_path"
      ;;
    2)
      key_path="$(expand_home "$(read_value 'Private key path' "$SSH_DIR/id_ed25519")")"
      pub_key_path="$key_path.pub"

      [[ -f "$key_path" ]] || die "Private key not found: $key_path"
      chmod 600 "$key_path"

      if [[ ! -f "$pub_key_path" ]]; then
        log "Creating public key at $pub_key_path"
        ssh-keygen -y -f "$key_path" > "$pub_key_path"
        chmod 644 "$pub_key_path"
      fi
      ;;
  esac
}

copy_host_commands() {
  local copy_tool="$SCRIPT_DIR/shared-copy-to-clipboard.sh"
  local host_commands public_key

  log_section 'Host setup commands'

  IFS= read -r public_key < "$pub_key_path"
  [[ -n "$public_key" ]] || die "Public key is empty: $pub_key_path"

  host_commands="$(cat <<EOF
mkdir -p "\$HOME/.ssh"
chmod 700 "\$HOME/.ssh"
touch "\$HOME/.ssh/authorized_keys"
chmod 600 "\$HOME/.ssh/authorized_keys"
cat >> "\$HOME/.ssh/authorized_keys" <<'SSH_PUBLIC_KEY'
$public_key
SSH_PUBLIC_KEY
EOF
)"

  if [[ -x "$copy_tool" ]] && printf '%s\n' "$host_commands" | "$copy_tool"; then
    log 'Copied ssh host setup commands to clipboard.'
  else
    log "Public key file: $pub_key_path"
  fi
}

print_host_instructions() {
  log_section 'Host instructions'

  log "Connect to the host: ssh $remote_user@$host_name"
  if [[ "$port" != '22' ]]; then
    log "Use port $port if needed: ssh -p $port $remote_user@$host_name"
  fi

  log 'On the host, paste and run the commands from your clipboard.'
}

write_ssh_config() {
  log_section 'SSH config'

  cat >> "$SSH_CONFIG" <<EOF

Host $host_alias
  HostName $host_name
  User $remote_user
EOF

  if [[ "$port" != '22' ]]; then
    cat >> "$SSH_CONFIG" <<EOF
  Port $port
EOF
  fi

  cat >> "$SSH_CONFIG" <<EOF
  IdentityFile $key_path
  IdentitiesOnly yes
EOF

  log "Added Host $host_alias to $SSH_CONFIG"
  log "Connect with: ssh $host_alias"
}

main() {
  run_step 'Checking SSH tools' ensure_ready
  read_host_details
  read_key_details
  copy_host_commands
  print_host_instructions
  write_ssh_config
}

main "$@"
