#!/usr/bin/env bash

# sdcard_prep.sh - Prepare an SD/microSD card with a single, aligned FAT32 partition.
#
# WARNING: This script DESTROYS all data on the target device.
#
# It will:
#   - sanity-check the target device
#   - refuse to touch devices larger than 256 GiB unless --i-am-not-a-dumbass is passed
#   - unmount any existing partitions on the device
#   - wipe the first 8 MiB (MBR, old partition tables, remnants)
#   - create a single MBR partition:
#       * starts at 4 MiB (sector 8192 assuming 512-byte sectors)
#       * uses the rest of the device
#       * type 0x0C (W95 FAT32 LBA)
#   - format it as FAT32 with 16 KiB clusters (-s 32)
#
# Usage:
#   sudo ./sdcard_prep.sh /dev/sdX [--i-am-not-a-dumbass]
#
# Notes:
#   - This is Linux-only and assumes 512-byte logical sectors.
#   - Adjust MKFS_OPTS below if you want different cluster sizes or labels.

set -euo pipefail

MKFS_OPTS="-F 32 -s 32"   # FAT32, 16 KiB clusters (32 * 512-byte sectors)
DEFAULT_LABEL="SDCARD"

usage() {
    cat << USAGE_EOF
Usage: $0 /dev/sdX [--i-am-not-a-dumbass]

Prepare an SD/microSD card with a single, 4 MiB-aligned FAT32 partition.

  /dev/sdX              Target block device (NOT a partition, e.g. /dev/sdb)
  --i-am-not-a-dumbass  Allow operation on devices > 256 GiB

WARNING: This script will destroy all data on the target device.
USAGE_EOF
}

_die() {
    echo "ERROR: $*" >&2
    exit 1
}

# --- Parse arguments ------------------------------------------------------

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 1
fi

FORCE=0
DEV=""

for arg in "$@"; do
    case "$arg" in
        --i-am-not-a-dumbass)
            FORCE=1
            ;;
        /dev/*)
            DEV="$arg"
            ;;
        *)
            _die "Unknown argument: $arg"
            ;;
    esac
done

if [[ -z "$DEV" ]]; then
    _die "No device specified. Example: $0 /dev/sdb"
fi

# --- Basic sanity checks --------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    _die "This script must be run as root."
fi

if [[ ! -b "$DEV" ]]; then
    _die "$DEV is not a block device."
fi

# Reject partitions like /dev/sdb1, /dev/mmcblk0p1, etc.
if [[ "$DEV" =~ [0-9]$ || "$DEV" =~ p[0-9]+$ ]]; then
    _die "$DEV looks like a partition. Use the whole-disk node (e.g. /dev/sdb)."
fi

DEV_BASENAME=$(basename "$DEV")

if [[ ! -e "/sys/block/$DEV_BASENAME/size" ]]; then
    ALT=$(basename "$(readlink -f "/sys/class/block/$DEV_BASENAME")")
    if [[ -e "/sys/block/$ALT/size" ]]; then
        DEV_BASENAME="$ALT"
    else
        _die "Unable to resolve size information for $DEV_BASENAME."
    fi
fi

SECTORS=$(<"/sys/block/$DEV_BASENAME/size")
BYTES=$(( SECTORS * 512 ))
GIB=$(( BYTES / 1024 / 1024 / 1024 ))

if (( GIB <= 0 )); then
    _die "Device size appears to be zero or invalid ($SECTORS sectors)."
fi

if (( GIB > 256 && FORCE == 0 )); then
    _die "Refusing to operate on devices larger than 256 GiB (${GIB} GiB). Use --i-am-not-a-dumbass to override."
fi

echo "Target device: $DEV (${GIB} GiB)"
echo "This will DESTROY all data on $DEV."
read -r -p "Type 'YES' to continue: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

# --- Unmount existing partitions -----------------------------------------

echo ">> Unmounting any existing partitions on $DEV..."
awk -v dev="$DEV" '$1 ~ "^"dev"[0-9p]" {print $2}' /proc/mounts | while read -r mnt; do
    echo "  - umount $mnt"
    umount "$mnt" || true
done

# --- Wipe first 8 MiB -----------------------------------------------------

echo ">> Wiping first 8 MiB of $DEV..."
dd if=/dev/zero of="$DEV" bs=1M count=8 conv=fsync status=progress

# --- Wipe any remaining filesystem/partition signatures -------------------

echo ">> Removing filesystem/partition signatures with wipefs..."
wipefs -a "$DEV"

# --- Create aligned MBR partition table -----------------------------------

echo ">> Creating new partition table and single FAT32 partition..."

START_SECTOR=8192

cat << SFDISK_EOF | sfdisk "$DEV"
label: dos
unit: sectors

${START_SECTOR},,c,*
SFDISK_EOF

# --- Re-read partition table ---------------------------------------------

echo ">> Forcing kernel to re-read partition table..."
partprobe "$DEV" 2>/dev/null || true
sleep 2

PARTITION="${DEV}1"
if [[ ! -b "$PARTITION" ]]; then
    if [[ -b "${DEV}p1" ]]; then
        PARTITION="${DEV}p1"
    else
        _die "Could not find the new partition (${DEV}1 or ${DEV}p1)."
    fi
fi

echo ">> New partition detected: $PARTITION"

# --- Create FAT32 filesystem ----------------------------------------------

LABEL="$DEFAULT_LABEL"

echo ">> Creating FAT32 filesystem on $PARTITION..."
echo "   mkfs.fat $MKFS_OPTS -n $LABEL $PARTITION"
mkfs.fat $MKFS_OPTS -n "$LABEL" "$PARTITION"

echo ">> Done."
echo "Partition layout:"
fdisk -l "$DEV" || true

echo "Filesystem details:"
fatlabel "$PARTITION" 2>/dev/null || echo "  (fatlabel not found; skipping label check)"

echo "sdcard_prep: Success. $PARTITION is ready to use."
