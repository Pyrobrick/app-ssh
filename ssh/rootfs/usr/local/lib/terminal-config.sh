#!/bin/bash
# shellcheck shell=bash

terminal::shell_name() {
    if bashio::config.has_value 'shell'; then
        bashio::config 'shell'
    elif bashio::config.true 'zsh'; then
        echo 'zsh'
    else
        echo 'bash'
    fi
}

terminal::shell_path() {
    case "$1" in
        fish)
            echo '/usr/bin/fish'
            ;;
        zsh)
            echo '/bin/zsh'
            ;;
        bash)
            echo '/bin/bash'
            ;;
        *)
            bashio::exit.nok "Unsupported shell: $1"
            ;;
    esac
}

terminal::session_backend() {
    local backend

    if bashio::config.has_value 'session_backend'; then
        backend=$(bashio::config 'session_backend')
    else
        backend='tmux'
    fi

    case "${backend}" in
        zellij|tmux)
            echo "${backend}"
            ;;
        *)
            bashio::exit.nok "Unsupported session backend: ${backend}"
            ;;
    esac
}

terminal::set_root_account_shell() {
    local passwd_file

    if (( $# == 0 )); then
        bashio::exit.nok 'No passwd files supplied'
        return 1
    fi

    for passwd_file in "$@"; do
        sed -i -r -e \
            's|^(root:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:).*|\1/bin/bash|' \
            "${passwd_file}" \
            || bashio::exit.nok 'Failed setting the root account shell'
    done
}
