#!/bin/bash

# Arch Linux 安装脚本模块 - partition_and_mount.sh

# 磁盘分区
partition_disk() {
    echo "--> 正在对 $DISK_TARGET 进行分区..."
    wipefs -a "$DISK_TARGET"
    sgdisk -Z "$DISK_TARGET"
    sgdisk -g "$DISK_TARGET"

    sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 -c 1:"EFI System Partition"
    
    if [ -n "$SWAP_SIZE" ]; then
        sgdisk -n 2:0:+"$SWAP_SIZE" -t 2:8200 -c 2:"Linux Swap"
        sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux Root (Btrfs)"
        EFI_PART="${DISK_TARGET}p1"
        SWAP_PART="${DISK_TARGET}p2"
        ROOT_PART="${DISK_TARGET}p3"
    else
        sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux Root (Btrfs)"
        EFI_PART="${DISK_TARGET}p1"
        ROOT_PART="${DISK_TARGET}p2"
    fi

    partprobe "$DISK_TARGET"
    
    echo "--> 正在格式化分区..."
    mkfs.fat -F 32 "$EFI_PART"
    [ -n "$SWAP_PART" ] && mkswap "$SWAP_PART"
    mkfs.btrfs -f -L ArchRoot "$ROOT_PART"
    echo "--> 分区完成。"
}

# 挂载文件系统和创建Btrfs子卷
mount_and_create_subvolumes() {
    echo "--> 正在挂载文件系统并创建Btrfs子卷..."
    mount "$ROOT_PART" /mnt
    
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@var_log
    
    umount /mnt

    BTRFS_OPTS="noatime,compress=zstd,space_cache=v2"
    mount -o $BTRFS_OPTS,subvol=@ "$ROOT_PART" /mnt
    mkdir -p /mnt/{boot/efi,home,.snapshots,var/log}

    mount -o $BTRFS_OPTS,subvol=@home "$ROOT_PART" /mnt/home
    mount -o $BTRFS_OPTS,subvol=@snapshots "$ROOT_PART" /mnt/.snapshots
    mount -o $BTRFS_OPTS,subvol=@var_log "$ROOT_PART" /mnt/var/log
    mount "$EFI_PART" /mnt/boot/efi
    [ -n "$SWAP_PART" ] && swapon "$SWAP_PART"
    echo "--> 文件系统挂载完成。"
}