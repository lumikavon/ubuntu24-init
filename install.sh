#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"

show_step() { printf "\n==> %s\n" "$1"; }
log_info() { printf "[INFO] %s\n" "$1"; }
log_error() { printf "[ERROR] %s\n" "$1"; }

run_init() {
	show_step "运行基础初始化 (scripts/init.sh)"
	local init_script="$SCRIPT_DIR/init.sh"
	if [ ! -x "$init_script" ]; then
		log_error "找不到或不可执行: $init_script"
		exit 1
	fi
	local username="$1"; shift || true
	sudo INIT_USERNAME="$username" "${init_script}" "$@"
}

run_nodejs() {
	show_step "安装 Node.js 环境 (scripts/nodejs.sh)"
	local node_script="$SCRIPT_DIR/nodejs.sh"
	if [ ! -x "$node_script" ]; then
		log_error "找不到或不可执行: $node_script"
		exit 1
	fi
	"${node_script}"
}

run_mcp() {
	show_step "安装 MCP 相关依赖 (scripts/mcp.sh)"
	local mcp_script="$SCRIPT_DIR/mcp.sh"
	if [ ! -x "$mcp_script" ]; then
		log_error "找不到或不可执行: $mcp_script"
		exit 1
	fi
	"${mcp_script}"
}

run_docker() {
	show_step "安装 Docker (scripts/docker.sh)"
	local docker_script="$SCRIPT_DIR/docker.sh"
	if [ ! -x "$docker_script" ]; then
		log_error "找不到或不可执行: $docker_script"
		exit 1
	fi
	"${docker_script}"
}

run_codeserver() {
	show_step "安装 code-server (scripts/codeserver.sh)"
	local cs_script="$SCRIPT_DIR/codeserver.sh"
	if [ ! -x "$cs_script" ]; then
		log_error "找不到或不可执行: $cs_script"
		exit 1
	fi
	"${cs_script}"
}

print_menu() {
	cat <<EOF
可用任务：
  1) 系统基础初始化 (修改 APT/pip 源，安装基础软件、Python、SSH、UFW)
	2) 安装 Node.js 环境
	3) 安装 MCP 依赖
	4) 安装 Docker
	5) 安装 code-server
  q) 退出
EOF
}

interactive_menu() {
	local username="$1"
	while true; do
		print_menu
		read -rp "请选择任务编号: " choice
		case "$choice" in
			1)
				run_init "$username"
				;;
			2)
				run_nodejs
				;;
			3)
				run_mcp
				;;
			4)
				run_docker
				;;
			5)
				run_codeserver
				;;
			q|Q)
				log_info "已退出"
				exit 0
				;;
			*)
				log_error "无效选择: $choice"
				;;
		esac
	done
}

usage() {
	cat <<EOF
用法: $0 [任务]

任务 (可选)：
  init        运行系统基础初始化 (调用 scripts/init.sh)
	nodejs      安装 Node.js 环境 (调用 scripts/nodejs.sh)
	mcp         安装 MCP 依赖 (调用 scripts/mcp.sh)
	docker      安装 Docker (调用 scripts/docker.sh)
	codeserver  安装 code-server (调用 scripts/codeserver.sh)
  help        显示本帮助

不带参数运行时，将进入交互式菜单。
EOF
}

main() {
	if [ "$(id -u)" -eq 0 ]; then
		log_error "请使用非 root 用户运行此脚本"
		exit 1
	fi

	local current_user
	current_user="$(id -un)"

	local cmd="${1:-}"
	case "${cmd:-}" in
		init)
			shift || true
			run_init "$current_user" "$@"
			;;
		nodejs)
			shift || true
			run_nodejs
			;;
		mcp)
			shift || true
			run_mcp
			;;
		docker)
			shift || true
			run_docker
			;;
		codeserver)
			shift || true
			run_codeserver
			;;
		help|-h|--help)
			usage
			;;
		"")
			interactive_menu "$current_user"
			;;
		*)
			log_error "未知任务: $cmd"
			usage
			exit 1
			;;
	esac
}

main "$@"

