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
MCP_VENV_DIR="$HOME/.local/mcp-venv"

install_uvx() {
    show_step "安装 uvx"

    if command -v uvx >/dev/null 2>&1; then
        log_info "uvx 已存在，跳过安装"
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_error "未检测到 curl，无法下载安装脚本"
        exit 1
    fi

    log_info "通过官方安装脚本安装 uv..."
    if curl -fsSL https://astral.sh/uv/install.sh | sh; then
        export PATH="$HOME/.local/bin:$PATH"
        log_success "uvx 安装完成"
    else
        log_error "uvx 安装失败"
        exit 1
    fi
}

resolve_pip_cmd() {
    if [ -n "${PIP_CMD:-}" ]; then
        # shellcheck disable=SC2206
        PIP_CMD_ARR=(${PIP_CMD})
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        local ext_file
        ext_file="$(python3 - <<'PY'
import sysconfig, os
print(os.path.join(sysconfig.get_paths().get("purelib", ""), "EXTERNALLY-MANAGED"))
PY
 2>/dev/null || true)"

        if [ -n "$ext_file" ] && [ -f "$ext_file" ]; then
            log_info "检测到受管 Python 环境，创建虚拟环境: $MCP_VENV_DIR"
            if [ ! -d "$MCP_VENV_DIR" ]; then
                python3 -m venv "$MCP_VENV_DIR" || log_error "虚拟环境创建失败"
            fi
            PIP_CMD_ARR=("$MCP_VENV_DIR/bin/pip")
            "$MCP_VENV_DIR/bin/pip" -q install -U pip wheel setuptools || true
            return 0
        fi

        PIP_CMD_ARR=(python3 -m pip)
        return 0
    fi

    if command -v pip3 >/dev/null 2>&1; then
        PIP_CMD_ARR=(pip3)
        return 0
    fi

    log_error "未找到可用的 pip/python3，请先安装 Python/pip"
    exit 1
}

install_mcp() {
    show_step "安装 MCP 相关依赖"

    if ! command -v npm >/dev/null 2>&1; then
        log_error "未检测到 npm，请先安装 Node.js 环境"
        exit 1
    fi

    local npm_registry="https://registry.npmmirror.com"
    local npm_pkgs=(
        "@playwright/mcp@latest"
        "@modelcontextprotocol/server-sequential-thinking"
        "@modelcontextprotocol/server-memory"
        "@modelcontextprotocol/server-filesystem"
        "mcp-mongo-server"
        "@modelcontextprotocol/server-redis"
        "@upstash/context7-mcp"
        "@modelcontextprotocol/server-puppeteer"
        "firecrawl-mcp"
        "@agentdeskai/browser-tools-mcp@1.2.1"
    )

    log_info "通过 npm 安装 MCP 相关包..."
    for pkg in "${npm_pkgs[@]}"; do
        log_info "安装 npm 包: $pkg"
        npm install -g "$pkg" --registry="$npm_registry" || log_warning "安装失败: $pkg"
    done

    resolve_pip_cmd
    log_info "使用 pip 命令: ${PIP_CMD_ARR[*]}"

    local pip_pkgs=(
        "mcp-server-time"
        "mcp-server-fetch"
        "mcp-server-sqlite"
        "mysql-mcp-server"
        "mcp-server-qdrant"
    )

    for pkg in "${pip_pkgs[@]}"; do
        log_info "安装 pip 包: $pkg"
        "${PIP_CMD_ARR[@]}" install -U "$pkg" || log_warning "安装失败: $pkg"
    done

    log_success "MCP 依赖安装完成"
}

main() {
    install_uvx
    install_mcp
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
