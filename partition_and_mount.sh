#!/bin/bash

# Arch Linux 安装脚本模块 - partition_and_mount.sh

# 磁盘分区
partition_disk() {
    # 在函数开始时启用错误即停，确保任何命令失败都会中止脚本
    set -e
    
    echo "--> 正在对 $DISK_TARGET 进行分区..."
    
    # 清理和创建GPT
    echo "执行: wipefs -a \"$DISK_TARGET\""
    wipefs -a "$DISK_TARGET"
    echo "执行: sgdisk -Z \"$DISK_TARGET\""
    sgdisk -Z "$DISK_TARGET"
    echo "执行: sgdisk -g \"$DISK_TARGET\""
    sgdisk -g "$DISK_TARGET"

    # 创建分区
    echo "执行: sgdisk -n 1:0:+\"$EFI_SIZE\" -t 1:ef00 -c 1:\"EFI System Partition\""
    sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 -c 1:"EFI System Partition"
    
    if [ -n "$SWAP_SIZE" ]; then
        echo "执行: sgdisk -n 2:0:+\"$SWAP_SIZE\" -t 2:8200 -c 2:\"Linux Swap\""
        sgdisk -n 2:0:+"$SWAP_SIZE" -t 2:8200 -c 2:"Linux Swap"
        echo "执行: sgdisk -n 3:0:0 -t 3:8300 -c 3:\"Linux Root (Btrfs)\""
        sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux Root (Btrfs)"
        if [[ $DISK_TARGET == /dev/nvme* || $DISK_TARGET == /dev/mmcblk* ]]; then
            EFI_PART="${DISK_TARGET}p1"
            SWAP_PART="${DISK_TARGET}p2"
            ROOT_PART="${DISK_TARGET}p3"
        else
            EFI_PART="${DISK_TARGET}1"
            SWAP_PART="${DISK_TARGET}2"
            ROOT_PART="${DISK_TARGET}3"
        fi
    else
        echo "执行: sgdisk -n 2:0:0 -t 2:8300 -c 2:\"Linux Root (Btrfs)\""
        sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux Root (Btrfs)"
        if [[ $DISK_TARGET == /dev/nvme* || $DISK_TARGET == /dev/mmcblk* ]]; then
            EFI_PART="${DISK_TARGET}p1"
            ROOT_PART="${DISK_TARGET}p2"
        else
            EFI_PART="${DISK_TARGET}1"
            ROOT_PART="${DISK_TARGET}2"
        fi
    fi

    # 验证分区结果
    echo "--> 分区命令执行完毕，正在验证分区表..."
    sgdisk -p "$DISK_TARGET"

    partprobe "$DISK_TARGET"
    
    # 等待分区设备节点创建
    echo "--> 正在等待分区设备创建..."
    local all_parts_found=0
    for i in {1..10}; do
        # 检查所有必需的分区是否存在
        if [ -b "$EFI_PART" ] && [ -b "$ROOT_PART" ] && { [ -z "$SWAP_PART" ] || [ -b "$SWAP_PART" ]; }; then
            all_parts_found=1
            break
        fi
        echo "    ...等待中 (尝试 $i/10)"
        sleep 1
    done

    if [ "$all_parts_found" -eq 0 ]; then
        echo "错误: 分区设备在10秒后仍未创建。请检查 dmesg 输出。"
        ls -l /dev/ | grep "$(basename "$DISK_TARGET")"
        exit 1
    fi
    echo "--> 所有分区设备已找到。"
    
    echo "--> 正在格式化分区..."
    mkfs.fat -F 32 "$EFI_PART"
    [ -n "$SWAP_PART" ] && mkswap "$SWAP_PART"
    mkfs.btrfs -f -L ArchRoot "$ROOT_PART"
    echo "--> 分区完成。"
    
    # 在函数结束时恢复默认行为
    set +e
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