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
	sudo "${init_script}" "$@"
}

print_menu() {
	cat <<EOF
可用任务：
  1) 系统基础初始化 (修改 APT/pip 源，安装基础软件、Python、SSH、UFW)
  q) 退出
EOF
}

interactive_menu() {
	while true; do
		print_menu
		read -rp "请选择任务编号: " choice
		case "$choice" in
			1)
				run_init
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
  help        显示本帮助

不带参数运行时，将进入交互式菜单。
EOF
}

main() {
	local cmd="${1:-}"
	case "${cmd:-}" in
		init)
			shift || true
			run_init "$@"
			;;
		help|-h|--help)
			usage
			;;
		"")
			interactive_menu
			;;
		*)
			log_error "未知任务: $cmd"
			usage
			exit 1
			;;
	esac
}

main "$@"

