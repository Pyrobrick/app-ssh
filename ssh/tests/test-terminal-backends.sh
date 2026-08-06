#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
terminal_lib="${repo_root}/ssh/rootfs/usr/local/lib/terminal-config.sh"
terminal_shell="${repo_root}/ssh/rootfs/usr/local/bin/terminal-shell"
terminal_session="${repo_root}/ssh/rootfs/usr/local/bin/terminal-session"
ssh_login="${repo_root}/ssh/rootfs/usr/local/bin/ssh-login"
bash_profile="${repo_root}/ssh/rootfs/root/.bash_profile"
declare -A config=()

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_eq() {
    local expected=$1
    local actual=$2

    [[ "${actual}" == "${expected}" ]] \
        || fail "expected '${expected}', got '${actual}'"
}

bashio::config.has_value() {
    [[ -n "${config[$1]+set}" && -n "${config[$1]}" ]]
}

bashio::config.true() {
    [[ "${config[$1]-}" == 'true' ]]
}

bashio::config() {
    printf '%s\n' "${config[$1]}"
}

bashio::exit.nok() {
    echo "$*" >&2
    return 1
}

# shellcheck disable=SC1090
source "${terminal_lib}"

# Existing installations retain their zsh/tmux or bash/tmux behaviour.
config=([zsh]=true)
assert_eq zsh "$(terminal::shell_name)"
assert_eq tmux "$(terminal::session_backend)"

config=([zsh]=false)
assert_eq bash "$(terminal::shell_name)"
assert_eq tmux "$(terminal::session_backend)"

# New selectors override the legacy zsh switch only when explicitly configured.
config=([zsh]=true [shell]=fish [session_backend]=zellij)
assert_eq fish "$(terminal::shell_name)"
assert_eq /usr/bin/fish "$(terminal::shell_path fish)"
assert_eq zellij "$(terminal::session_backend)"

config=([zsh]=false [shell]=zsh [session_backend]=tmux)
assert_eq zsh "$(terminal::shell_name)"
assert_eq /bin/zsh "$(terminal::shell_path zsh)"
assert_eq tmux "$(terminal::session_backend)"

if terminal::shell_path invalid; then
    fail 'invalid shell was accepted'
fi
config=([session_backend]=invalid)
if terminal::session_backend; then
    fail 'invalid session backend was accepted'
fi

tmp_dir=$(mktemp -d)
trap 'rm -r -- "${tmp_dir}"' EXIT
mkdir -p "${tmp_dir}/bin"

cat > "${tmp_dir}/bin/fake-shell" <<'EOF'
#!/bin/sh
printf '%s|%s|%s\n' "$1" "$SHELL" "$APP_SELECTED_SHELL"
EOF

cat > "${tmp_dir}/bin/zellij" <<'EOF'
#!/bin/sh
printf '%s\n' "$*"
EOF

cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/bin/sh
printf '%s\n' "$*"
EOF

cat > "${tmp_dir}/bin/sudo" <<'EOF'
#!/bin/sh
set -eu

case "${1:-}" in
    -H)
        shift
        exec "$@"
        ;;
    -i)
        printf '%s\n' "$*"
        ;;
    *)
        echo "unexpected sudo arguments: $*" >&2
        exit 64
        ;;
esac
EOF

chmod +x "${tmp_dir}/bin/"*

cat > "${tmp_dir}/terminal.conf" <<EOF
TERMINAL_SHELL_NAME=fish
TERMINAL_SHELL_PATH=${tmp_dir}/bin/fake-shell
TERMINAL_SESSION_BACKEND=zellij
TERMINAL_SHARE_SESSIONS=true
TERMINAL_SHELL_COMMAND=/custom/terminal-shell
EOF

output=$(TERMINAL_CONFIG_PATH="${tmp_dir}/terminal.conf" "${terminal_shell}")
assert_eq "-l|${tmp_dir}/bin/fake-shell|1" "${output}"

output=$(PATH="${tmp_dir}/bin:${PATH}" \
    TERMINAL_CONFIG_PATH="${tmp_dir}/terminal.conf" "${terminal_session}")
assert_eq \
    'attach --create homeassistant options --default-shell /custom/terminal-shell --mirror-session true --simplified-ui true' \
    "${output}"

sed -i 's/TERMINAL_SESSION_BACKEND=zellij/TERMINAL_SESSION_BACKEND=tmux/' \
    "${tmp_dir}/terminal.conf"
output=$(PATH="${tmp_dir}/bin:${PATH}" \
    TERMINAL_CONFIG_PATH="${tmp_dir}/terminal.conf" "${terminal_session}")
assert_eq '-u new -A -s homeassistant /custom/terminal-shell' "${output}"

output=$(PATH="${tmp_dir}/bin:${PATH}" "${ssh_login}" -c \
    'printf "%s" "quoted command value"')
assert_eq 'quoted command value' "${output}"

set +e
PATH="${tmp_dir}/bin:${PATH}" "${ssh_login}" -c 'exit 23'
command_status=$?
set -e
assert_eq 23 "${command_status}"

output=$(PATH="${tmp_dir}/bin:${PATH}" "${ssh_login}")
assert_eq '-i' "${output}"

cat > "${tmp_dir}/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/ash
daemon:x:2:2:daemon:/sbin:/sbin/nologin
EOF
terminal::set_root_account_shell "${tmp_dir}/passwd"
assert_eq 'root:x:0:0:root:/root:/bin/bash' \
    "$(sed -n '1p' "${tmp_dir}/passwd")"
assert_eq 'daemon:x:2:2:daemon:/sbin:/sbin/nologin' \
    "$(sed -n '2p' "${tmp_dir}/passwd")"

# A non-interactive login shell must not be redirected into a multiplexer.
output=$(bash --noprofile --norc -c "source '${bash_profile}'; printf unaffected")
assert_eq unaffected "${output}"

bash -n \
    "${terminal_lib}" \
    "${repo_root}/ssh/rootfs/etc/s6-overlay/s6-rc.d/init-user/run" \
    "${repo_root}/ssh/rootfs/etc/s6-overlay/s6-rc.d/ttyd/run" \
    "${bash_profile}"
sh -n "${terminal_shell}" "${terminal_session}" "${ssh_login}"

echo 'All terminal backend tests passed.'
