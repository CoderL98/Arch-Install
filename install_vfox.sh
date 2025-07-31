#!/bin/bash
set -e

# vfox 安装脚本

echo "--> 正在安装 vfox..."
# 使用 vfox 官方脚本安装
curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash

echo "--> 配置 vfox shell 环境..."
# 为 bash 配置
if [ -f "$HOME/.bashrc" ]; then
    echo 'eval "$(vfox activate bash)"' >> "$HOME/.bashrc"
fi
# 为 zsh 配置
if [ -f "$HOME/.zshrc" ]; then
    echo 'eval "$(vfox activate zsh)"' >> "$HOME/.zshrc"
fi
# 为 fish 配置
if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish"
    echo 'vfox activate fish | source' >> "$HOME/.config/fish/config.fish"
fi
# 为 nushell 配置 (需要用户手动执行以保存配置)
echo "请注意：对于 Nushell，您可能需要手动执行以下命令以保存配置："
echo "vfox activate nushell \$nu.default-config-dir | save --append \$nu.config-path"
echo ""

echo "--> vfox 安装和配置完成。"