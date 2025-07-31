#!/bin/bash

# Arch Linux 自动化安装脚本
# 主入口脚本 - v13 (模块化拆分，集成 Rust, vfox, uv 独立安装脚本，并加入 Cosmic DE 选项)

# --- 全局配置 ---
# 在这里预设值可以实现全自动安装
# 如果留空，脚本将以交互模式询问

# 系统设置
HOSTNAME=""
USERNAME=""
PASSWORD="" # 警告：将密码明文保存在脚本中存在安全风险
TIMEZONE="Asia/Shanghai"

# 磁盘和分区
DISK_TARGET="" # 目标磁盘，例如 /dev/sda。留空则进入交互选择模式
EFI_SIZE="512M"
SWAP_SIZE="4G" # 留空则不创建Swap分区

# 桌面环境 ('kde', 'gnome', 'xfce', 'cinnamon', 'mate', 'budgie', 'deepin', 'lxqt', 'cosmic', 'none')
DESKTOP_ENV="kde"

# 显卡驱动 ('intel', 'amd', 'nvidia', 'vmware', 'none')
VIDEO_DRIVER="amd"

# AUR 助手 ('yay', 'paru')
AUR_HELPER="paru"

# --- 软件包选择 ---

# Pacman packages
pacman_apps=(
    "neovim" "Neovim (高级文本编辑器)" "OFF"
    "gimp" "GIMP (图像处理软件)" "OFF"
    "shotcut" "Shotcut (视频编辑器)" "OFF"
    "flameshot" "Flameshot (截图工具)" "OFF"
    "discord" "Discord (聊天应用)" "OFF"
    "onlyoffice-desktopeditors" "ONLYOFFICE (办公套件)" "OFF"
)

# AUR packages
aur_apps=(
    "dingtalk-bin" "钉钉 (DingTalk)" "OFF"
    "wechat-universal-bwrap" "微信 (WeChat) (bwrap沙盒版)" "OFF"
    "jetbrains-toolbox" "JetBrains Toolbox" "OFF"
    "apifox-bin" "Apifox" "OFF"
    "obsidian" "Obsidian" "OFF"
    "telegram-desktop-bin" "Telegram Desktop" "OFF"
    "v2rayn-bin" "V2RayN (GUI for V2Ray)" "OFF"
    "vmware-workstation" "VMware Workstation" "OFF"
    "spotify" "Spotify" "OFF"
    "visual-studio-code-bin" "Visual Studio Code" "OFF"
    "google-chrome" "Google Chrome" "OFF"
    "floorp-bin" "Floorp Browser" "OFF"
    "tabby-bin" "Tabby Terminal" "OFF"
    "microsoft-edge-stable-bin" "Microsoft Edge" "OFF"
    "waterfox-bin" "Waterfox Browser" "OFF"
    "vfox-bin" "vfox (Version Manager)" "OFF"
    "bilibili-bin" "哔哩哔哩 (Bilibili) 客户端" "OFF"
    "uv-bin" "uv (Python 包管理器)" "OFF"
    "cosmic-session" "COSMIC 桌面环境 (AUR)" "OFF" # 添加 Cosmic DE 到 AUR 列表
)

# 用于存储用户选择的数组
SELECTED_PACMAN_APPS=()
SELECTED_AUR_APPS=()

# --- 引入子脚本 ---
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/partition_and_mount.sh"
source "$(dirname "$0")/base_system_install.sh"
source "$(dirname "$0")/chroot_config.sh"


# 主函数
main() {
    print_welcome
    check_root
    select_packages # 在交互式设置之前选择软件包，因为 dialog 需要在 chroot 环境外运行
    interactive_setup
    
    read -p "配置确认完毕，按任意键开始安装，或按 Ctrl+C 取消。" -n 1 -r
    echo

    partition_disk
    mount_and_create_subvolumes
    install_base
    generate_fstab

    # 复制 Rust, vfox 和 uv 安装脚本到 /mnt
    cp "$(dirname "$0")/install_rust.sh" /mnt/install_rust.sh
    cp "$(dirname "$0")/install_vfox.sh" /mnt/install_vfox.sh
    cp "$(dirname "$0")/install_uv.sh" /mnt/install_uv.sh

    configure_system

    echo "********************************************"
    echo "*      Arch Linux 安装完成！             *"
    echo "*      现在可以卸载并重启系统。          *"
    echo "*      # umount -R /mnt                   *"
    echo "*      # reboot                           *"
    echo "********************************************"
}

# 运行主函数
main