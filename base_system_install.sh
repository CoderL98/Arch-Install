#!/bin/bash

# Arch Linux 安装脚本模块 - base_system_install.sh

# 安装基本系统
install_base() {
    echo "--> 正在选择镜像源..."
    reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    
    echo "--> 正在安装基本系统..."
    pacstrap /mnt base base-devel linux linux-firmware nano vim dhcpcd networkmanager grub efibootmgr btrfs-progs dialog curl
}

# 生成 fstab
generate_fstab() {
    echo "--> 正在生成fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    sed -i 's/subvolid=[0-9]*,//g' /mnt/etc/fstab
}