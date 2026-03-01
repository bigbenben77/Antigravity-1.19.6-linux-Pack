#!/bin/bash

# Google Antigravity IDE Linux 安装脚本
# 版本: 1.107.0
# 用法: ./install-antigravity.sh [压缩包路径]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
APP_NAME="Antigravity"
APP_NAME_LOWER="antigravity"
INSTALL_DIR="/opt/$APP_NAME"
BIN_LINK="/usr/local/bin/$APP_NAME_LOWER"
DESKTOP_FILE="/usr/share/applications/$APP_NAME_LOWER.desktop"
ICON_DIR="/usr/share/pixmaps"

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}"
    echo "用法: sudo $0 [压缩包路径]"
    exit 1
fi

# 获取压缩包路径
ARCHIVE_PATH="${1:-./antigravity-linux.tar.gz}"

# 检查文件是否存在
if [ ! -f "$ARCHIVE_PATH" ]; then
    echo -e "${RED}错误: 找不到文件 $ARCHIVE_PATH${NC}"
    echo "请确保压缩包存在，或指定正确的路径"
    exit 1
fi

# 检查文件类型
if ! file "$ARCHIVE_PATH" | grep -qE '(gzip|tar)'; then
    echo -e "${YELLOW}警告: 文件可能不是有效的 tar.gz 压缩包${NC}"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${BLUE}=== Google Antigravity IDE 安装脚本 ===${NC}"
echo

# 1. 清理旧版本
echo -e "${BLUE}[1/6] 清理旧版本...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo "  发现旧版本，正在移除..."
    rm -rf "$INSTALL_DIR"
fi
if [ -L "$BIN_LINK" ]; then
    rm -f "$BIN_LINK"
fi
if [ -f "$DESKTOP_FILE" ]; then
    rm -f "$DESKTOP_FILE"
fi

# 2. 创建安装目录
echo -e "${BLUE}[2/6] 创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"
echo "  安装位置: $INSTALL_DIR"

# 3. 解压文件
echo -e "${BLUE}[3/6] 解压文件中...${NC}"
echo "  源文件: $ARCHIVE_PATH"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 解压到临时目录
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_DIR" --strip-components=1

# 检查解压结果
if [ ! -f "$TEMP_DIR/antigravity" ]; then
    echo -e "${RED}错误: 解压失败，找不到主程序${NC}"
    exit 1
fi

# 移动到安装目录
cp -r "$TEMP_DIR"/* "$INSTALL_DIR/"
echo -e "  ${GREEN}✓ 解压完成${NC}"

# 4. 设置权限
echo -e "${BLUE}[4/6] 设置权限...${NC}"
chmod -R 755 "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/antigravity"

# chrome-sandbox 需要特殊权限（如果存在）
if [ -f "$INSTALL_DIR/chrome-sandbox" ]; then
    chown root:root "$INSTALL_DIR/chrome-sandbox"
    chmod 4755 "$INSTALL_DIR/chrome-sandbox"
    echo "  已设置 chrome-sandbox 权限"
fi
echo -e "  ${GREEN}✓ 权限设置完成${NC}"

# 5. 创建命令链接
echo -e "${BLUE}[5/6] 创建命令链接...${NC}"
ln -sf "$INSTALL_DIR/antigravity" "$BIN_LINK"
echo "  命令链接: $BIN_LINK"
echo -e "  ${GREEN}✓ 现在可以直接使用 'antigravity' 命令启动${NC}"

# 6. 创建桌面快捷方式
echo -e "${BLUE}[6/6] 创建桌面快捷方式...${NC}"

# 查找图标
ICON_PATH=""
if [ -f "$INSTALL_DIR/resources/app/resources/linux/code.png" ]; then
    ICON_PATH="$INSTALL_DIR/resources/app/resources/linux/code.png"
    cp "$ICON_PATH" "$ICON_DIR/$APP_NAME_LOWER.png"
elif [ -f "$INSTALL_DIR/antigravity.png" ]; then
    ICON_PATH="$INSTALL_DIR/antigravity.png"
    cp "$ICON_PATH" "$ICON_DIR/$APP_NAME_LOWER.png"
fi

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Google Antigravity
Comment=AI-powered IDE by Google
GenericName=Text Editor
Exec=$INSTALL_DIR/antigravity %F
Type=Application
StartupNotify=false
StartupWMClass=antigravity
Categories=Utility;TextEditor;Development;IDE;
MimeType=text/plain;application/x-antigravity-workspace;
Actions=new-empty-window;
Keywords=google;antigravity;ai;ide;code;editor;
EOF

if [ -n "$ICON_PATH" ]; then
    echo "Icon=$ICON_DIR/$APP_NAME_LOWER.png" >> "$DESKTOP_FILE"
fi

cat >> "$DESKTOP_FILE" << EOF

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$INSTALL_DIR/antigravity --new-window %F
Icon=$APP_NAME_LOWER
EOF

chmod 644 "$DESKTOP_FILE"
echo "  桌面文件: $DESKTOP_FILE"
echo -e "  ${GREEN}✓ 快捷方式创建完成${NC}"

echo
# 更新桌面数据库
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database &> /dev/null || true
fi

# 7. 创建卸载脚本
echo -e "${BLUE}[额外] 创建卸载脚本...${NC}"
UNINSTALL_SCRIPT="$INSTALL_DIR/uninstall.sh"
cat > "$UNINSTALL_SCRIPT" << 'EOF'
#!/bin/bash
# Antigravity 卸载脚本

if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行卸载脚本"
    exit 1
fi

echo "正在卸载 Google Antigravity..."

INSTALL_DIR="/opt/Antigravity"
BIN_LINK="/usr/local/bin/antigravity"
DESKTOP_FILE="/usr/share/applications/antigravity.desktop"
ICON_FILE="/usr/share/pixmaps/antigravity.png"

rm -rf "$INSTALL_DIR"
rm -f "$BIN_LINK"
rm -f "$DESKTOP_FILE"
rm -f "$ICON_FILE"

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database &> /dev/null || true
fi

echo "✓ Antigravity 已卸载"
EOF
chmod +x "$UNINSTALL_SCRIPT"
echo "  卸载脚本: $UNINSTALL_SCRIPT"

echo
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  ✓ Google Antigravity 安装成功！${NC}"
echo -e "${GREEN}=======================================${NC}"
echo
echo "启动方式:"
echo "  1. 命令行: antigravity"
echo "  2. 应用菜单: Google Antigravity"
echo
echo "其他操作:"
echo "  卸载: sudo $UNINSTALL_SCRIPT"
echo
echo -e "${YELLOW}注意: 这是预览版本，使用时会收集交互数据${NC}"
echo -e "详细信息请查看: $INSTALL_DIR/LICENSE.txt"
