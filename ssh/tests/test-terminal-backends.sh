#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
terminal_lib="${repo_root}/ssh/rootfs/usr/local/lib/terminal-config.sh"
terminal_shell="${repo_root}/ssh/rootfs/usr/local/bin/terminal-shell"
terminal_session="${repo_root}/ssh/rootfs/usr/local/bin/terminal-session"
zellij_web="${repo_root}/ssh/rootfs/usr/local/bin/zellij-web"
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
printf '%s|%s|%s\n' "$*" "$SHELL" "$APP_SELECTED_SHELL"
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
ZELLIJ_CONFIG_FILE=/custom/zellij.kdl
ZELLIJ_STATE_DIR=${tmp_dir}/zellij
XDG_CACHE_HOME=${tmp_dir}/zellij/cache
XDG_DATA_HOME=${tmp_dir}/zellij/data
EOF

output=$(TERMINAL_CONFIG_PATH="${tmp_dir}/terminal.conf" "${terminal_shell}")
assert_eq "-l|${tmp_dir}/bin/fake-shell|1" "${output}"

output=$(TERMINAL_CONFIG_PATH="${tmp_dir}/terminal.conf" \
    "${terminal_shell}" -c 'printf selected-shell')
assert_eq "-c printf selected-shell|${tmp_dir}/bin/fake-shell|1" "${output}"

output=$(PATH="${tmp_dir}/bin:${PATH}" \
    TERMINAL_CONFIG_PATH="${tmp_dir}/terminal.conf" "${terminal_session}")
assert_eq \
    '--config /custom/zellij.kdl attach --create homeassistant options --default-shell /custom/terminal-shell --mirror-session true --simplified-ui true --web-sharing on' \
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

# The native web configuration must be ingress-safe and keep ttyd out of the
# Zellij path.
INGRESS_ENTRY=/api/hassio_ingress/test-token \
INGRESS_IP=172.30.33.10 \
INGRESS_PORT=12345 \
SUPERVISOR_IP=172.30.32.2 \
TERMINAL_CONFIG_PATH="${tmp_dir}/terminal.conf" \
ZELLIJ_CONFIG_FILE_OVERRIDE="${tmp_dir}/zellij.kdl" \
NGINX_CONFIG_FILE="${tmp_dir}/nginx.conf" \
"${zellij_web}" --render-only

grep -Fq 'base_url "/api/hassio_ingress/test-token"' \
    "${tmp_dir}/zellij.kdl" || fail 'missing Zellij ingress base URL'
grep -Fq 'proxy_hide_header X-Frame-Options;' \
    "${tmp_dir}/nginx.conf" || fail 'Zellij iframe header is not removed'
grep -Fq 'proxy_cookie_path / /api/hassio_ingress/test-token/;' \
    "${tmp_dir}/nginx.conf" || fail 'Zellij cookie is not ingress-scoped'
grep -Fq 'listen 172.30.33.10:12345;' \
    "${tmp_dir}/nginx.conf" || fail 'ingress listener is not isolated'
grep -Fq 'allow 172.30.32.2;' \
    "${tmp_dir}/nginx.conf" || fail 'Supervisor allow-list is missing'

grep -Fq 'exec /usr/local/bin/zellij-web' \
    "${repo_root}/ssh/rootfs/etc/s6-overlay/s6-rc.d/ttyd/run" \
    || fail 'Zellij does not dispatch to its native web client'
grep -Fq 'exec ttyd' \
    "${repo_root}/ssh/rootfs/etc/s6-overlay/s6-rc.d/ttyd/run" \
    || fail 'tmux no longer dispatches to ttyd'
grep -Fq 'ARG ZELLIJ_VERSION="0.44.3"' \
    "${repo_root}/ssh/Dockerfile" \
    || fail 'web-capable Zellij version is not pinned'

# A non-interactive login shell must not be redirected into a multiplexer.
output=$(bash --noprofile --norc -c "source '${bash_profile}'; printf unaffected")
assert_eq unaffected "${output}"

bash -n \
    "${terminal_lib}" \
    "${repo_root}/ssh/rootfs/etc/s6-overlay/s6-rc.d/init-user/run" \
    "${repo_root}/ssh/rootfs/etc/s6-overlay/s6-rc.d/ttyd/run" \
    "${zellij_web}" \
    "${bash_profile}"
sh -n "${terminal_shell}" "${terminal_session}" "${ssh_login}"

echo 'All terminal backend tests passed.'
