# shellcheck shell=bash
# Interactive shell selection and session sharing are configured at startup.
# Non-interactive login shells must never be redirected into a multiplexer.
if [[ $- == *i* ]] \
    && [[ -z "${APP_SELECTED_SHELL:-}" ]] \
    && [[ -z "${TMUX:-}" ]] \
    && [[ -z "${ZELLIJ:-}" ]] \
    && [[ -r /etc/terminal-session.conf ]]; then
    # shellcheck disable=SC1091
    source /etc/terminal-session.conf

    if [[ "${TERMINAL_SHARE_SESSIONS}" == 'true' ]]; then
        exec /usr/local/bin/terminal-session
    else
        exec /usr/local/bin/terminal-shell
    fi
fi
