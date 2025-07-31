#!/bin/bash

# Arch Linux 安装脚本库 - lib.sh

# 欢迎和警告信息
print_welcome() {
    echo "********************************************"
    echo "* 欢迎使用 Arch Linux 自动化安装脚本 v10 *"
    echo "*  请在运行前仔细阅读并配置脚本中的变量  *"
    echo "*           风险自负！                   *"
    echo "********************************************"
    echo ""
    sleep 3
}

# 检查Root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误：请以root用户运行此脚本。"
        exit 1
    fi
}

# 交互式选择软件包
select_packages() {
    echo "--> 配置可选软件包安装:"
    # 使用 dialog 创建菜单，如果 dialog 不存在则回退到简单模式
    if command -v dialog &> /dev/null; then
        # Pacman
        pacman_choices=()
        for i in "${!pacman_apps[@]}"; do
            idx=$((i * 3))
            pacman_choices+=("${pacman_apps[idx]}" "${pacman_apps[idx+1]}" "${pacman_apps[idx+2]}")
        done
        dialog --checklist "选择要从 Pacman 安装的软件 (使用空格键选择):" 20 70 15 "${pacman_choices[@]}" 2> /tmp/pacman_choices_output
        while read -r choice; do
            SELECTED_PACMAN_APPS+=("$choice")
        done < /tmp/pacman_choices_output

        # AUR
        aur_choices=()
         for i in "${!aur_apps[@]}"; do
            idx=$((i * 3))
            aur_choices+=("${aur_apps[idx]}" "${aur_apps[idx+1]}" "${aur_apps[idx+2]}")
        done
        dialog --checklist "选择要从 AUR 安装的软件 (使用空格键选择):" 20 70 15 "${aur_choices[@]}" 2> /tmp/aur_choices_output
        while read -r choice; do
            SELECTED_AUR_APPS+=("$choice")
        done < /tmp/aur_choices_output
        rm -f /tmp/pacman_choices_output /tmp/aur_choices_output
    else
        echo "警告: 'dialog' 未安装，将使用简单的文本模式。"
        echo "选择 Pacman 软件包 (输入数字, 以空格分隔):"
        for i in "${!pacman_apps[@]}"; do
            idx=$((i * 3))
            echo "$((i/3+1))) ${pacman_apps[idx+1]}"
        done
        read -r -p "选择: " choices_input
        for choice_num in $choices_input; do
            idx=$(((choice_num-1) * 3))
            SELECTED_PACMAN_APPS+=("${pacman_apps[idx]}")
        done

        echo "选择 AUR 软件包 (输入数字, 以空格分隔):"
        for i in "${!aur_apps[@]}"; do
            idx=$((i * 3))
            echo "$((i/3+1))) ${aur_apps[idx+1]}"
        done
        read -r -p "选择: " choices_input
        for choice_num in $choices_input; do
            idx=$(((choice_num-1) * 3))
            SELECTED_AUR_APPS+=("${aur_apps[idx]}")
        done
    fi
}


# 交互式配置（如果变量为空）
interactive_setup() {
    # 交互式选择磁盘
    if [ -z "$DISK_TARGET" ]; then
        echo "可用磁盘列表:"
        mapfile -t options < <(lsblk -dn -o NAME,SIZE,TYPE | awk '$3=="disk" {print "/dev/"$1 " ("$2")"}')
        PS3="请选择要安装Arch Linux的磁盘: "
        select DISK_INFO in "${options[@]}"; do
            if [[ -n "$DISK_INFO" ]]; then
                DISK_TARGET=$(echo "$DISK_INFO" | awk '{print $1}')
                break
            else
                echo "无效的选择，请重新选择。"
            fi
        done
    fi
    echo "将在磁盘 $DISK_TARGET 上进行安装。"
    
    # 交互式获取其他配置
    [ -z "$HOSTNAME" ] && read -p "请输入主机名: " HOSTNAME
    [ -z "$USERNAME" ] && read -p "请输入新用户名: " USERNAME
    [ -z "$PASSWORD" ] && read -sp "请输入用户密码: " PASSWORD && echo
}