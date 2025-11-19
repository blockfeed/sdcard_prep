# sdcard_prep.sh
### Aligned FAT32 SD/microSD Card Preparation Script for Linux

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

A fast, deterministic SD/microSD preparation script that wipes vendor junk, aligns the partition at the 4 MiB boundary, and formats a clean FAT32 filesystem optimized for consoles (DSi/3DS), embedded systems, and ROM loaders.

---

## Features

- **4 MiB-aligned partition** (sector 8192) — optimal for NAND erase blocks  
- **Safe, explicit workflow** — unmounts partitions, wipes only the first 8 MiB  
- **FAT32 filesystem** with 16 KiB clusters (`-s 32`)  
- **Device safety guardrails**  
  - Rejects devices **>256 GiB** unless `--i-am-not-a-dumbass` is provided  
  - Requires typing **YES** explicitly  
- **Single partition** of type **0x0C (W95 FAT32 LBA)**  
- **Pure Linux tooling** — uses only standard Unix utilities

---

## Usage

```bash
sudo ./sdcard_prep.sh /dev/sdX [--i-am-not-a-dumbass]
```

### Arguments

| Argument | Meaning |
|---------|---------|
| `/dev/sdX` | Target whole-disk block device (NOT `/dev/sdX1`) |
| `--i-am-not-a-dumbass` | Required for devices above 256 GiB |

### Example

```bash
sudo ./sdcard_prep.sh /dev/sdb
```

For SDXC cards (>256 GiB):

```bash
sudo ./sdcard_prep.sh /dev/sdb --i-am-not-a-dumbass
```

---

## What the Script Does

1. Verifies the device exists and is a whole disk.  
2. Rejects huge devices unless explicitly overridden.  
3. Unmounts `/dev/sdX1`, `/dev/sdX2`, etc.  
4. Wipes the first **8 MiB** (clears vendor metadata, GPT/MBR remnants).  
5. Creates an MBR table with a single, aligned partition:  
   - **Start:** 4 MiB (`8192` sectors)  
   - **End:** end of disk  
   - **Type:** `0x0C` (FAT32 LBA)  
6. Formats the partition as FAT32:

```bash
mkfs.fat -F 32 -s 32 -n SDCARD /dev/sdX1
```

---

## Why 4 MiB Alignment?

Most SD controllers use **4–8 MiB internal erase blocks**. Aligning the filesystem to these boundaries:

- avoids read‑modify‑write cycles  
- improves performance  
- reduces FAT wear  
- increases card lifetime  

Perfect for DSi/3DS, Switch payload loaders, FPGA carts, and embedded systems.

---

## Requirements

- Linux  
- `bash`  
- `sfdisk`  
- `wipefs`  
- `dd`  
- `mkfs.fat`  
- `partprobe` (optional)  
- `fatlabel` (optional)

---

## Installation

```bash
git clone https://github.com/blockfeed/sdcard_prep.git
cd sdcard_prep
chmod +x sdcard_prep.sh
```

---

## Example Output

```
Target device: /dev/sdb (59 GiB)
Type 'YES' to continue: YES
>> Unmounting existing partitions...
>> Wiping first 8 MiB...
>> Removing filesystem signatures...
>> Creating new partition table...
>> Creating FAT32 filesystem...
sdcard_prep: Success. /dev/sdb1 is ready to use.
```

---

## License

This project is licensed under the **GNU General Public License v3.0**.

