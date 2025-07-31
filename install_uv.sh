#!/bin/bash
set -e

# uv 安装脚本

echo "--> 正在安装 uv..."

# 使用 uv 官方安装脚本
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "--> uv 安装完成。"