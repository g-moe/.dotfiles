#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

. "$LIB_DIR/logging.sh"
. "$LIB_DIR/interactive.sh"
. "$LIB_DIR/utils.sh"

HOME_DIR="${HOME:-}"
SSH_DIR="$HOME_DIR/.ssh"
SSH_CONFIG="$SSH_DIR/config"

host_alias=''
host_name=''
remote_user=''
port='22'
key_path=''
pub_key_path=''

fail() {
  log_error "$1"
  exit 1
}

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
  [[ -n "$HOME_DIR" ]] || fail 'HOME is not set.'

  if [[ "$(id -u)" -eq 0 ]]; then
    fail 'Do not run this with sudo.'
  fi

  has_command ssh-keygen || fail 'ssh-keygen was not found.'

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

  host_alias="$(interactive_read 'SSH alias, like prod or homelab')"
  [[ -n "$host_alias" ]] || fail 'SSH alias is required.'
  [[ "$host_alias" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'Use only letters, numbers, dots, underscores, and dashes in the alias.'

  if host_exists "$host_alias"; then
    if ! interactive_confirm "Host '$host_alias' already exists. Overwrite it?" 'n'; then
      fail 'Host setup canceled.'
    fi

    remove_host_block
    log_info "Removed old Host $host_alias from $SSH_CONFIG"
  fi

  host_name="$(interactive_read 'Server hostname or IP')"
  [[ -n "$host_name" ]] || fail 'Server hostname or IP is required.'

  remote_user="$(interactive_read 'SSH user' "${USER:-}")"
  [[ -n "$remote_user" ]] || fail 'SSH user is required.'

  port="$(interactive_read 'SSH port' '22')"
  [[ "$port" =~ ^[0-9]+$ ]] || fail 'SSH port must be a number.'
}

read_key_details() {
  local choice default_key

  log_section 'Key'

  choice="$(interactive_select 'SSH key:' \
    'Skip' \
    'Generate a new key for this host' \
    'Use an existing key')"

  case "$choice" in
    0)
      log_info 'Skipped.'
      exit 0
      ;;
    1)
      default_key="$SSH_DIR/id_ed25519_$host_alias"
      key_path="$(expand_home "$(interactive_read 'Private key path' "$default_key")")"
      pub_key_path="$key_path.pub"

      if [[ -e "$key_path" || -e "$pub_key_path" ]]; then
        if ! interactive_confirm "Key already exists. Overwrite $key_path?" 'n'; then
          fail 'Key generation canceled.'
        fi

        rm -f "$key_path" "$pub_key_path"
      fi

      log_info 'Generating SSH key.'
      log_info 'ssh-keygen will ask whether you want a passphrase.'
      ssh-keygen -t ed25519 -f "$key_path" -C "$remote_user@$host_name ($host_alias)"
      chmod 600 "$key_path"
      chmod 644 "$pub_key_path"
      ;;
    2)
      key_path="$(expand_home "$(interactive_read 'Private key path' "$SSH_DIR/id_ed25519")")"
      pub_key_path="$key_path.pub"

      [[ -f "$key_path" ]] || fail "Private key not found: $key_path"
      chmod 600 "$key_path"

      if [[ ! -f "$pub_key_path" ]]; then
        log_info "Creating public key at $pub_key_path"
        ssh-keygen -y -f "$key_path" > "$pub_key_path"
        chmod 644 "$pub_key_path"
      fi
      ;;
  esac
}

copy_public_key() {
  log_section 'Public key'

  if has_command pbcopy; then
    pbcopy < "$pub_key_path"
    log_info 'Copied public key to clipboard.'
  else
    log_info "Public key file: $pub_key_path"
  fi

  log_info 'No key contents were printed.'
}

print_host_instructions() {
  log_section 'Host instructions'

  log_info "Connect to the host: ssh $remote_user@$host_name"
  if [[ "$port" != '22' ]]; then
    log_info "Use port $port if needed: ssh -p $port $remote_user@$host_name"
  fi

  log_info 'On the host, run:'
  printf '%s\n' \
    'mkdir -p ~/.ssh' \
    'chmod 700 ~/.ssh' \
    'touch ~/.ssh/authorized_keys' \
    'chmod 600 ~/.ssh/authorized_keys' \
    'cat >> ~/.ssh/authorized_keys' \
    '<paste clipboard contents here>' \
    '<press Ctrl-D>' >/dev/tty
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

  log_info "Added Host $host_alias to $SSH_CONFIG"
  log_info "Connect with: ssh $host_alias"
}

main() {
  run_step 'Checking SSH tools' ensure_ready
  read_host_details
  read_key_details
  copy_public_key
  print_host_instructions
  write_ssh_config
}

main "$@"
