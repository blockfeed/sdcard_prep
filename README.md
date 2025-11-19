\
    # sdcard_prep.sh

    Prepare an SD/microSD card under Linux with a single, aligned FAT32 partition suitable for
    devices like Nintendo DSi/3DS and other embedded systems that expect a simple FAT32 layout.

    > **WARNING:** This script will **destroy all data** on the target device.

    ## What it does

    Given a whole-disk device (e.g. `/dev/sdb`), the script:

    1. Performs sanity checks:
       - Verifies the device exists and is a block device.
       - Rejects partitions (`/dev/sdb1`, `/dev/mmcblk0p1`, etc.).
       - Reads device size from `/sys/block/*/size`.
       - **Refuses to operate on devices larger than 256 GiB** unless explicitly overridden.
    2. Unmounts any mounted partitions belonging to that device.
    3. Wipes the first 8 MiB of the device to clear:
       - old MBR/partition tables,
       - leftover filesystem headers,
       - vendor-reserved junk at the head of the disk.
    4. Uses `sfdisk` to create a new **MBR (dos)** partition table with a single partition:
       - starts at **4 MiB** (sector `8192` assuming 512-byte sectors),
       - consumes the **rest of the device**,
       - partition type **0x0C** (`W95 FAT32 LBA`),
       - marked bootable (`*`).
    5. Creates a FAT32 filesystem on the new partition with:
       - `mkfs.fat -F 32 -s 32` (FAT32, 16 KiB cluster size),
       - label `SDCARD` by default.

    This matches a typical “optimal” layout for SD/microSD use-cases:

    - 4 MiB partition alignment plays nicely with typical NAND erase block sizes.
    - FAT32 with 16 KiB clusters is well-behaved for large, mostly-sequential workloads
      (ROMs, media, etc.).
    - A single partition is simple and compatible with consoles and cameras.

    ## Requirements

    - Linux
    - `bash`
    - `sfdisk` (from `util-linux`)
    - `dd`
    - `wipefs`
    - `mkfs.fat` (`dosfstools`)
    - `partprobe` (from `parted`) is optional but recommended
    - `fatlabel` is optional (used only to display the resulting label)

    ## Usage

    ```bash
    sudo ./sdcard_prep.sh /dev/sdX [--i-am-not-a-dumbass]
    ```

    - `/dev/sdX`  
      Whole-disk block device (e.g. `/dev/sdb`, **not** `/dev/sdb1`).
    - `--i-am-not-a-dumbass`  
      Required if the target device is larger than **256 GiB**. This is a guardrail to
      prevent you from accidentally nuking large HDDs/SSDs/NVMe devices.

    The script will:

    - Print the detected device size in GiB.
    - Ask you to type `YES` (exactly) before doing anything destructive.
    - Show the resulting partition table and filesystem label when finished.

    Example:

    ```bash
    # DANGER: this will erase /dev/sdb completely
    sudo ./sdcard_prep.sh /dev/sdb
    ```

    If `/dev/sdb` is larger than 256 GiB:

    ```bash
    sudo ./sdcard_prep.sh /dev/sdb --i-am-not-a-dumbass
    ```

    ## Layout details

    The script creates:

    - **Partition table:** MBR (`dos`)
    - **Partition 1:**
      - Start: 4 MiB (sector 8192 @ 512 B/sector)
      - End: end-of-device
      - Type: `0x0C` (`W95 FAT32 LBA`)
      - Bootable flag: set

    Filesystem:

    - Type: FAT32
    - Command: `mkfs.fat -F 32 -s 32 -n SDCARD /dev/sdX1`
    - Cluster size: 16 KiB (32 sectors × 512 B)

    This is tuned for:

    - consoles (e.g. DSi/3DS) and older hardware that expect FAT32,
    - ROM-loading and sequential read patterns,
    - minimal metadata churn and reasonable performance on SD controllers.

    ## Customization

    If you want to tweak cluster size or label, edit the top of the script:

    ```bash
    MKFS_OPTS="-F 32 -s 32"   # FAT32, 16 KiB clusters (32 * 512-byte sectors)
    DEFAULT_LABEL="SDCARD"
    ```

    Examples:

    - 32 KiB clusters:

      ```bash
      MKFS_OPTS="-F 32 -s 64"
      ```

    - Custom label:

      ```bash
      DEFAULT_LABEL="NDSI"
      ```

    ## Safety notes

    - This script is intentionally conservative:
      - It refuses to run on >256 GiB devices unless you add
        `--i-am-not-a-dumbass`.
      - It demands an explicit `YES` before doing anything destructive.
    - It is still trivially possible to destroy important data if you point it at
      the wrong device. Double-check `lsblk`/`fdisk -l` before running.

