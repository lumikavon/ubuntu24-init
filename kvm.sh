#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KVM_DIR="$SCRIPT_DIR/kvm/ubuntu"

get_yq() {
    if command -v yq >/dev/null 2>&1; then
        echo "yq"
        return 0
    fi

    local bundled_yq="$SCRIPT_DIR/assets/tools/yq_linux_amd64"
    if [[ -x "$bundled_yq" ]]; then
        echo "$bundled_yq"
        return 0
    fi

    return 1
}

get_compose_host_port() {
    local index="$1"
    local label="$2"
    local compose_file="$KVM_DIR/docker-compose.yml"
    local yq_cmd
    yq_cmd="$(get_yq)" || {
        echo "error: yq not found (install yq or make $SCRIPT_DIR/assets/tools/yq_linux_amd64 executable)" >&2
        return 1
    }

    local mapping
    mapping="$($yq_cmd -r ".services.kvm.ports[$index]" "$compose_file")" || return 1
    if [[ -z "$mapping" || "$mapping" == "null" ]]; then
        echo "error: could not read .services.kvm.ports[$index] ($label) from $compose_file" >&2
        return 1
    fi

    mapping="${mapping%%/*}"

    local -a parts
    IFS=':' read -r -a parts <<<"$mapping"

    local host_port=""
    if [[ ${#parts[@]} -eq 3 ]]; then
        host_port="${parts[1]}"
    elif [[ ${#parts[@]} -eq 2 ]]; then
        host_port="${parts[0]}"
    elif [[ ${#parts[@]} -eq 1 ]]; then
        host_port="${parts[0]}"
    fi

    if [[ ! "$host_port" =~ ^[0-9]+$ ]]; then
        echo "error: unexpected port mapping format for $label: $mapping" >&2
        return 1
    fi

    echo "$host_port"
}

get_vnc_port() {
    get_compose_host_port 2 "VNC"
}

get_ssh_port() {
    get_compose_host_port 3 "SSH"
}

select_command() {
    local options=(start stop status shell logs vnc ssh quit)
    while true; do
        echo "Available commands:"
        local i=1
        for opt in "${options[@]}"; do
            echo "$i) $opt"
            ((i++))
        done

        local reply
        read -r -p "Select a command (number or name): " reply || return 1

        reply="${reply#"${reply%%[![:space:]]*}"}"
        reply="${reply%"${reply##*[![:space:]]}"}"

        if [[ -z "$reply" ]]; then
            echo "Invalid selection. Try again." >&2
            continue
        fi

        if [[ "$reply" =~ ^[0-9]+$ ]]; then
            local idx=$((reply - 1))
            if (( idx >= 0 && idx < ${#options[@]} )); then
                local cmd="${options[$idx]}"
                if [[ "$cmd" == "quit" ]]; then
                    return 1
                fi
                COMMAND="$cmd"
                return 0
            fi
        else
            for opt in "${options[@]}"; do
                if [[ "$reply" == "$opt" ]]; then
                    if [[ "$opt" == "quit" ]]; then
                        return 1
                    fi
                    COMMAND="$opt"
                    return 0
                fi
            done
        fi

        echo "Invalid selection. Try again." >&2
    done
}

COMMAND="${1:-}"
if [[ -z "$COMMAND" ]]; then
    if ! select_command; then
        exit 0
    fi
fi

case "$COMMAND" in
    start)
        echo "Starting KVM Ubuntu..."
        cd "$KVM_DIR" && docker compose up -d
        ;;
    stop)
        echo "Stopping KVM Ubuntu..."
        cd "$KVM_DIR" && docker compose stop
        ;;
    status)
        cd "$KVM_DIR" && docker compose ps
        ;;
    shell)
        cd "$KVM_DIR" && docker compose exec kvm /bin/bash
        ;;
    logs)
        cd "$KVM_DIR" && docker compose logs "${@:2}"
        ;;
    vnc)
        vnc_port="$(get_vnc_port)" || exit 1
        echo "Connecting to VNC on localhost:$vnc_port ..."
        vncviewer "localhost::$vnc_port"
        ;;
    ssh)
        ssh_port="$(get_ssh_port)" || exit 1
        ssh_user="${2:-root}"
        echo "Connecting to SSH on localhost:$ssh_port as $ssh_user ..."
        ssh -p "$ssh_port" "${ssh_user}@localhost" "${@:3}"
        ;;
    *)
        echo "Usage: ./kvm.sh <start|stop|status|shell|logs|vnc|ssh>"
        echo "  logs: passes extra args to docker compose logs"
        echo "  ssh:  ./kvm.sh ssh [user] [extra ssh args...]"
        echo "Or run without arguments for an interactive menu."
        exit 1
        ;;
esac
