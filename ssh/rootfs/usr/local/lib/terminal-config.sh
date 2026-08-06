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
