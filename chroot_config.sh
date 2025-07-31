#!/bin/bash

# Arch Linux 安装脚本模块 - chroot_config.sh

# Chroot 并进行系统配置
configure_system() {
    echo "--> 正在进入Chroot环境并配置系统..."
    
    # 将选择的软件包列表传递给chroot环境
    echo "${SELECTED_PACMAN_APPS[@]}" > /mnt/pacman_selection.txt
    echo "${SELECTED_AUR_APPS[@]}" > /mnt/aur_selection.txt
    echo "$AUR_HELPER" > /mnt/aur_helper.txt

    # 准备要在chroot中运行的脚本
    cat > /mnt/chroot_script.sh <<EOF
#!/bin/bash
set -e

# 时区和本地化
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=zh_CN.UTF-8" > /etc/locale.conf

# 主机名和hosts
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# 设置Root密码
echo "root:$PASSWORD" | chpasswd

# GRUB引导
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# 启用基础网络服务
systemctl enable dhcpcd
systemctl enable NetworkManager

# 创建用户
useradd -m -g users -G wheel "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel

# --- 桌面环境和驱动安装 ---
DE_PACKAGES=""
DISPLAY_MANAGER=""

case "$DESKTOP_ENV" in
    kde) DE_PACKAGES="plasma-meta konsole dolphin"; DISPLAY_MANAGER="sddm";;
    gnome) DE_PACKAGES="gnome gnome-extra"; DISPLAY_MANAGER="gdm";;
    xfce) DE_PACKAGES="xfce4 xfce4-goodies"; DISPLAY_MANAGER="lightdm";;
    cinnamon) DE_PACKAGES="cinnamon nemo-fileroller"; DISPLAY_MANAGER="lightdm";;
    mate) DE_PACKAGES="mate mate-extra"; DISPLAY_MANAGER="lightdm";;
    budgie) DE_PACKAGES="budgie-desktop"; DISPLAY_MANAGER="lightdm";;
    deepin) DE_PACKAGES="deepin deepin-extra"; DISPLAY_MANAGER="lightdm";;
    lxqt) DE_PACKAGES="lxqt"; DISPLAY_MANAGER="sddm";;
    cosmic)
        # Cosmic DE 通常通过 AUR 安装，其主要包为 cosmic-session
        # 这里将其视为一个特殊的 AUR 包，通过 AUR 助手安装
        DE_PACKAGES="" # Cosmic DE 的包将通过 AUR_SELECTION 安装
        DISPLAY_MANAGER="cosmic-greeter" # Cosmic 自己的显示管理器
        echo "警告：COSMIC 桌面环境的安装可能需要较长时间，且可能需要大量内存。"
        echo "请确保您已选择安装 'cosmic-session' AUR 包。"
        ;;
esac

VIDEO_PACKAGES=""
case "$VIDEO_DRIVER" in
    amd) VIDEO_PACKAGES="xf86-video-amdgpu mesa";;
    intel) VIDEO_PACKAGES="xf86-video-intel mesa";;
    nvidia) VIDEO_PACKAGES="nvidia nvidia-utils nvidia-settings";;
    vmware) VIDEO_PACKAGES="xf86-video-vmware mesa open-vm-tools";;
esac

# 读取选择的软件包
read -r -a PACMAN_SELECTION < /pacman_selection.txt
INSTALL_PACKAGES="\$DE_PACKAGES \$VIDEO_PACKAGES \${PACMAN_SELECTION[@]}"

if [ -n "\$DISPLAY_MANAGER" ]; then
    INSTALL_PACKAGES="\$INSTALL_PACKAGES \$DISPLAY_MANAGER"
    if [ "\$DISPLAY_MANAGER" = "lightdm" ]; then
        INSTALL_PACKAGES="\$INSTALL_PACKAGES lightdm-gtk-greeter"
    fi
fi

# 安装软件包
if [ -n "\$DE_PACKAGES" ] || [ \${#PACMAN_SELECTION[@]} -gt 0 ]; then
    pacman -S --noconfirm --needed \$INSTALL_PACKAGES
fi

if [ -n "\$DISPLAY_MANAGER" ]; then
    systemctl enable \$DISPLAY_MANAGER
fi

# 启用 VMware Tools 服务
if [ "$VIDEO_DRIVER" = "vmware" ]; then
    systemctl enable vmtoolsd.service
    systemctl enable vmware-vmblock-fuse.service
fi

# Fcitx5 输入法环境变量
echo "GTK_IM_MODULE=fcitx" >> /etc/environment
echo "QT_IM_MODULE=fcitx" >> /etc/environment
echo "XMODIFIERS=@im=fcitx" >> /etc/environment

# --- AUR 软件包安装 ---
read -r -a AUR_SELECTION < /aur_selection.txt
read -r AUR_HELPER_CHOICE < /aur_helper.txt

if [ \${#AUR_SELECTION[@]} -gt 0 ]; then
    # 为新用户创建安装脚本
    cat > /home/$USERNAME/install_aur.sh <<EOS
#!/bin/bash
set -e
# 安装 git 和 base-devel
sudo pacman -S --noconfirm --needed git base-devel

# 如果选择 paru, 运行 Rust 安装脚本
if [ "$AUR_HELPER_CHOICE" = "paru" ]; then
    sudo pacman -S --noconfirm --needed curl
    # 复制并执行 Rust 安装脚本
    cp /install_rust.sh /home/$USERNAME/install_rust.sh
    chown $USERNAME:users /home/$USERNAME/install_rust.sh
    chmod +x /home/$USERNAME/install_rust.sh
    su - \$USERNAME -c "/home/\$USERNAME/install_rust.sh"
    rm /home/$USERNAME/install_rust.sh
fi

# 安装选定的AUR助手
cd /tmp
if [ "$AUR_HELPER_CHOICE" = "paru" ]; then
    git clone https://aur.archlinux.org/paru.git
    cd paru
else # 默认为 yay
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
fi
makepkg -si --noconfirm
cd .. && rm -rf paru yay-bin
# 安装选定的AUR包
\$AUR_HELPER_CHOICE -S --noconfirm --needed \${AUR_SELECTION[@]}
EOS
    
    chown $USERNAME:users /home/$USERNAME/install_aur.sh
    chmod +x /home/$USERNAME/install_aur.sh
    # 以新用户身份执行脚本
    su - \$USERNAME -c "/home/\$USERNAME/install_aur.sh"
fi

# --- vfox 安装 ---
# 检查 SELECTED_AUR_APPS 中是否包含 "vfox-bin"
if [[ " \${AUR_SELECTION[@]} " =~ " vfox-bin " ]]; then
    # 复制并执行 vfox 安装脚本
    cp /install_vfox.sh /home/$USERNAME/install_vfox.sh
    chown $USERNAME:users /home/$USERNAME/install_vfox.sh
    chmod +x /home/$USERNAME/install_vfox.sh
    su - \$USERNAME -c "/home/\$USERNAME/install_vfox.sh"
    rm /home/$USERNAME/install_vfox.sh
fi

# --- uv 安装 ---
# 检查 SELECTED_AUR_APPS 中是否包含 "uv-bin"
if [[ " \${AUR_SELECTION[@]} " =~ " uv-bin " ]]; then
    # 复制并执行 uv 安装脚本
    cp /install_uv.sh /home/$USERNAME/install_uv.sh
    chown $USERNAME:users /home/$USERNAME/install_uv.sh
    chmod +x /home/$USERNAME/install_uv.sh
    su - \$USERNAME -c "/home/\$USERNAME/install_uv.sh"
    rm /home/$USERNAME/install_uv.sh
fi


EOF

    # 赋予脚本执行权限并执行
    arch-chroot /mnt chmod +x /chroot_script.sh
    arch-chroot /mnt /chroot_script.sh
    
    # 清理临时文件
    rm /mnt/chroot_script.sh /mnt/pacman_selection.txt /mnt/aur_selection.txt /mnt/aur_helper.txt
    rm /mnt/install_rust.sh /mnt/install_vfox.sh /mnt/install_uv.sh # 删除复制到 /mnt 的脚本
    echo "--> Chroot配置完成。"
}