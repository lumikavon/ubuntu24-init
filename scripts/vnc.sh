#!/usr/bin/env bash
set -euo pipefail

# Simple logging helpers
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
show_step() { printf "\n==> %s\n" "$1"; }
log_info() { printf "%s [INFO] %s\n" "$(_now)" "$1"; }
log_warning() { printf "%s [WARN] %s\n" "$(_now)" "$1"; }
log_error() { printf "%s [ERROR] %s\n" "$(_now)" "$1"; }
log_success() { printf "%s [OK] %s\n" "$(_now)" "$1"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
        log_error "未检测到 sudo，无法安装 VNC 服务"
        exit 1
    fi
}

install_vnc_packages() {
    show_step "安装 VNC 服务端"
    require_sudo

    sudo apt-get update -y || log_warning "apt-get update 可能失败"
    sudo apt-get install -y tigervnc-standalone-server tigervnc-common xterm \
        || log_error "VNC 服务端安装失败"
}

configure_vnc_user() {
    show_step "配置 VNC 用户环境"

    local vnc_dir="$HOME/.vnc"
    mkdir -p "$vnc_dir"

    cat > "$vnc_dir/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec xterm &
EOF
    chmod +x "$vnc_dir/xstartup"

    if [ -n "${VNC_PASSWORD:-}" ]; then
        umask 077
        if command -v vncpasswd >/dev/null 2>&1; then
            printf "%s\n" "$VNC_PASSWORD" | vncpasswd -f > "$vnc_dir/passwd"
            chmod 600 "$vnc_dir/passwd"
            log_info "已写入 VNC 密码: $vnc_dir/passwd"
        else
            log_warning "未找到 vncpasswd，可在安装完成后手动运行 vncpasswd 设置密码"
        fi
    else
        # 如果未提供密码，自动生成一个强口令并写入 passwd 文件，避免 systemd 启动失败
        if command -v vncpasswd >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
            VNC_PASSWORD_GENERATED=$(openssl rand -base64 12)
            umask 077
            printf "%s\n" "$VNC_PASSWORD_GENERATED" | vncpasswd -f > "$vnc_dir/passwd"
            chmod 600 "$vnc_dir/passwd"
            log_info "未提供 VNC_PASSWORD，已自动生成并写入密码文件: $vnc_dir/passwd"
            log_info "生成的 VNC 密码: $VNC_PASSWORD_GENERATED"
        else
            log_warning "未设置 VNC_PASSWORD，且无法自动生成密码 (缺少 vncpasswd 或 openssl)。首次运行 vncserver 时会提示设置。"
        fi
    fi

    log_info "如需启动: vncserver -localhost no :1"
}

configure_vnc_autostart() {
    show_step "配置 VNC 开机自启"

    require_sudo

    local target_user
    target_user="${SUDO_USER:-$USER}"
    if [ -z "$target_user" ]; then
        log_error "无法确定目标用户"
        exit 1
    fi

    local service_file="/etc/systemd/system/vncserver@.service"
    log_info "写入 systemd 单元: $service_file (用户: $target_user)"

        [ -n "$target_user" ] || target_user="$USER"
[ -n "$target_user" ] || target_user="$USER"
    sudo tee "$service_file" >/dev/null <<EOF
[Unit]
Description=TigerVNC server for %i
After=syslog.target network.target

[Service]
Type=forking
User=$target_user
PAMName=login
PIDFile=/home/%u/.vnc/%H:%i.pid
Environment=HOME=/home/%u
WorkingDirectory=/home/%u
ExecStartPre=/bin/sh -c "test -f /home/%u/.vnc/passwd || true"
ExecStart=/usr/bin/vncserver -localhost no %i
ExecStop=/usr/bin/vncserver -kill %i
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload || log_warning "daemon-reload 失败"

    # 默认使用 :1 显示
    local unit_name="vncserver@:1.service"
    sudo systemctl enable "$unit_name" || log_warning "启用自启失败: $unit_name"
    sudo systemctl restart "$unit_name" || log_warning "启动 VNC 服务失败: $unit_name"

    log_success "VNC 已配置为开机启动 (显示 :1，用户 $target_user)"
}

main() {
    install_vnc_packages
    configure_vnc_user
    configure_vnc_autostart
    log_success "VNC Server 安装配置完成"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
