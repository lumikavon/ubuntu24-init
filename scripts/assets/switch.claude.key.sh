#!/usr/bin/env bash
set -euo pipefail

# Switch API Keys for Claude Code / Codex / Gemini

show_step() { printf "\n==> %s\n" "$1"; }
log_info() { printf "[INFO] %s\n" "$1"; }
log_success() { printf "[OK] %s\n" "$1"; }
log_error() { printf "[ERROR] %s\n" "$1"; }

BASHRC="$HOME/.bashrc"
CODEX_AUTH="$HOME/.codex/auth.json"

# Claude Code env markers
CC_BEGIN="# Claude Code Environment Variables"
CC_END="# End Claude Code Environment Variables"

# Codex env markers
CODEX_BEGIN="# OPENAI Environment Variables (managed by initializer) - begin"
CODEX_END="# OPENAI Environment Variables (managed by initializer) - end"

# Gemini env markers
GEMINI_BEGIN="# GEMINI Environment Variables (managed by initializer) - begin"
GEMINI_END="# GEMINI Environment Variables (managed by initializer) - end"

update_bashrc_block() {
	local begin_marker="$1"
	local end_marker="$2"
	local content="$3"

	touch "$BASHRC"
	local tmpfile
	tmpfile="$(mktemp)"
	awk -v begin="$begin_marker" -v end="$end_marker" '
		$0 == begin { skipping = 1; next }
		skipping && $0 == end { skipping = 0; next }
		!skipping { print }
	' "$BASHRC" >"$tmpfile" && mv "$tmpfile" "$BASHRC" || rm -f "$tmpfile"

	{
		printf '%s\n' "$begin_marker"
		printf '%s\n' "$content"
		printf '%s\n' "$end_marker"
	} >>"$BASHRC"
}

switch_claude_code_key() {
	show_step "切换 Claude Code API Key"
	read -rp "请输入新的 Claude Code API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	local content
	content=$(cat <<EOF
export ANTHROPIC_BASE_URL="https://api.aicodemirror.com/api/claude"
export ANTHROPIC_API_KEY="$new_key"
EOF
)
	update_bashrc_block "$CC_BEGIN" "$CC_END" "$content"
	log_success "Claude Code API Key 已更新到 ~/.bashrc"
	log_info "请执行 source ~/.bashrc 或重启终端使其生效"
}

switch_codex_key() {
	show_step "切换 Codex API Key"
	read -rp "请输入新的 Codex (OpenAI) API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	# Update ~/.bashrc
	local content
	content=$(cat <<EOF
export OPENAI_BASE_URL="https://api.aicodemirror.com/api/codex/backend-api/codex"
export OPENAI_API_KEY="$new_key"
EOF
)
	update_bashrc_block "$CODEX_BEGIN" "$CODEX_END" "$content"
	log_success "Codex 环境变量已更新到 ~/.bashrc"

	# Update ~/.codex/auth.json
	if [ -d "$HOME/.codex" ]; then
		mkdir -p "$HOME/.codex"
		if command -v jq >/dev/null 2>&1; then
			jq -n --arg key "$new_key" '{OPENAI_API_KEY: $key}' >"$CODEX_AUTH"
		else
			printf '{\n  "OPENAI_API_KEY": "%s"\n}\n' "$new_key" >"$CODEX_AUTH"
		fi
		chmod 600 "$CODEX_AUTH" 2>/dev/null || true
		log_success "Codex auth.json 已更新"
	else
		mkdir -p "$HOME/.codex"
		if command -v jq >/dev/null 2>&1; then
			jq -n --arg key "$new_key" '{OPENAI_API_KEY: $key}' >"$CODEX_AUTH"
		else
			printf '{\n  "OPENAI_API_KEY": "%s"\n}\n' "$new_key" >"$CODEX_AUTH"
		fi
		chmod 600 "$CODEX_AUTH" 2>/dev/null || true
		log_success "Codex auth.json 已创建"
	fi

	log_info "请执行 source ~/.bashrc 或重启终端使其生效"
}

switch_gemini_key() {
	show_step "切换 Gemini API Key"
	read -rp "请输入新的 Gemini API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	local content
	content=$(cat <<EOF
export GOOGLE_GEMINI_BASE_URL="https://api.aicodemirror.com/api/gemini"
export GEMINI_API_KEY="$new_key"
EOF
)
	update_bashrc_block "$GEMINI_BEGIN" "$GEMINI_END" "$content"
	log_success "Gemini API Key 已更新到 ~/.bashrc"
	log_info "请执行 source ~/.bashrc 或重启终端使其生效"
}

apply_key_to_claude() {
	show_step "直接应用 API Key 到 Claude Code"
	read -rp "请输入 Claude Code API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	export ANTHROPIC_BASE_URL="https://api.aicodemirror.com/api/claude"
	export ANTHROPIC_API_KEY="$new_key"
	log_success "已在当前 shell 中设置 ANTHROPIC_API_KEY"
	log_info "此设置仅在当前终端会话有效"
}

apply_key_to_codex() {
	show_step "直接应用 API Key 到 Codex"
	read -rp "请输入 Codex (OpenAI) API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	export OPENAI_BASE_URL="https://api.aicodemirror.com/api/codex/backend-api/codex"
	export OPENAI_API_KEY="$new_key"
	log_success "已在当前 shell 中设置 OPENAI_API_KEY"
	log_info "此设置仅在当前终端会话有效"
}

apply_key_to_gemini() {
	show_step "直接应用 API Key 到 Gemini"
	read -rp "请输入 Gemini API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	export GOOGLE_GEMINI_BASE_URL="https://api.aicodemirror.com/api/gemini"
	export GEMINI_API_KEY="$new_key"
	log_success "已在当前 shell 中设置 GEMINI_API_KEY"
	log_info "此设置仅在当前终端会话有效"
}

switch_all_keys() {
	show_step "切换所有 API Key (Claude Code/Codex/Gemini)"
	read -rp "请输入统一的 API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	# Claude Code
	local cc_content
	cc_content=$(cat <<EOF
export ANTHROPIC_BASE_URL="https://api.aicodemirror.com/api/claude"
export ANTHROPIC_API_KEY="$new_key"
EOF
)
	update_bashrc_block "$CC_BEGIN" "$CC_END" "$cc_content"
	log_success "Claude Code API Key 已更新"

	# Codex
	local codex_content
	codex_content=$(cat <<EOF
export OPENAI_BASE_URL="https://api.aicodemirror.com/api/codex/backend-api/codex"
export OPENAI_API_KEY="$new_key"
EOF
)
	update_bashrc_block "$CODEX_BEGIN" "$CODEX_END" "$codex_content"
	mkdir -p "$HOME/.codex"
	if command -v jq >/dev/null 2>&1; then
		jq -n --arg key "$new_key" '{OPENAI_API_KEY: $key}' >"$CODEX_AUTH"
	else
		printf '{\n  "OPENAI_API_KEY": "%s"\n}\n' "$new_key" >"$CODEX_AUTH"
	fi
	chmod 600 "$CODEX_AUTH" 2>/dev/null || true
	log_success "Codex API Key 已更新"

	# Gemini
	local gemini_content
	gemini_content=$(cat <<EOF
export GOOGLE_GEMINI_BASE_URL="https://api.aicodemirror.com/api/gemini"
export GEMINI_API_KEY="$new_key"
EOF
)
	update_bashrc_block "$GEMINI_BEGIN" "$GEMINI_END" "$gemini_content"
	log_success "Gemini API Key 已更新"

	log_info "请执行 source ~/.bashrc 或重启终端使其生效"
}

apply_key_to_all() {
	show_step "直接应用 API Key 到所有工具"
	read -rp "请输入统一的 API Key: " new_key
	if [ -z "$new_key" ]; then
		log_error "未输入 API Key，已取消"
		return 1
	fi

	export ANTHROPIC_BASE_URL="https://api.aicodemirror.com/api/claude"
	export ANTHROPIC_API_KEY="$new_key"
	export OPENAI_BASE_URL="https://api.aicodemirror.com/api/codex/backend-api/codex"
	export OPENAI_API_KEY="$new_key"
	export GOOGLE_GEMINI_BASE_URL="https://api.aicodemirror.com/api/gemini"
	export GEMINI_API_KEY="$new_key"

	log_success "已在当前 shell 中设置所有 API Key"
	log_info "此设置仅在当前终端会话有效"
}

print_menu() {
	cat <<'EOF'

========================================
    API Key 切换工具
========================================

持久化配置 (写入 ~/.bashrc):
  1) 切换 Claude Code API Key
  2) 切换 Codex API Key
  3) 切换 Gemini API Key
  4) 切换所有 API Key (统一设置)

临时应用 (仅当前会话):
  5) 直接应用到 Claude Code
  6) 直接应用到 Codex
  7) 直接应用到 Gemini
  8) 直接应用到所有工具

  q) 退出

EOF
}

main() {
	while true; do
		print_menu
		read -rp "请选择操作: " choice
		case "$choice" in
			1) switch_claude_code_key ;;
			2) switch_codex_key ;;
			3) switch_gemini_key ;;
			4) switch_all_keys ;;
			5) apply_key_to_claude ;;
			6) apply_key_to_codex ;;
			7) apply_key_to_gemini ;;
			8) apply_key_to_all ;;
			q|Q) log_info "已退出"; exit 0 ;;
			*) log_error "无效选择: $choice" ;;
		esac
	done
}

main "$@"
