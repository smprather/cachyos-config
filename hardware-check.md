# Full hardware check

Regenerate with `scripts/hardware-check.sh` — read-only, ~3 s, 14 sections (the redaction
self-test that closes the output is not one of them). This file is the **redacted** copy: disk
serial numbers, MAC addresses, IP addresses, SSIDs and the machine-id are replaced with
`[redacted]` before it lands in this repo, because the repo is published. The unredacted run
lives on the machine under `~/Documents/`; the rule set is `REDACT_SED` at the top of the
script (`scripts/hardware-check.sh --print-redact-sed` prints it), and the self-test block at
the end proves it still blanks every identifier shape. Every line below is command output —
nothing here is inferred or remembered.

The machine-id is on that list for a reason worth keeping: Limine names its kernel-staging
directory `/boot/<machine-id>/` and records the same value in `/boot/limine.conf`, so an
unredacted `/boot` listing identifies this machine by itself. A labelled-only rule missed
exactly that until 2026-10-17; the context-free 32-hex rule covers it. Do not remove that rule,
and do not reinstate the older sed (see the top of `scripts/hardware-check.sh`).

Generated: 2026-10-17T18:18:19-05:00 · machine cachyos-x8664 · kernel 7.2.9-2-cachyos · CachyOS on a Gigabyte B550 AORUS ELITE AX V2

## System

```text
$ hostnamectl
 Static hostname: cachyos-x8664
       Icon name: computer-desktop
         Chassis: desktop 🖥️
      Machine ID [redacted]
         Boot ID [redacted]
    Product UUID [redacted]
Operating System: CachyOS
          Kernel: Linux 7.2.9-2-cachyos
    Architecture: x86-64
 Hardware Vendor: Gigabyte Technology Co., Ltd.
  Hardware Model: B550 AORUS ELITE AX V2
 Hardware Serial: [redacted]
Firmware Version: FId
   Firmware Date: Tue 2026-08-18
    Firmware Age: 2month
```
```text
$ uptime -p; who -b 2>/dev/null
up 38 minutes
         system boot  2026-10-17 17:40
```
```text
$ timedatectl | head -8
               Local time: Sat 2026-10-17 18:18:19 CDT
           Universal time: Sat 2026-10-17 23:18:19 UTC
                 RTC time: Sat 2026-10-17 23:18:19
                Time zone: America/Chicago (CDT, -0500)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```
```text
$ head -6 /etc/os-release
NAME="CachyOS Linux"
PRETTY_NAME="CachyOS"
ID=cachyos
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
```

## Firmware, board, chassis, boot

```text
$ sudo -n dmidecode -t bios 2>/dev/null | sed -n "1,22p"
# dmidecode 3.7
Getting SMBIOS data from sysfs.
SMBIOS 3.3.0 present.

Handle 0x0000, DMI type 0, 26 bytes
Platform Firmware Information
	Vendor: American Megatrends International, LLC.
	Version: FId
	Release Date: 08/18/2026
	Address: 0xF0000
	Runtime Size: 64 KiB
	ROM Size: 16 MiB
	Characteristics:
		PCI is supported
		Firmware is upgradeable
		Firmware shadowing is allowed
		Boot from CD is supported
		Selectable boot is supported
		Firmware ROM is socketed
		EDD is supported
		Japanese floppy for NEC 9800 1.2 MB is supported (int 13h)
		Japanese floppy for Toshiba 1.2 MB is supported (int 13h)
```
```text
$ ls /sys/class/tpm/ 2>/dev/null | head -3 || echo "no TPM device node"
tpm0
```
```text
$ sudo -n dmidecode -t baseboard 2>/dev/null | sed -n "/Base Board Information/,/^$/p"
Base Board Information
	Manufacturer: Gigabyte Technology Co., Ltd.
	Product Name: B550 AORUS ELITE AX V2
	Version: Default string
	Serial Number: [redacted]
	Asset Tag: Default string
	Features:
		Board is a hosting board
		Board is replaceable
	Location In Chassis: Default string
	Chassis Handle: 0x0003
	Type: Motherboard
	Contained Object Handles: 0

```
```text
$ sudo -n dmidecode -t system,chassis 2>/dev/null | grep -v "^$" | head -26
```
```text
$ if [ -d /sys/firmware/efi ]; then echo "EFI boot: yes (efivars present)"; else echo "EFI boot: no"; fi
EFI boot: yes (efivars present)
```
```text
$ sudo -n efibootmgr -v 2>/dev/null | head -12
BootCurrent: 000B
Timeout: 1 seconds
BootOrder: 000B,0008,0003,0001,0009,000A,0002,0004,0006,0007
Boot0001* UEFI OS	HD(1,GPT,35e30959-a6e8-4319-8e32-1e98a48d4de0,0x1000,0x800000)/\EFI\BOOT\BOOTX64.EFI0000424f
      dp: 04 01 2a 00 01 00 00 00 00 10 00 00 00 00 00 00 00 00 80 00 00 00 00 00 59 09 e3 35 e8 a6 19 43 8e 32 1e 98 a4 8d 4d e0 02 02 / 04 04 30 00 5c 00 45 00 46 00 49 00 5c 00 42 00 4f 00 4f 00 54 00 5c 00 42 00 4f 00 4f 00 54 00 58 00 36 00 34 00 2e 00 45 00 46 00 49 00 00 00 / 7f ff 04 00
    data: 00 00 42 4f
Boot0002* Limine	HD(1,GPT,35e30959-a6e8-4319-8e32-1e98a48d4de0,0x1000,0x800000)/\EFI\LIMINE\LIMINE_X64.EFI
      dp: 04 01 2a 00 01 00 00 00 00 10 00 00 00 00 00 00 00 00 80 00 00 00 00 00 59 09 e3 35 e8 a6 19 43 8e 32 1e 98 a4 8d 4d e0 02 02 / 04 04 3a 00 5c 00 45 00 46 00 49 00 5c 00 4c 00 49 00 4d 00 49 00 4e 00 45 00 5c 00 4c 00 49 00 4d 00 49 00 4e 00 45 00 5f 00 58 00 36 00 34 00 2e 00 45 00 46 00 49 00 00 00 / 7f ff 04 00
Boot0003* ST12000DM0007-2GR116	BBS(HD,,0x0)0000424f
      dp: 05 01 09 00 02 00 00 00 00 / 7f ff 04 00
    data: 00 00 42 4f
Boot0004* Hitachi HDS5C3030ALA630	BBS(HD,,0x0)0000424f
```
```text
$ if command -v mokutil >/dev/null; then mokutil --sb-state 2>&1 | head -2; else v=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1); if [ -n "$v" ]; then printf "SecureBoot efivar present; last byte (1 = enabled, 0 = disabled): %s\n" "$(od -An -tu1 "$v" | awk "{print \$NF}")"; else echo "no mokutil and no SecureBoot efivar"; fi; fi
SecureBoot efivar present; last byte (1 = enabled, 0 = disabled): 0
```
```text
$ sudo -n ls -la /boot | head -14
total 250764
drwxr-xr-x 5 root root      4096 Dec 31  1969 .
dr-xr-xr-x 1 root root       142 Oct 17 16:54 ..
drwxr-xr-x 5 root root      4096 Oct 17 17:45 [redacted]
-rwxr-xr-x 1 root root    307200 Sep 17 04:27 amd-ucode.img
drwxr-xr-x 4 root root      4096 Oct 17 11:52 EFI
-rwxr-xr-x 1 root root 110237389 Oct 17 11:54 initramfs-linux-cachyos.img
-rwxr-xr-x 1 root root 110708504 Oct 17 11:54 initramfs-linux-cachyos-lts.img
-rwxr-xr-x 1 root root    333800 Oct 13 00:17 limine-bios.sys
-rwxr-xr-x 1 root root     22848 Oct 17 18:18 limine.conf
-rwxr-xr-x 1 root root      9073 Oct 17 18:03 limine.conf.old
-rwxr-xr-x 1 root root     98696 Jan 22  2026 limine-splash.png
drwxr-xr-x 2 root root      4096 Oct 17 17:40 loader
-rwxr-xr-x 1 root root  17244160 Oct 17 11:52 vmlinuz-linux-cachyos
```

## CPU

```text
$ lscpu | grep -v -e "^Flags" -e "^NUMA" -e "^Vulnerability" -e "^BogoMIPS" | head -32
Architecture:                            x86_64
CPU op-mode(s):                          32-bit, 64-bit
Address sizes:                           48 bits physical, 48 bits virtual
Byte Order:                              Little Endian
CPU(s):                                  24
On-line CPU(s) list:                     0-23
Vendor ID:                               AuthenticAMD
Model name:                              AMD Ryzen 9 5900X 12-Core Processor
CPU family:                              25
Model:                                   33
Thread(s) per core:                      2
Core(s) per socket:                      12
Socket(s):                               1
Stepping:                                2
Microcode version:                       0xa201213
Frequency boost:                         enabled
CPU(s) scaling MHz:                      54%
CPU max MHz:                             4954.5649
CPU min MHz:                             567.0890
Virtualization:                          AMD-V
L1d cache:                               384 KiB (12 instances)
L1i cache:                               384 KiB (12 instances)
L2 cache:                                6 MiB (12 instances)
L3 cache:                                64 MiB (2 instances)
```
```text
$ lscpu | grep "^Flags" | tr " " "\n" | grep -x -e avx2 -e avx512f -e svm -e aes -e sha_ni -e f16c -e bmi2 -e movbe -e vaes -e vpclmulqdq -e sme -e sev -e invpcid -e pcid -e fsgsbase -e umip -e pku -e ospke -e user_shstk -e xsaves -e clzero -e erms -e adx -e npt -e lbrv -e v_vmsave_vmload -e vgif -e avic -e wdt -e rdseed -e ibrs -e ibpb -e stibp -e ssbd | sort | tr "\n" " "; echo
adx aes avic avx2 bmi2 clzero erms f16c fsgsbase ibpb ibrs invpcid lbrv movbe npt ospke pku rdseed sha_ni ssbd stibp svm umip user_shstk vaes vgif vpclmulqdq v_vmsave_vmload wdt xsaves 
```
```text
$ grep -m1 "^microcode" /proc/cpuinfo; grep -m1 "^model name" /proc/cpuinfo
microcode	: 0xa201213
model name	: AMD Ryzen 9 5900X 12-Core Processor
```
```text
$ cpupower frequency-info 2>/dev/null | grep -i -e driver -e governor -e "hardware limits" -e "current policy" -e boost -e energy | head -8
  driver: amd-pstate-epp
  energy performance preference: balance_performance
  hardware limits: 567 MHz - 4.95 GHz
  available cpufreq governors: performance powersave
  current policy: frequency should be within 1.73 GHz and 4.95 GHz.
                  The governor "powersave" may decide which speed to use
  boost state support:
```
```text
$ cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference 2>/dev/null; cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null
balance_performance
active
```
```text
$ sudo -n dmidecode -t processor 2>/dev/null | sed -n "/Processor Information/,/^Handle/p" | grep -v "^$" | head -24
Processor Information
	Socket Designation: AM4
	Type: Central Processor
	Family: Zen
	Manufacturer: Advanced Micro Devices, Inc.
	ID: 12 0F A2 00 FF FB 8B 17
	Signature: Family 25, Model 33, Stepping 2
	Flags:
		FPU (Floating-point unit on-chip)
		VME (Virtual mode extension)
		DE (Debugging extension)
		PSE (Page size extension)
		TSC (Time stamp counter)
		MSR (Model specific registers)
		PAE (Physical address extension)
		MCE (Machine check exception)
		CX8 (CMPXCHG8 instruction supported)
		APIC (On-chip APIC hardware supported)
		SEP (Fast system call)
		MTRR (Memory type range registers)
		PGE (Page global enable)
		MCA (Machine check architecture)
		CMOV (Conditional move instruction supported)
		PAT (Page attribute table)
```
```text
$ sudo -n dmidecode -t cache 2>/dev/null | grep -i -e "Installed Size" -e "Socket Designation" -e "Associativity" -e "^.\tType:" | head -20
grep: warning: stray \ before t
	Socket Designation: L1 - Cache
	Installed Size: 768 KiB
	Associativity: 8-way Set-associative
	Socket Designation: L2 - Cache
	Installed Size: 6 MiB
	Associativity: 8-way Set-associative
	Socket Designation: L3 - Cache
	Installed Size: 64 MiB
	Associativity: 16-way Set-associative
```
```text
$ cat /proc/cmdline
quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID [redacted]
```

## Memory

```text
$ sudo -n dmidecode -t memory 2>/dev/null | awk "/^Memory Device/{n++} n>0 && /^\t(Size|Type|Speed|Configured Memory Speed|Part Number|Rank|Locator|Bank Locator|Form Factor|Manufacturer):/{gsub(/^\t/,\"\"); print \"slot\" n \": \" \$0}" | grep -v "No Module Installed"
slot1: Form Factor: Unknown
slot1: Locator: DIMM 0
slot1: Bank Locator: P0 CHANNEL A
slot1: Type: Unknown
slot2: Size: 16 GiB
slot2: Form Factor: DIMM
slot2: Locator: DIMM 1
slot2: Bank Locator: P0 CHANNEL A
slot2: Type: DDR4
slot2: Speed: 3600 MT/s
slot2: Manufacturer: Unknown
slot2: Part Number: CMK32GX4M2D3600C18
slot2: Rank: 2
slot2: Configured Memory Speed: 3600 MT/s
slot3: Form Factor: Unknown
slot3: Locator: DIMM 0
slot3: Bank Locator: P0 CHANNEL B
slot3: Type: Unknown
slot4: Size: 16 GiB
slot4: Form Factor: DIMM
slot4: Locator: DIMM 1
slot4: Bank Locator: P0 CHANNEL B
slot4: Type: DDR4
slot4: Speed: 3600 MT/s
slot4: Manufacturer: Unknown
slot4: Part Number: CMK32GX4M2D3600C18
slot4: Rank: 2
slot4: Configured Memory Speed: 3600 MT/s
```
```text
$ sudo -n dmidecode -t memory 2>/dev/null | grep -e "Maximum Capacity" -e "Number Of Devices" -e "Error Correction Type"
	Error Correction Type: None
	Maximum Capacity: 128 GiB
	Number Of Devices: 4
```
```text
$ free -h
               total        used        free      shared  buff/cache   available
Mem:            31Gi       6.7Gi       5.2Gi       218Mi        19Gi        24Gi
Swap:           31Gi       2.1Mi        31Gi
```
```text
$ swapon --show; echo; zramctl 2>/dev/null | head -4
NAME       TYPE       SIZE USED PRIO
/dev/zram0 partition 31.3G 2.1M  100

NAME       ALGORITHM DISKSIZE DATA  COMPR TOTAL STREAMS MOUNTPOINT
/dev/zram0 zstd         31.3G 2.1M 484.1K  1.5M         [SWAP]
```

## GPU

```text
$ lspci -nnk | grep -A3 -i "VGA compatible\|3D controller"
07:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA106 [GeForce RTX 3060 Lite Hash Rate] [10de:2504] (rev a1)
	Subsystem: Micro-Star International Co., Ltd. [MSI] Device [1462:397d]
	Kernel driver in use: nvidia
	Kernel modules: nouveau, nvidia_drm, nvidia
```
```text
$ cat /proc/driver/nvidia/version 2>/dev/null | head -3
NVRM version: NVIDIA UNIX Open Kernel Module for x86_64  615.78.08  Release Build  (notroot@)  Fri Oct  9 15:54:18 UTC 2026
GCC version:  Selected multilib: .;@m64
```
```text
$ nvidia-smi --query-gpu=name,driver_version,vbios_version,memory.total,memory.used,temperature.gpu,power.draw,power.limit,clocks.sm,clocks.mem,utilization.gpu,pstate --format=csv 2>/dev/null
name, driver_version, vbios_version, memory.total [MiB], memory.used [MiB], temperature.gpu, power.draw [W], power.limit [W], clocks.current.sm [MHz], clocks.current.memory [MHz], utilization.gpu [%], pstate
NVIDIA GeForce RTX 3060, 615.78.08, 94.06.2F.00.9A, 12288 MiB, 387 MiB, 39, 12.81 W, 170.00 W, 210 MHz, 405 MHz, 13 %, P8
```
```text
$ command -v vulkaninfo >/dev/null && (vulkaninfo --summary 2>/dev/null | head -14) || echo "vulkaninfo not installed"
==========
VULKANINFO
==========

Vulkan Instance Version: 1.4.363


Instance Extensions: count = 25
-------------------------------
VK_EXT_acquire_drm_display             : extension revision 1
VK_EXT_acquire_xlib_display            : extension revision 1
VK_EXT_debug_report                    : extension revision 10
VK_EXT_debug_utils                     : extension revision 2
VK_EXT_direct_mode_display             : extension revision 1
```
```text
$ command -v glxinfo >/dev/null && (glxinfo -B 2>/dev/null | head -12) || echo "glxinfo not installed"
name of display: :0
display: :0  screen: 0
direct rendering: Yes
Memory info (GL_NVX_gpu_memory_info):
    Dedicated video memory: 12288 MB
    Total available memory: 12288 MB
    Currently available dedicated video memory: 11562 MB
OpenGL vendor string: NVIDIA Corporation
OpenGL renderer string: NVIDIA GeForce RTX 3060/PCIe/SSE2
OpenGL core profile version string: 4.6.0 NVIDIA 615.78.08
OpenGL core profile shading language version string: 4.60 NVIDIA
OpenGL core profile context flags: (none)
```

## Storage and filesystems

```text
$ lsblk -o NAME,SIZE,TYPE,FSTYPE,FSVER,MOUNTPOINTS,ROTA,MODEL
NAME          SIZE TYPE  FSTYPE            FSVER            MOUNTPOINTS  ROTA MODEL
sda          10.9T disk                                                     1 ST12000DM0007-2GR116
├─sda1         16M part                                                     1 
├─sda2        5.5T part  ntfs                                               1 
└─sda3        5.5T part  btrfs                                              1 
sdb           2.7T disk                                                     1 Hitachi HDS5C3030ALA630
├─sdb1        2.4G part  linux_raid_member 0.90.0                           1 
├─sdb2          2G part  linux_raid_member 0.90.0                           1 
└─sdb3        2.7T part  linux_raid_member 1.2                              1 
  └─md127     2.7T raid1 ext4              1.0                              1 
sdc          29.6G disk  iso9660           Joliet Extension                 1 USB 3.0 FD
├─sdc1        2.9G part  iso9660           Joliet Extension                 1 
└─sdc2         23M part  vfat              FAT16                            1 
zram0        31.3G disk  swap              1                [SWAP]          0 
nvme1n1     238.5G disk                                                     0 INTEL SSDPEKKW256G7
├─nvme1n1p1     4G part  vfat              FAT32                            0 
└─nvme1n1p2 234.5G part  btrfs                              /mnt/oldroot    0 
                                                            /mnt/oldhome      
                                                            /mnt/oldroot      
                                                            /mnt/oldroot      
nvme0n1     931.5G disk                                                     0 Samsung SSD 9100 PRO 1TB
├─nvme0n1p1     1M part                                                     0 
├─nvme0n1p2     4G part  vfat              FAT32            /boot           0 
└─nvme0n1p3 927.5G part  btrfs                              /var/tmp        0 
                                                            /var/log          
                                                            /var/cache        
                                                            /home             
                                                            /root             
                                                            /srv              
                                                            /                 
```
```text
$ cat /proc/mdstat 2>/dev/null || echo "no md arrays"
Personalities : [raid1] 
md127 : active (auto-read-only) raid1 sdb3[2]
      2925444560 blocks super 1.2 [2/1] [U_]
      
unused devices: <none>
```
```text
$ command -v mdadm >/dev/null && (sudo -n mdadm --detail /dev/md127 2>/dev/null | sed -n "1,24p") || echo "mdadm not installed"
/dev/md127:
           Version : 1.2
     Creation Time : Thu Mar 21 21:20:08 2013
        Raid Level : raid1
        Array Size : 2925444560 (2.72 TiB 3.00 TB)
     Used Dev Size : 2925444560 (2.72 TiB 3.00 TB)
      Raid Devices : 2
     Total Devices : 1
       Persistence : Superblock is persistent

       Update Time : Wed Oct 14 12:16:58 2026
             State : clean, degraded 
    Active Devices : 1
   Working Devices : 1
    Failed Devices : 0
     Spare Devices : 0

Consistency Policy : resync

              Name : DiskStation:2
              UUID [redacted]
            Events : 4421153

    Number   Major   Minor   RaidDevice State
```
```text
$ df -hT -x tmpfs -x devtmpfs -x efivarfs
Filesystem     Type   Size  Used Avail Use% Mounted on
/dev/nvme0n1p3 btrfs  928G  146G  781G  16% /
/dev/nvme0n1p3 btrfs  928G  146G  781G  16% /srv
/dev/nvme0n1p3 btrfs  928G  146G  781G  16% /root
/dev/nvme0n1p3 btrfs  928G  146G  781G  16% /home
/dev/nvme0n1p3 btrfs  928G  146G  781G  16% /var/cache
/dev/nvme0n1p3 btrfs  928G  146G  781G  16% /var/log
/dev/nvme0n1p3 btrfs  928G  146G  781G  16% /var/tmp
/dev/nvme0n1p2 vfat   4.0G  747M  3.3G  19% /boot
/dev/nvme1n1p2 btrfs  235G  193G   39G  84% /mnt/oldroot
/dev/nvme1n1p2 btrfs  235G  193G   39G  84% /mnt/oldhome
```
```text
$ findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS -t btrfs,vfat,ext4,swap,none 2>/dev/null | head -14
TARGET             SOURCE                  FSTYPE OPTIONS
/                  /dev/nvme0n1p3[/@]      btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@
├─/srv             /dev/nvme0n1p3[/@srv]   btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=259,subvol=/@srv
├─/root            /dev/nvme0n1p3[/@root]  btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=258,subvol=/@root
├─/home            /dev/nvme0n1p3[/@home]  btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=257,subvol=/@home
├─/var/cache       /dev/nvme0n1p3[/@cache] btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=260,subvol=/@cache
├─/var/log         /dev/nvme0n1p3[/@log]   btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=262,subvol=/@log
├─/var/tmp         /dev/nvme0n1p3[/@tmp]   btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=261,subvol=/@tmp
├─/boot            /dev/nvme0n1p2          vfat   rw,noatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro
├─/mnt/oldroot     /dev/nvme1n1p2[/@]      btrfs  ro,relatime,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@
│ └─/mnt/oldroot   /dev/nvme1n1p2[/@]      btrfs  ro,relatime,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@
│   └─/mnt/oldroot /dev/nvme1n1p2[/@]      btrfs  ro,relatime,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@
└─/mnt/oldhome     /dev/nvme1n1p2[/@home]  btrfs  ro,relatime,ssd,discard=async,space_cache=v2,subvolid=257,subvol=/@home
```
```text
$ sudo -n btrfs filesystem usage / 2>/dev/null | head -8
Overall:
    Device size:		 927.51GiB
    Device allocated:		 150.02GiB
    Device unallocated:		 777.49GiB
    Device missing:		     0.00B
    Device slack:		     0.00B
    Used:			 145.41GiB
    Free (estimated):		 780.68GiB	(min: 391.94GiB)
```
```text
$ sudo -n btrfs subvolume list / 2>/dev/null | head -12
ID 256 gen 157 top level 5 path @
ID 257 gen 158 top level 5 path @home
ID 258 gen 27 top level 5 path @root
ID 259 gen 25 top level 5 path @srv
ID 260 gen 157 top level 5 path @cache
ID 261 gen 132 top level 5 path @tmp
ID 262 gen 158 top level 5 path @log
ID 263 gen 56 top level 256 path var/lib/portables
ID 264 gen 56 top level 256 path var/lib/machines
ID 265 gen 158 top level 256 path .snapshots
ID 266 gen 31 top level 265 path .snapshots/1/snapshot
ID 267 gen 32 top level 265 path .snapshots/2/snapshot
```
```text
$ sudo -n snapper -c root list --columns number,type,date,description 2>/dev/null | tail -6
13 │ pre    │ Sat 17 Oct 2026 06:03:17 PM CDT │ pacman -Syu --noconfirm fio
14 │ post   │ Sat 17 Oct 2026 06:03:19 PM CDT │ fio glusterfs
15 │ pre    │ Sat 17 Oct 2026 06:17:33 PM CDT │ pacman -Syu pipewire-jack
16 │ post   │ Sat 17 Oct 2026 06:17:34 PM CDT │ jack2 pipewire-jack
17 │ pre    │ Sat 17 Oct 2026 06:17:49 PM CDT │ pacman -Syu --noconfirm ccache sccache mold ninja hyperfine docker docke
18 │ post   │ Sat 17 Oct 2026 06:18:00 PM CDT │ ada audacity blueman c-ares ccache cdparanoia chromium clamav colord col
```
```text
$ for d in $(lsblk -dno NAME,TYPE | awk "\$2==\"disk\"{print \$1}"); do echo "== /dev/$d"; sudo -n smartctl -i -H -A "/dev/$d" 2>/dev/null | grep -i -e "Model Number" -e "Firmware" -e "Serial Number" -e "SMART overall" -e "Temperature" -e "Percentage Used" -e "Data Units Written" -e "Power On Hours" -e "Available Spare" -e "Media and Data" | head -12; done
== /dev/sda
Serial Number: [redacted]
Firmware Version: DN01
SMART overall-health self-assessment test result: PASSED
190 Airflow_Temperature_Cel 0x0022   058   043   040    Old_age   Always       -       42 (Min/Max 41/42)
194 Temperature_Celsius     0x0022   042   057   000    Old_age   Always       -       42 (0 19 0 0 0)
== /dev/sdb
Serial Number: [redacted]
Firmware Version: MEAOA580
SMART overall-health self-assessment test result: PASSED
194 Temperature_Celsius     0x0002   130   130   000    Old_age   Always       -       46 (Min/Max 13/59)
== /dev/sdc
== /dev/zram0
== /dev/nvme1n1
Model Number:                       INTEL SSDPEKKW256G7
Serial Number: [redacted]
Firmware Version:                   PSF100C
SMART overall-health self-assessment test result: PASSED
Temperature:                        30 Celsius
Available Spare:                    100%
Available Spare Threshold:          10%
Percentage Used:                    13%
Data Units Written:                 67,576,337 [34.5 TB]
Power On Hours:                     38,507
Media and Data Integrity Errors:    1
Warning  Comp. Temperature Time:    145
== /dev/nvme0n1
Model Number:                       Samsung SSD 9100 PRO 1TB
Serial Number: [redacted]
Firmware Version:                   0B2QNXH7
SMART overall-health self-assessment test result: PASSED
Temperature:                        38 Celsius
Available Spare:                    100%
Available Spare Threshold:          10%
Percentage Used:                    0%
Data Units Written:                 553,282 [283 GB]
Power On Hours:                     0
Media and Data Integrity Errors:    0
Warning  Comp. Temperature Time:    0
```

## PCIe topology (which M.2 slot each NVMe sits in, and its link)

```text
$ for n in /sys/class/nvme/nvme*; do d=$(basename "$n"); dev=$(readlink -f "$n/device"); pci=$(basename "$dev"); parent=$(basename "$(dirname "$dev")"); printf "%-7s %s\n" "$d" "$(cat $n/model 2>/dev/null)"; sudo -n lspci -vv -s "$pci" 2>/dev/null | grep -m1 -o "LnkSta:.*" | sed "s/^/          link now : /"; sudo -n lspci -vv -s "$parent" 2>/dev/null | grep -m1 -o "LnkCap:.*Speed [0-9.]*GT/s" | sed "s/^/          slot max : /"; done
nvme0   Samsung SSD 9100 PRO 1TB                
          link now : LnkSta:	Speed 16GT/s (downgraded), Width x4
          slot max : LnkCap:	Port #1, Speed 16GT/s
nvme1   INTEL SSDPEKKW256G7                     
          link now : LnkSta:	Speed 8GT/s, Width x4
          slot max : LnkCap:	Port #4, Speed 8GT/s
```

## Displays

```text
$ kscreen-doctor -o 2>/dev/null | head -40 || echo "kscreen-doctor unavailable from this shell"
[01;32mOutput: [0;0m1 HDMI-A-1 b3c855e8-6ea0-4327-b0d1-ebeaa768a9f3
	[01;32menabled[0;0m
	[01;32mconnected[0;0m
	[01;32mpriority 1[0;0m
	[01;33mHDMI[0;0m
	[01;33mreplication source:[0;0m0
	[01;34mModes: [0;0m 1:[01;32m3440x1440@59.97*[0;0m!  2:3840x2160@60.00  3:3840x2160@59.94  4:3840x2160@50.00  5:2560x1440@120.00  6:1920x1080@119.88  7:1920x1080@100.00  8:1920x1080@60.00  9:1920x1080@59.94  10:1920x1080@50.00  11:1680x1050@59.95  12:1280x1024@75.03  13:1280x1024@60.02  14:1440x900@59.89  15:1280x960@60.00  16:1280x800@59.81  17:1152x864@75.00  18:1280x720@119.88  19:1280x720@60.00  20:1280x720@59.94  21:1280x720@50.00  22:1024x768@75.03  23:1024x768@60.00  24:800x600@75.00  25:800x600@60.32  26:720x576@50.00  27:720x480@59.94  28:640x480@75.00  29:640x480@59.94  30:640x480@59.93 
[01;33m	Custom modes:[0;0m None
[01;33m	Geometry: [0;0m0,0 3440x1440
[01;33m	Scale: [0;0m1
[01;33m	Rotation: [0;0m1
[01;33m	Overscan: [0;0m0
[01;33m	Vrr: [0;0mincapable
[01;33m	RgbRange: [0;0munknown
[01;33m	HDR: [0;0mdisabled
[01;33m	Wide Color Gamut: [0;0mdisabled
[01;33m	ICC profile: [0;0mnone
[01;33m	Color profile source: [0;0msRGB
[01;33m	Color power preference: [0;0mprefer efficiency and performance
[01;33m	Brightness control: [0;0munsupported
[01;33m	DDC/CI: [0;0mallowed
[01;33m	Color resolution: unknown
[01;33m	Allow EDR: [0;0munsupported
[01;33m	Sharpness control: [0;0munsupported
[01;33m	Automatic brightness: [0;0munsupported
[01;33m	Auto Rotate Policy: [0;0mincapable
[01;33m	Adaptive backlight modulation: [0;0munsupported
```
```text
$ for c in /sys/class/drm/card*-*; do [ -e "$c/status" ] || continue; printf "%s: status=%s enabled=%s modes=%s\n" "$(basename $c)" "$(cat $c/status)" "$(cat $c/enabled 2>/dev/null)" "$(head -3 $c/modes 2>/dev/null | tr "\n" ",")"; done
card1-DP-1: status=disconnected enabled=disabled modes=
card1-DP-2: status=disconnected enabled=disabled modes=
card1-DP-3: status=disconnected enabled=disabled modes=
card1-HDMI-A-1: status=connected enabled=enabled modes=3440x1440,3840x2160,3840x2160,
```

## Network and Bluetooth

```text
$ ip -br link; echo; ip -br addr | head -8
lo               UNKNOWN        [redacted] <LOOPBACK,UP,LOWER_UP> 
eno1             UP             [redacted] <BROADCAST,MULTICAST,UP,LOWER_UP> 
wlan0            DOWN           [redacted] <NO-CARRIER,BROADCAST,MULTICAST,UP> 
docker0          DOWN           [redacted] <NO-CARRIER,BROADCAST,MULTICAST,UP> 

lo               UNKNOWN        [redacted] [redacted] 
eno1             UP             [redacted] [redacted] 
wlan0            DOWN           
docker0          DOWN           [redacted] 
```
```text
$ lspci -nn | grep -i -e ethernet -e "network controller"
05:00.0 Ethernet controller [0200]: Realtek Semiconductor Co., Ltd. RTL8125 2.5GbE Controller [10ec:8125] (rev 05)
06:00.0 Network controller [0280]: Realtek Semiconductor Co., Ltd. RTL8852CE PCIe 802.11ax Wireless Network Controller [10ec:c852] (rev 01)
```
```text
$ for i in $(ls /sys/class/net | grep -v lo); do printf "%-12s " "$i"; sudo -n ethtool "$i" 2>/dev/null | grep -i -e speed -e duplex -e "link detected" | tr "\n" " "; echo; done
docker0      	Speed: Unknown! 	Duplex: Unknown! (255) 	Link detected: no 
eno1         	Speed: 1000Mb/s 	Duplex: Full 	Link detected: yes 
wlan0        	Link detected: no 
```
```text
$ rfkill list 2>/dev/null | head -8; echo; iw dev 2>/dev/null | grep -i -e Interface -e type -e channel -e ssid [redacted] head -8
0: hci0: Bluetooth
	Soft blocked: no
	Hard blocked: no
1: phy0: Wireless LAN
	Soft blocked: no
	Hard blocked: no

	Interface wlan0
		type managed
```
```text
$ timeout 5 bluetoothctl show 2>/dev/null | head -8 || echo "bluetoothctl unavailable"
Controller [redacted] (public)
	Manufacturer: 0x005d (93)
	Version: 0x0c (12)
	Name: cachyos-x8664
	Alias: cachyos-x8664
	Class: 0x007c0104 (8126724)
	Powered: yes
	PowerState: on
```
```text
$ lsusb | grep -i -e bluetooth -e wireless -e intel | head -4
Bus 001 Device 002: ID 0bda:0852 Realtek Semiconductor Corp. Bluetooth Radio
```

## Audio

```text
$ lspci -nn | grep -i audio
07:00.1 Audio device [0403]: NVIDIA Corporation GA106 High Definition Audio Controller [10de:228e] (rev a1)
09:00.4 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse HD Audio Controller [1022:1487]
```
```text
$ aplay -l 2>/dev/null | head -12
**** List of PLAYBACK Hardware Devices ****
card 1: NVidia [HDA NVidia], device 3: HDMI 0 [DELL S3425DW]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: NVidia [HDA NVidia], device 7: HDMI 1 [HDMI 1]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: NVidia [HDA NVidia], device 8: HDMI 2 [HDMI 2]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: NVidia [HDA NVidia], device 9: HDMI 3 [HDMI 3]
  Subdevices: 1/1
```
```text
$ pactl info 2>/dev/null | grep -i -e "Server Name" -e "Server Version" -e "Default Sink" -e "Default Source"
Server Name: PulseAudio (on PipeWire 1.6.9)
Server Version: 15.0.0
Default Sink: alsa_output.pci-0000_07_00.1.hdmi-stereo
Default Source: alsa_input.usb-046d_Logitech_BRIO_1A2BE970-03.analog-stereo
```

## PCI and USB inventory

```text
$ lspci -nn
00:00.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Root Complex [1022:1480]
00:00.2 IOMMU [0806]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse IOMMU [1022:1481]
00:01.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
00:01.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse GPP Bridge [1022:1483]
00:01.2 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse GPP Bridge [1022:1483]
00:02.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
00:03.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
00:03.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse GPP Bridge [1022:1483]
00:04.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
00:05.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
00:07.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
00:07.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Internal PCIe GPP Bridge 0 to bus[E:B] [1022:1484]
00:08.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
00:08.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Internal PCIe GPP Bridge 0 to bus[E:B] [1022:1484]
00:14.0 SMBus [0c05]: Advanced Micro Devices, Inc. [AMD] FCH SMBus Controller [1022:790b] (rev 61)
00:14.3 ISA bridge [0601]: Advanced Micro Devices, Inc. [AMD] FCH LPC Bridge [1022:790e] (rev 51)
00:18.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 0 [1022:1440]
00:18.1 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 1 [1022:1441]
00:18.2 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 2 [1022:1442]
00:18.3 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 3 [1022:1443]
00:18.4 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 4 [1022:1444]
00:18.5 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 5 [1022:1445]
00:18.6 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 6 [1022:1446]
00:18.7 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 7 [1022:1447]
01:00.0 Non-Volatile memory controller [0108]: Samsung Electronics Co Ltd NVMe SSD 9100 PRO [PM9E1] [144d:a810]
02:00.0 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset USB 3.1 XHCI Controller [1022:43ee]
02:00.1 SATA controller [0106]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset SATA Controller [1022:43eb]
02:00.2 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Upstream Port [1022:43e9]
03:04.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Downstream Port [1022:43ea]
03:08.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Downstream Port [1022:43ea]
03:09.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Downstream Port [1022:43ea]
04:00.0 Non-Volatile memory controller [0108]: Intel Corporation SSD 600P Series [8086:f1a5] (rev 03)
05:00.0 Ethernet controller [0200]: Realtek Semiconductor Co., Ltd. RTL8125 2.5GbE Controller [10ec:8125] (rev 05)
06:00.0 Network controller [0280]: Realtek Semiconductor Co., Ltd. RTL8852CE PCIe 802.11ax Wireless Network Controller [10ec:c852] (rev 01)
07:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA106 [GeForce RTX 3060 Lite Hash Rate] [10de:2504] (rev a1)
07:00.1 Audio device [0403]: NVIDIA Corporation GA106 High Definition Audio Controller [10de:228e] (rev a1)
08:00.0 Non-Essential Instrumentation [1300]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Function [1022:148a]
09:00.0 Non-Essential Instrumentation [1300]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Reserved SPP [1022:1485]
09:00.1 Encryption controller [1080]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Cryptographic Coprocessor PSPCPP [1022:1486]
09:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
09:00.4 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse HD Audio Controller [1022:1487]
```
```text
$ lsusb
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 001 Device 002: ID 0bda:0852 Realtek Semiconductor Corp. Bluetooth Radio
Bus 001 Device 003: ID 05e3:0608 Genesys Logic, Inc. Hub
Bus 001 Device 004: ID 048d:5702 Integrated Technology Express, Inc. RGB LED Controller
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 003 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 003 Device 002: ID 1a40:0101 Terminus Technology Inc. Hub
Bus 003 Device 003: ID 05e3:0610 Genesys Logic, Inc. Hub
Bus 003 Device 004: ID 1a86:e229 QinHeng Electronics WCH UART TO KB-MS_V1.8
Bus 003 Device 005: ID 05e3:0610 Genesys Logic, Inc. Hub
Bus 003 Device 006: ID 1a86:7523 QinHeng Electronics CH340 serial converter
Bus 003 Device 007: ID 28e9:30ad GDMicroelectronics B87 Keyboard
Bus 003 Device 008: ID 2516:0141 Cooler Master Co., Ltd. MM720 Gaming Mouse
Bus 004 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 004 Device 002: ID 154b:00d2 PNY USB 3.0 FD
Bus 004 Device 003: ID 05e3:0626 Genesys Logic, Inc. Hub
Bus 004 Device 004: ID 046d:085e Logitech, Inc. BRIO Ultra HD Webcam
Bus 004 Device 005: ID 05e3:0626 Genesys Logic, Inc. Hub
```
```text
$ lsusb -t | head -24
/:  Bus 001.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/10p, 480M
    |__ Port 005: Dev 002, If 0, Class=Wireless, Driver=btusb, 12M
    |__ Port 005: Dev 002, If 1, Class=Wireless, Driver=btusb, 12M
    |__ Port 006: Dev 003, If 0, Class=Hub, Driver=hub/4p, 480M
    |__ Port 007: Dev 004, If 0, Class=Human Interface Device, Driver=usbhid, 12M
/:  Bus 002.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/4p, 10000M
/:  Bus 003.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/4p, 480M
    |__ Port 002: Dev 002, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 001: Dev 003, If 0, Class=Hub, Driver=hub/4p, 480M
            |__ Port 004: Dev 005, If 0, Class=Hub, Driver=hub/4p, 480M
                |__ Port 003: Dev 007, If 0, Class=Human Interface Device, Driver=usbhid, 12M
                |__ Port 003: Dev 007, If 1, Class=Human Interface Device, Driver=usbhid, 12M
                |__ Port 003: Dev 007, If 2, Class=Human Interface Device, Driver=usbhid, 12M
                |__ Port 003: Dev 007, If 3, Class=Human Interface Device, Driver=usbhid, 12M
                |__ Port 004: Dev 008, If 0, Class=Human Interface Device, Driver=usbhid, 12M
                |__ Port 004: Dev 008, If 1, Class=Human Interface Device, Driver=usbhid, 12M
                |__ Port 004: Dev 008, If 2, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 002: Dev 004, If 0, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 003: Dev 006, If 0, Class=Vendor Specific Class, Driver=ch341, 12M
/:  Bus 004.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/4p, 10000M
    |__ Port 001: Dev 002, If 0, Class=Mass Storage, Driver=usb-storage, 5000M
    |__ Port 002: Dev 003, If 0, Class=Hub, Driver=hub/4p, 5000M
        |__ Port 001: Dev 004, If 0, Class=Video, Driver=uvcvideo, 5000M
        |__ Port 001: Dev 004, If 1, Class=Video, Driver=uvcvideo, 5000M
```

## Sensors, thermals, power

```text
$ if command -v sensors >/dev/null; then sudo -n sensors 2>/dev/null | head -46; else echo "lm_sensors not installed"; fi
gigabyte_wmi-virtual-0
Adapter: Virtual device
temp1:        +30.0°C  
temp2:        +30.0°C  
temp3:        +51.0°C  
temp4:        +32.0°C  
temp5:        +33.0°C  
temp6:        +38.0°C  

nvme-pci-0100
Adapter: PCI adapter
Composite:    +37.9°C  (low  = -273.1°C, high = +83.8°C)
                       (crit = +87.8°C)
Sensor 1:     +36.9°C  (low  = -273.1°C, high = +65261.8°C)
Sensor 2:     +37.9°C  (low  = -273.1°C, high = +65261.8°C)

acpitz-acpi-0
Adapter: ACPI interface
temp1:        +16.8°C  
temp2:        +16.8°C  

r8169_0_500:00-mdio-0
Adapter: MDIO adapter
temp1:        +36.5°C  (high = +120.0°C)

k10temp-pci-00c3
Adapter: PCI adapter
Tctl:         +51.8°C  
Tccd1:        +32.5°C  
Tccd2:        +37.2°C  

nvme-pci-0400
Adapter: PCI adapter
Composite:    +29.9°C  (low  = -273.1°C, high = +69.8°C)
                       (crit = +79.8°C)

```
```text
$ for z in /sys/class/thermal/thermal_zone*; do [ -e "$z/temp" ] && printf "%s %s: %s\n" "$(basename $z)" "$(cat $z/type 2>/dev/null)" "$(( $(cat $z/temp) / 1000 ))C"; done
thermal_zone0 acpitz: 16C
thermal_zone1 acpitz: 16C
```
```text
$ powerprofilesctl get 2>/dev/null; upower -e 2>/dev/null | head -6; for p in /sys/class/power_supply/*/type; do [ -e "$p" ] && cat "$p"; done
balanced
/org/freedesktop/UPower/devices/DisplayDevice
```
```text
$ cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver 2>/dev/null; cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null
amd-pstate-epp
1
```

## Virtualisation and platform security

```text
$ systemd-detect-virt; echo "IOMMU groups: $(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l)"; sudo -n dmesg 2>/dev/null | grep -i -m4 -e "AMD-Vi" -e "iommu" | head -4
none
IOMMU groups: 22
[    0.079980] AMD-Vi: ivrs, add hid:AMDI0020, uid:\_SB.FUR0, rdevid:0xa0
[    0.079981] AMD-Vi: ivrs, add hid:AMDI0020, uid:\_SB.FUR1, rdevid:0xa0
[    0.079982] AMD-Vi: ivrs, add hid:AMDI0020, uid:\_SB.FUR2, rdevid:0xa0
[    0.079982] AMD-Vi: ivrs, add hid:AMDI0020, uid:\_SB.FUR3, rdevid:0xa0
```
```text
$ sudo -n dmesg 2>/dev/null | grep -i -m3 -e "microcode" -e "Spectre" -e "MDS" | head -3
[    0.250932] Spectre V2 : Mitigation: Retpolines
[    0.250933] Spectre V2 : User space: Mitigation: STIBP always-on protection
[    0.250935] Spectre V1 : Mitigation: usercopy/swapgs barriers and __user pointer sanitization
```

## Kernel modules and packages in play

```text
$ lsmod | grep -i -e "^nvidia" -e "^kvm" -e "^snd_hda" -e "^iwlwifi" -e "^r8169" -e "^usbhid" -e "^amdgpu" | head -14
snd_hda_codec_alc662    20480  1
snd_hda_codec_realtek_lib    73728  1 snd_hda_codec_alc662
snd_hda_codec_generic   126976  2 snd_hda_codec_alc662,snd_hda_codec_realtek_lib
snd_hda_codec_nvhdmi    16384  1
snd_hda_codec_hdmi     61440  1 snd_hda_codec_nvhdmi
kvm_amd               270336  0
snd_hda_intel          69632  2
snd_hda_codec         241664  6 snd_hda_codec_generic,snd_hda_codec_hdmi,snd_hda_intel,snd_hda_codec_alc662,snd_hda_codec_nvhdmi,snd_hda_codec_realtek_lib
snd_hda_core          159744  6 snd_hda_codec_generic,snd_hda_codec_hdmi,snd_hda_intel,snd_hda_codec_alc662,snd_hda_codec,snd_hda_codec_realtek_lib
r8169                 180224  0
kvm                  1564672  1 kvm_amd
nvidia_drm            184320  24
nvidia_uvm           2383872  0
nvidia_modeset       1916928  13 nvidia_drm
```
```text
$ pacman -Q linux-cachyos linux-cachyos-lts linux-cachyos-nvidia-open nvidia-utils linux-firmware 2>/dev/null
linux-cachyos 7.2.9-2
linux-cachyos-lts 6.18.55-2
linux-cachyos-nvidia-open 7.2.9-2
nvidia-utils 615.78.08-2
linux-firmware 1:20260916-1
```
```text
$ rg -c . /proc/crypto >/dev/null 2>&1; ls /usr/lib/modules | head -6
6.18.55-2-cachyos-lts
7.2.9-2-cachyos
```

Redaction self-test (synthetic identifiers; none may survive the rules above):

```text
  redacted  disk serial, labelled
  redacted  GUID with dashes
  redacted  MAC, anchorless shape
  redacted  IPv4, anchorless shape
  redacted  wireless network name, labelled
  redacted  IPv4, bare inside a list
  redacted  IPv6
  redacted  machine-id, labelled and bare
```
