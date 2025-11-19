# sdcard_prep.sh
### Aligned FAT32 SD/microSD Card Preparation Script for Linux

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

A fast, deterministic SD/microSD preparation script that wipes vendor junk, aligns the partition at the **4 MiB boundary**, and formats a clean FAT32 filesystem optimized for consoles (DSi/3DS), embedded systems, and ROM loaders.

---

## Features

- **4 MiB-aligned partition** (sector 8192) — ideal for SD card erase-block boundaries  
- **Safe workflow** — unmounts partitions, wipes the first 8 MiB cleanly  
- **FAT32 w/ 32 KiB clusters** (`-s 64`) for improved performance on DSi/3DS/TWiLightMenu++  
- **Device guardrails**  
  - Rejects devices >256 GiB unless `--i-am-not-a-dumbass` is provided  
  - Requires explicit `"YES"` confirmation  
- **Single partition** (type `0x0C`, W95 FAT32 LBA)  
- **Pure Linux tooling** — relies on `sfdisk`, `wipefs`, `mkfs.fat`, etc.

---

## Usage

```bash
sudo ./sdcard_prep.sh /dev/sdX [--i-am-not-a-dumbass]
```

### Arguments

| Argument | Description |
|---------|-------------|
| `/dev/sdX` | Whole-disk block device (NOT `/dev/sdX1`) |
| `--i-am-not-a-dumbass` | Required to override the 256 GiB protection |

### Examples

```bash
sudo ./sdcard_prep.sh /dev/sdb
```

For SDXC cards (>256 GiB):

```bash
sudo ./sdcard_prep.sh /dev/sdb --i-am-not-a-dumbass
```

---

## What the Script Does

1. Verifies the device exists and is a whole disk  
2. Rejects large devices unless overridden  
3. Unmounts `/dev/sdX1`, `/dev/sdX2`, etc.  
4. **Wipes the first 8 MiB** (removes vendor partitions, boot remnants, etc.)  
5. Creates a clean MBR layout with a single aligned partition:  
   - Start: sector **8192** (4 MiB)  
   - End: end of device  
   - Type: **0x0C** (FAT32 LBA)  
6. Formats as FAT32 with **32 KiB clusters**:

```bash
mkfs.fat -F 32 -s 64 -n SDCARD /dev/sdX1
```

---

## Why 4 MiB Alignment?

Most SD/microSD cards use internal erase blocks sized in **multiple MiB**.  
If the filesystem starts mid‑block, writes cause **read–modify–write cycles**, degrading:

- performance  
- latency  
- card longevity  

Starting the partition at **4 MiB** aligns it cleanly with these erase structures.

**Reference:**  
- Practical SD card alignment discussion (explicit 4 MiB recommendation):  
  https://3gfp.com/wp/2014/07/formatting-sd-cards-for-speed-and-lifetime/

---

## Why 32 KiB Clusters?

For Nintendo DSi/3DS homebrew (TWiLight Menu++ in particular), larger FAT32 clusters significantly reduce:

- fragmentation  
- directory traversal overhead  
- load time for ROMs and menus  

**Reference:**  
- TWiLight Menu++ FAQs & Troubleshooting:  
  https://github.com/Epicpkmn11/TWiLightMenu/wiki/FAQs-%26-Troubleshooting

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

