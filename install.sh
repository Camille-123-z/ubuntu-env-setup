#!/usr/bin/env bash
# =============================================================================
#  Ubuntu 22.04 开发环境一键安装脚本
#  安装内容：中文支持(中文字体 + fcitx5 拼音输入法 + zh_CN.UTF-8)、
#            Google Chrome、Visual Studio Code、CuteCom(串口调试助手)、
#            Terminator(多窗口终端)
#
#  用法：
#      sudo bash install.sh
#      # 或
#      chmod +x install.sh && sudo ./install.sh
#
#  可在下方「配置区」按需开关各组件。脚本可重复执行(幂等)。
# =============================================================================
set -euo pipefail

# --------------------------- 配置区 ---------------------------
INSTALL_CHINESE=true      # 中文支持：中文字体 + fcitx5 拼音输入法 + zh_CN.UTF-8 locale
SET_ZH_LOCALE=false       # true=系统界面也切成中文(重启生效)；false=仅装支持、不切界面语言
INSTALL_CHROME=true       # Google Chrome 浏览器
INSTALL_VSCODE=true       # Visual Studio Code
INSTALL_CUTECOM=true      # CuteCom 串口调试助手
INSTALL_TERMINATOR=true   # Terminator 终端
# --------------------------------------------------------------

# 颜色与日志
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

# 权限检查
if [[ $EUID -ne 0 ]]; then
    fail "请用 root 权限运行：sudo bash $0"
fi

export DEBIAN_FRONTEND=noninteractive
ARCH="$(dpkg --print-architecture)"                                  # amd64 / arm64 ...
RUN_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"

info "系统架构: ${ARCH}   实际用户: ${RUN_USER:-root}"

# --------------------------- 基础依赖 ---------------------------
info "更新软件源并安装基础依赖..."
apt-get update
apt-get install -y \
    curl wget gnupg2 ca-certificates apt-transport-https \
    software-properties-common lsb-release
ok "基础依赖就绪"

# --------------------------- 中文支持 ---------------------------
install_chinese() {
    info "安装中文支持(字体 + 输入法 + locale)..."
    apt-get install -y \
        language-pack-zh-hans language-pack-gnome-zh-hans \
        fonts-noto-cjk fonts-wqy-microhei fonts-wqy-zenhei \
        fcitx5 fcitx5-chinese-addons \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 \
        fcitx5-config-qt locales

    # 生成 zh_CN.UTF-8 locale
    locale-gen zh_CN.UTF-8 >/dev/null 2>&1 || true

    # 输入法环境变量(系统级，避免部分程序无法调出输入法)
    if ! grep -q 'GTK_IM_MODULE' /etc/environment 2>/dev/null; then
        {
            echo ''
            echo '# fcitx5 中文输入法'
            echo 'GTK_IM_MODULE=fcitx'
            echo 'QT_IM_MODULE=fcitx'
            echo 'XMODIFIERS=@im=fcitx'
        } >> /etc/environment
        ok "已写入 fcitx5 输入法环境变量"
    else
        info "输入法环境变量已存在，跳过"
    fi

    # 尝试把默认输入法框架切换为 fcitx5(作用于实际用户，需图形会话)
    if [[ -n "$RUN_USER" ]]; then
        if command -v im-config >/dev/null 2>&1; then
            sudo -H -u "$RUN_USER" im-config -n fcitx5 2>/dev/null \
                && ok "输入法框架已切换为 fcitx5" \
                || warn "未能自动切换输入法框架，请登录后手动执行: im-config -n fcitx5"
        fi
    fi

    # 可选：切换系统默认语言为中文
    if [[ "$SET_ZH_LOCALE" == true ]]; then
        update-locale LANG=zh_CN.UTF-8
        ok "系统默认语言已设为 zh_CN.UTF-8(重启生效)"
    else
        info "未切换系统默认语言(如需中文界面，把配置区 SET_ZH_LOCALE 改为 true)"
    fi
    ok "中文支持安装完成(输入法需重启/重新登录后生效)"
}

# --------------------------- Google Chrome ---------------------------
install_chrome() {
    if [[ "$ARCH" != "amd64" ]]; then
        warn "Google Chrome 官方仅提供 amd64 的 .deb，当前架构 ${ARCH} 已跳过"
        return 0
    fi
    info "安装 Google Chrome..."
    local deb="/tmp/google-chrome-stable_current_amd64.deb"
    info "下载 Chrome 安装包(国内需先开代理，如 export https_proxy=http://127.0.0.1:7897)"
    if ! wget -q -O "$deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb; then
        fail "Chrome 下载失败，请检查网络/代理后重试"
    fi
    apt-get install -y "$deb"
    rm -f "$deb"
    ok "Google Chrome 安装完成"
}

# --------------------------- VS Code ---------------------------
install_vscode() {
    info "安装 Visual Studio Code..."
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor --yes -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list
    apt-get update
    apt-get install -y code
    ok "Visual Studio Code 安装完成"
}

# --------------------------- CuteCom ---------------------------
install_cutecom() {
    info "安装 CuteCom(串口调试助手)..."
    # cutecom 位于 universe 源
    if ! apt-cache show cutecom >/dev/null 2>&1; then
        add-apt-repository -y universe
        apt-get update
    fi
    apt-get install -y cutecom
    # 串口权限：把实际用户加入 dialout 组
    if [[ -n "$RUN_USER" ]]; then
        usermod -aG dialout,plugdev "$RUN_USER" 2>/dev/null \
            && ok "已将用户 ${RUN_USER} 加入 dialout/plugdev 组(重新登录生效)"
    fi
    ok "CuteCom 安装完成"
}

# --------------------------- Terminator ---------------------------
install_terminator() {
    info "安装 Terminator(终端)..."
    apt-get install -y terminator
    ok "Terminator 安装完成"
}

# --------------------------- 执行 ---------------------------
echo
echo "============================================================"
info "开始安装..."
echo "============================================================"

[[ "$INSTALL_CHINESE"    == true ]] && install_chinese
[[ "$INSTALL_CHROME"     == true ]] && install_chrome
[[ "$INSTALL_VSCODE"     == true ]] && install_vscode
[[ "$INSTALL_CUTECOM"    == true ]] && install_cutecom
[[ "$INSTALL_TERMINATOR" == true ]] && install_terminator

echo
echo "============================================================"
ok "全部安装完成！"
echo "============================================================"
cat <<'EOF'
后续步骤：
  1. 重启系统(或重新登录)使中文输入法 / 串口权限生效。
  2. 登录后若 fcitx5 未自动启动，运行: fcitx5 -d
     并在「设置 → 键盘/输入法」确认「中文(智能拼音)」已添加。
  3. CuteCom 打开串口前，确认设备出现在 /dev/ttyUSB* 或 /dev/ttyACM*。
  4. 如需把系统界面语言切为中文：重跑 sudo bash install.sh，
     并把配置区 SET_ZH_LOCALE 改为 true。
EOF
