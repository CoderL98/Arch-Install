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
    local DIALOG_OUTPUT_PACMAN="/tmp/pacman_choices_output.$$"
    local DIALOG_OUTPUT_AUR="/tmp/aur_choices_output.$$"
    trap 'rm -f "$DIALOG_OUTPUT_PACMAN" "$DIALOG_OUTPUT_AUR"' EXIT

    # Pacman
    local pacman_choices=()
    for i in $(seq 0 $(( ${#pacman_apps[@]} / 3 - 1 )) ); do
        local idx=$((i * 3))
        pacman_choices+=("${pacman_apps[idx]}" "${pacman_apps[idx+1]}" "${pacman_apps[idx+2]}")
    done
    dialog --checklist "选择要从 Pacman 安装的软件 (使用空格键选择):" 20 70 15 "${pacman_choices[@]}" 2> "$DIALOG_OUTPUT_PACMAN"
    while read -r choice; do
        SELECTED_PACMAN_APPS+=("$choice")
    done < "$DIALOG_OUTPUT_PACMAN"

    # AUR
    local aur_choices=()
    for i in $(seq 0 $(( ${#aur_apps[@]} / 3 - 1 )) ); do
        local idx=$((i * 3))
        aur_choices+=("${aur_apps[idx]}" "${aur_apps[idx+1]}" "${aur_apps[idx+2]}")
    done
    dialog --checklist "选择要从 AUR 安装的软件 (使用空格键选择):" 20 70 15 "${aur_choices[@]}" 2> "$DIALOG_OUTPUT_AUR"
    while read -r choice; do
        SELECTED_AUR_APPS+=("$choice")
    done < "$DIALOG_OUTPUT_AUR"
    
    rm -f "$DIALOG_OUTPUT_PACMAN" "$DIALOG_OUTPUT_AUR"
    trap - EXIT
}


# 交互式配置（如果变量为空）
interactive_setup() {
    # --- Dialog 模式 ---
    local DIALOG_OUTPUT="/tmp/dialog_output.$$"
    trap 'rm -f "$DIALOG_OUTPUT"' EXIT

    # 交互式选择磁盘
    if [ -z "$DISK_TARGET" ]; then
        mapfile -t options < <(lsblk -dn -o NAME,SIZE,TYPE | awk '$3=="disk" {print "/dev/"$1, "("$2")"}')
        dialog --title "选择目标磁盘" --menu "请选择要安装 Arch Linux 的磁盘:" 15 60 4 "${options[@]}" 2> "$DIALOG_OUTPUT"
        DISK_TARGET=$(cat "$DIALOG_OUTPUT")
        if [ -z "$DISK_TARGET" ]; then echo "错误：未选择磁盘。"; exit 1; fi
    fi
    dialog --title "确认磁盘" --msgbox "将在磁盘 $DISK_TARGET 上进行安装。" 8 40

    # 交互式获取其他配置
    [ -z "$HOSTNAME" ] && HOSTNAME=$(dialog --title "设置主机名" --inputbox "请输入主机名:" 8 40 --stdout)
    [ -z "$USERNAME" ] && USERNAME=$(dialog --title "创建用户" --inputbox "请输入新用户名:" 8 40 --stdout)
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(dialog --title "设置密码" --passwordbox "请输入用户 '$USERNAME' 的密码:" 8 40 --stdout)
        local pass2=$(dialog --title "确认密码" --passwordbox "请再次输入密码:" 8 40 --stdout)
        if [ "$PASSWORD" != "$pass2" ]; then
            dialog --title "错误" --msgbox "两次输入的密码不匹配！" 8 40
            exit 1
        fi
    fi

    # 交互式设置SWAP分区大小
    if [ -z "$SWAP_SIZE" ]; then
        local MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local MEM_TOTAL_GB=$(( (MEM_TOTAL_KB / 1024 / 1024) + 1 ))
        local USER_SWAP_SIZE=$(dialog --title "设置SWAP" --inputbox "请输入SWAP分区大小 (单位GB, 留空则默认和内存大小一致):" 8 60 "$MEM_TOTAL_GB" --stdout)
        if [ -z "$USER_SWAP_SIZE" ]; then
            SWAP_SIZE="${MEM_TOTAL_GB}G"
        elif [[ "$USER_SWAP_SIZE" =~ ^[0-9]+$ ]]; then
            SWAP_SIZE="${USER_SWAP_SIZE}G"
        else
            dialog --title "警告" --msgbox "无效的SWAP大小输入，将使用默认值 ${MEM_TOTAL_GB}GB。" 8 60
            SWAP_SIZE="${MEM_TOTAL_GB}G"
        fi
    fi
    dialog --title "SWAP确认" --msgbox "SWAP分区大小将设置为: $SWAP_SIZE" 8 40
    
    trap - EXIT
}