#!/bin/bash

# Mac M4 一键软件安装脚本 - 集成版
# 作者: Claude Code
# 版本: 3.0

set -e  # 遇到错误立即退出

# 配置变量
SERVER_IP="192.168.9.148"
SERVER_PORT="8000"
BASE_URL="http://192.168.9.148:8000/packages"
TEMP_DIR="/tmp/mac_m4_installer"
INSTALL_LOG="/tmp/mac_m4_install.log"

SUCCESS_APPS=()
FAILED_APPS=()

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$INSTALL_LOG"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$INSTALL_LOG"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$INSTALL_LOG"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$INSTALL_LOG"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$INSTALL_LOG"
}

# 检查系统要求
check_requirements() {
    print_status "检查系统要求..."

    if [[ "$(uname -m)" != "arm64" ]]; then
        print_error "此脚本仅支持Apple Silicon Mac (M1/M2/M3/M4)"
        exit 1
    fi

    local macos_version
    macos_version=$(sw_vers -productVersion)
    print_status "检测到 macOS $macos_version"

    if ! ping -c 1 "$SERVER_IP" >/dev/null 2>&1; then
        print_error "无法连接到软件服务器 ($SERVER_IP)"
        print_status "请确保与软件服务器在同一网络"
        exit 1
    fi

    print_success "系统检查通过"
}

# 创建临时目录
setup_environment() {
    print_status "设置安装环境..."
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    touch "$INSTALL_LOG"
    print_success "环境设置完成"
}

# 下载文件函数
download_file() {
    local filename="$1"
    local url="${BASE_URL}/${filename}"
    local output_path="${TEMP_DIR}/${filename}"

    print_status "下载 $filename..."
    print_status "源地址: $url"
    print_status "保存路径: $output_path"

    if curl -L --connect-timeout 30 --max-time 600 -o "$output_path" "$url"; then
        if [[ -f "$output_path" && $(stat -f%z "$output_path") -gt 1000000 ]]; then
            print_success "$filename 下载成功 ($(du -h "$output_path" | cut -f1))"
            return 0
        else
            print_warning "$filename 下载文件太小，可能失败"
            return 1
        fi
    else
        print_error "$filename 下载失败"
        return 1
    fi
}

# 安装DMG文件
install_dmg() {
    local dmg_file="$1"
    local dmg_path="${TEMP_DIR}/${dmg_file}"

    if [[ ! -f "$dmg_path" ]]; then
        print_warning "跳过 $dmg_file - 文件不存在"
        return 1
    fi

    print_status "安装 $dmg_file..."

    local mount_point
    mount_point=$(mktemp -d "/tmp/mount_${dmg_file%%.*}_XXXX")
    if ! hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -quiet; then
        rmdir "$mount_point" 2>/dev/null || true
        print_error "无法挂载 $dmg_file"
        return 1
    fi

    local installed=false
    local errors=0

    local pkg_path
    pkg_path=$(find "$mount_point" -maxdepth 5 -type f -name "*.pkg" | head -1)
    if [[ -n "$pkg_path" ]]; then
        local pkg_basename=$(basename "$pkg_path")
        print_status "安装安装包: $pkg_basename"
        if sudo installer -pkg "$pkg_path" -target /; then
            print_success "$pkg_basename 安装成功"
            installed=true
        else
            print_error "$pkg_basename 安装失败"
            ((errors++))
        fi
    fi

        local app_path
    app_path=$(find "$mount_point" -maxdepth 5 -type d -name "*.app" | head -1)
    if [[ -n "$app_path" ]]; then
        local app_basename=$(basename "$app_path")
        local target_app="/Applications/$app_basename"
        print_status "安装应用程序: $app_basename"
        if [[ -d "$target_app" ]]; then
            print_status "移除已有的 $app_basename"
            sudo rm -rf "$target_app"
        fi
        if sudo ditto "$app_path" "$target_app"; then
            print_success "$app_basename 安装成功"
            installed=true
        else
            print_error "$app_basename 安装失败"
            ((errors++))
        fi
    fi

    hdiutil detach "$mount_point" -quiet >/dev/null 2>&1 || true
    rmdir "$mount_point" 2>/dev/null || true

    if [[ "$installed" = true ]] && (( errors == 0 )); then
        return 0
    fi

    print_warning "$dmg_file 安装未成功"
    return 1
}

# 安装PKG文件
install_pkg() {
    local pkg_file="$1"
    local pkg_path="${TEMP_DIR}/${pkg_file}"

    if [[ ! -f "$pkg_path" ]]; then
        print_warning "跳过 $pkg_file - 文件不存在"
        return 1
    fi

    print_status "安装 $pkg_file..."

    if sudo installer -pkg "$pkg_path" -target /; then
        print_success "$pkg_file 安装成功"
    else
        print_error "$pkg_file 安装失败"
        return 1
    fi
}

# 安装ZIP文件
install_zip() {
    local zip_file="$1"
    local zip_path="${TEMP_DIR}/${zip_file}"

    if [[ ! -f "$zip_path" ]]; then
        print_warning "跳过 $zip_file - 文件不存在"
        return 1
    fi

    print_status "安装 $zip_file..."

    local extract_dir="${TEMP_DIR}/$(basename "$zip_file" .zip)_extracted"
    mkdir -p "$extract_dir"

    if unzip -q "$zip_path" -d "$extract_dir"; then
        local app_name
        app_name=$(find "$extract_dir" -name "*.app" -maxdepth 3 | head -1)
        if [[ -n "$app_name" ]]; then
            local app_basename=$(basename "$app_name")
            print_status "安装应用程序: $app_basename"
            cp -R "$app_name" /Applications/
            print_success "$app_basename 安装成功"
        else
            print_warning "$zip_file 中未找到应用程序"
        fi
    else
        print_error "$zip_file 解压失败"
        return 1
    fi
}

# 安装TAR.GZ文件（命令行工具）
install_targz() {
    local targz_file="$1"
    local targz_path="${TEMP_DIR}/${targz_file}"

    if [[ ! -f "$targz_path" ]]; then
        print_warning "跳过 $targz_file - 文件不存在"
        return 1
    fi

    print_status "安装 $targz_file..."

    local extract_dir="${TEMP_DIR}/$(basename "$targz_file" .tar.gz)_extracted"
    mkdir -p "$extract_dir"

    if tar -xzf "$targz_path" -C "$extract_dir"; then
        local binary_file
        binary_file=$(find "$extract_dir" -type f -perm +111 | head -1)
        if [[ -n "$binary_file" ]]; then
            local binary_name=$(basename "$binary_file")
            print_status "安装命令行工具: $binary_name"
            sudo cp "$binary_file" /usr/local/bin/
            sudo chmod +x "/usr/local/bin/$binary_name"
            print_success "$binary_name 安装成功"
        else
            print_warning "$targz_file 中未找到可执行文件"
        fi
    else
        print_error "$targz_file 解压失败"
        return 1
    fi
}

# 主安装函数
install_software() {
    print_status "开始下载和安装软件包..."

    local software_list=(
        "ChatGPT_M.dmg"
        "Chrome_M.dmg"
        "Docker_M.dmg"
        "Telegram_M.dmg"
        "WeChat_M.dmg"
        "Wave_M.dmg"
        "Qoder_M.dmg"
        "Trae_M.dmg"
        "ClashVerge_M.dmg"
        "VSCode_ARM64.zip"
        "WPS_M.zip"
        "NodeJS_ARM64.pkg"
        "Homebrew.pkg"
    )

    local installed_count=0
    local total_count=${#software_list[@]}
    local success_list=()
    local fail_list=()

    print_status "开始下载软件包..."
    for software in "${software_list[@]}"; do
        download_file "$software" || true
    done

    print_status "开始安装软件..."
           for dmg in ChatGPT_M.dmg Chrome_M.dmg Docker_M.dmg Telegram_M.dmg WeChat_M.dmg Wave_M.dmg Qoder_M.dmg Trae_M.dmg ClashVerge_M.dmg; do
        local label
        case "$dmg" in
            ChatGPT_M.dmg) label="🤖 ChatGPT - AI助手" ;;
            Chrome_M.dmg) label="🌐 Google Chrome - 浏览器" ;;
            Docker_M.dmg) label="🐳 Docker Desktop - 容器平台" ;;
            Telegram_M.dmg) label="💬 Telegram - 即时通讯" ;;
            WeChat_M.dmg) label="💬 微信 WeChat - 社交通讯" ;;
            Wave_M.dmg) label="🌊 Wave Terminal - 新一代终端" ;;
            Qoder_M.dmg) label="🧠 Qoder - AI 开发助手" ;;
            Trae_M.dmg) label="🛰️ Trae - 系统监控工具" ;;
            ClashVerge_M.dmg) label="🔗 Clash Verge - 代理工具" ;;
            *) label="$dmg" ;;
        esac
        if install_dmg "$dmg"; then
            ((installed_count++))
            success_list+=("$label")
        else
            fail_list+=("$label")
        fi
    done

    for zip in VSCode_ARM64.zip WPS_M.zip; do
        local label
        case "$zip" in
            VSCode_ARM64.zip) label="📝 Visual Studio Code - 代码编辑器" ;;
            WPS_M.zip) label="📊 WPS Office - 办公软件" ;;
            *) label="$zip" ;;
        esac
        if install_zip "$zip"; then
            ((installed_count++))
            success_list+=("$label")
        else
            fail_list+=("$label")
        fi
    done

    for pkg in NodeJS_ARM64.pkg Homebrew.pkg; do
        local label
        case "$pkg" in
            NodeJS_ARM64.pkg) label="🟢 Node.js - JavaScript运行环境" ;;
            Homebrew.pkg) label="🍺 Homebrew - 包管理器" ;;
            *) label="$pkg" ;;
        esac
        if install_pkg "$pkg"; then
            ((installed_count++))
            success_list+=("$label")
        else
            fail_list+=("$label")
        fi
    done

    print_success "安装完成！成功安装 ${installed_count}/$total_count 个软件包"

    SUCCESS_APPS=("${success_list[@]}")
    FAILED_APPS=("${fail_list[@]}")
}

install_claude_cli() {
    print_status "跳过 Claude Code CLI 安装（官方已下架 npm 包）"
    print_status "如需使用，请参考 https://docs.anthropic.com/ 手动配置"
    return 0
}

create_codex_wrapper() {
    local wrapper_path="/usr/local/bin/codex"

    if command -v codex >/dev/null 2>&1; then
        return 0
    fi

    if ! command -v openai >/dev/null 2>&1; then
        return 1
    fi

    if sudo tee "$wrapper_path" >/dev/null <<'EOF_WRAPPER'
#!/bin/bash
exec openai "$@"
EOF_WRAPPER
    then
        sudo chmod +x "$wrapper_path"
        print_success "已创建 codex 命令包装脚本"
        return 0
    fi

    print_warning "未能创建 codex 命令包装脚本，请确认具有写入 /usr/local/bin 的权限"
    return 1
}

install_codex_cli() {
    print_status "安装 Codex CLI..."

    if ! command -v pip3 >/dev/null 2>&1; then
        print_warning "未检测到 pip3，跳过 Codex CLI 安装"
        print_status "请手动执行: pip3 install --upgrade openai"
        return 1
    fi

    if sudo -H pip3 install --upgrade openai --trusted-host pypi.org --trusted-host files.pythonhosted.org >>"$INSTALL_LOG" 2>&1; then
        if command -v pipx >/dev/null 2>&1; then
            pipx install --force openai >>"$INSTALL_LOG" 2>&1 || true
        fi
        if command -v openai >/dev/null 2>&1; then
            create_codex_wrapper || true
            print_success "OpenAI CLI 安装完成，可使用 'openai' 或 'codex' 命令"
            return 0
        fi
    fi

    print_warning "OpenAI CLI 自动安装失败，请手动执行: pip3 install --upgrade openai --trusted-host pypi.org --trusted-host files.pythonhosted.org"
    return 1
}

install_cli_tools() {
    print_status "安装CLI工具..."

    if ! command -v brew >/dev/null 2>&1; then
        print_status "安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    if command -v brew >/dev/null 2>&1; then
        print_status "安装 Git (Homebrew)..."
        if brew list git >/dev/null 2>&1 || brew install git >>"$INSTALL_LOG" 2>&1; then
            if brew list git >/dev/null 2>&1; then
                print_success "Git 安装成功"
                git --version | tee -a "$INSTALL_LOG" >/dev/null 2>&1 || true
            fi
        else
            print_warning "Git 安装失败，请手动执行: brew install git"
        fi
    else
        print_warning "未检测到 Homebrew，无法自动安装 Git"
    fi

    install_claude_cli || true
    install_codex_cli || true
}

# 配置程序坞
configure_dock() {
    print_status "配置程序坞..."

    local apps=(
        "/Applications/ChatGPT.app"
        "/Applications/Google Chrome.app"
        "/Applications/Docker.app"
        "/Applications/Telegram.app"
        "/Applications/WeChat.app"
        "/Applications/Wave.app"
        "/Applications/Qoder.app"
        "/Applications/Trae.app"
        "/Applications/ClashVerge.app"
        "/Applications/Visual Studio Code.app"
        "/Applications/WPS Office.app"
    )

    for app in "${apps[@]}"; do
        if [[ -d "$app" ]]; then
            print_status "添加 $(basename "$app" .app) 到程序坞"
            defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
        fi
    done

    killall Dock
    print_success "程序坞配置完成"
}

cleanup() {
    print_status "清理临时文件..."
    rm -rf "$TEMP_DIR"
    print_success "清理完成"
}

show_summary() {
    echo ""
    echo "======================================"
    echo "🎉 Mac M4 软件安装完成！"
    echo "======================================"
    echo ""
    if (( ${#SUCCESS_APPS[@]} > 0 )); then
        echo "✅ 已安装的软件："
        for item in "${SUCCESS_APPS[@]}"; do
            echo "   $item"
        done
    else
        echo "⚠️ 本次没有成功安装的软件包"
    fi
    if (( ${#FAILED_APPS[@]} > 0 )); then
        echo ""
        echo "⚠️ 以下软件未成功安装："
        for item in "${FAILED_APPS[@]}"; do
            echo "   $item"
        done
    fi
    if (( ${#CLI_SUCCESS[@]} > 0 )); then
        echo ""
        echo "✅ 已安装的 CLI 工具："
        for item in "${CLI_SUCCESS[@]}"; do
            echo "   $item"
        done
    fi
    if (( ${#CLI_FAILED[@]} > 0 )); then
        echo ""
        echo "⚠️ 未成功安装的 CLI 工具："
        for item in "${CLI_FAILED[@]}"; do
            echo "   $item"
        done
    fi
    echo ""
    echo "📋 安装日志保存在: $INSTALL_LOG"
    echo ""
    echo "🚀 现在可以开始使用你的新Mac了！"
    echo "======================================"
}

main() {
    echo "======================================"
    echo "🍎 Mac M4 一键软件安装器"
    echo "======================================"
    echo ""

    if [[ $EUID -eq 0 ]]; then
        print_error "请不要以root权限运行此脚本"
        exit 1
    fi

    check_requirements
    setup_environment
    install_software
    install_cli_tools
    configure_dock
    cleanup
    show_summary

    print_success "安装完成！"
}

main "$@"
