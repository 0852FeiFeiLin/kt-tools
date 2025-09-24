#!/bin/bash

# kt-tools 服务器快速配置脚本

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INSTALLER_DIR="$ROOT_DIR/public/installers"
SOFTWARE_DIR="$ROOT_DIR/resources/software-cache/macos-arm"
LOG_DIR="$ROOT_DIR/resources/logs"
UPDATE_SCRIPT="$SCRIPT_DIR/update_cache.sh"
DEFAULT_PORT=8000

detect_ip() {
    if command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
        hostname -I 2>/dev/null | awk '{print $1}' | head -1
        return
    fi

    if command -v ipconfig >/dev/null 2>&1; then
        local candidates=(en0 en1 en2)
        for iface in "${candidates[@]}"; do
            local addr
            addr=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
            if [[ -n "$addr" ]]; then
                echo "$addr"
                return
            fi
        done
    fi

    if command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null |
            awk '/inet / && $2 != "127.0.0.1" {print $2; exit}'
        return
    fi
}

DEFAULT_IP=$(detect_ip)

if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ 需要 python3 支持，请先安装 python3。"
    exit 1
fi

if [[ -z "$DEFAULT_IP" ]]; then
    echo "⚠️  未能自动检测服务器 IP，请手动输入。"
fi

echo "🍎 kt-tools 服务器配置"
echo "======================================"

# 准备目录与权限
echo "📁 创建目录结构..."
mkdir -p "$SOFTWARE_DIR" "$LOG_DIR"
chmod +x "$UPDATE_SCRIPT" \
         "$INSTALLER_DIR/quick_install.sh" \
         "$INSTALLER_DIR/mac_m4_installer.sh"

read -p "请输入服务器IP${DEFAULT_IP:+ (默认: $DEFAULT_IP)}: " input_ip
if [[ -n "$input_ip" ]]; then
    SERVER_IP="$input_ip"
elif [[ -n "$DEFAULT_IP" ]]; then
    SERVER_IP="$DEFAULT_IP"
else
    echo "❌ 未提供有效 IP，退出。"
    exit 1
fi

read -p "请输入服务端口 (默认: $DEFAULT_PORT): " input_port
if [[ -n "$input_port" ]]; then
    SERVER_PORT="$input_port"
else
    SERVER_PORT="$DEFAULT_PORT"
fi

echo "🌐 使用 IP: $SERVER_IP 端口: $SERVER_PORT"

update_env_var() {
    local file="$1"
    local key="$2"
    local value="$3"
    python3 - "$file" "$key" "$value" <<'PY'
import re
import sys
path, key, value = sys.argv[1:4]
text = open(path, 'r', encoding='utf-8').read()
pattern = re.compile(rf'^({re.escape(key)}=)".*?"', re.MULTILINE)
new_text, count = pattern.subn(rf'\1"{value}"', text)
if count == 0:
    sys.stderr.write(f"无法在 {path} 中更新 {key}\n")
    sys.exit(1)
open(path, 'w', encoding='utf-8').write(new_text)
PY
}

update_env_var "$INSTALLER_DIR/quick_install.sh" "SERVER_IP" "$SERVER_IP"
update_env_var "$INSTALLER_DIR/quick_install.sh" "SERVER_PORT" "$SERVER_PORT"
update_env_var "$INSTALLER_DIR/mac_m4_installer.sh" "SERVER_IP" "$SERVER_IP"
update_env_var "$INSTALLER_DIR/mac_m4_installer.sh" "SERVER_PORT" "$SERVER_PORT"
update_env_var "$INSTALLER_DIR/mac_m4_installer.sh" "BASE_URL" "http://${SERVER_IP}:${SERVER_PORT}/packages"

echo "⏰ 是否配置自动更新任务？(每月1日与16日凌晨3点运行)"
read -p "输入 y/n (默认: y): " setup_cron

if [[ "$setup_cron" != "n" && "$setup_cron" != "N" ]]; then
    (crontab -l 2>/dev/null; echo "0 3 1,16 * * bash $UPDATE_SCRIPT >> $LOG_DIR/cron.log 2>&1") | crontab -
    echo "✅ 已写入 cron 任务"
else
    echo "⏭️  跳过 cron 配置"
fi

echo "🚀 是否立即执行一次缓存更新？"
read -p "输入 y/n (默认: y): " run_update
if [[ "$run_update" != "n" && "$run_update" != "N" ]]; then
    bash "$UPDATE_SCRIPT"
    echo "✅ 缓存更新脚本已执行"
else
    echo "ℹ️ 可稍后手动运行: bash $UPDATE_SCRIPT"
fi

echo ""
echo "🎉 配置完成"
echo "======================================"
echo "📁 软件包目录: $SOFTWARE_DIR"
echo "📄 日志目录: $LOG_DIR"
echo "🌐 访问地址: http://$SERVER_IP:$SERVER_PORT"
echo "👉 安装入口: curl -fsSL http://$SERVER_IP:$SERVER_PORT/installers/quick_install.sh | bash"
echo "======================================"
