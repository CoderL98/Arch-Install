#!/bin/bash
set -e

# Rust 安装脚本
# 使用官方 rustup.rs 脚本安装 Rust 工具链

echo "--> 正在安装 Rust 工具链..."
# 确保 curl 已安装
sudo pacman -S --noconfirm --needed curl

# 使用 rustup 官方脚本安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 将 cargo 的 bin 目录添加到 PATH
source "$HOME/.cargo/env"

echo "--> Rust 工具链安装完成。"