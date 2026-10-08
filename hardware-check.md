# Full hardware check

Regenerate with `scripts/hardware-check.sh` — read-only, ~3 s, 13 sections. This file is
the **redacted** copy: disk serial numbers, MAC addresses, IP addresses and SSIDs are
replaced with `[redacted]` before it lands in this repo, because the repo is published. The
unredacted run lives on the machine under `~/Documents/`; the sed that performs the
redaction is documented at the top of the script. Every line below is command output —
nothing here is inferred or remembered.

Generated: 2026-10-07T22:15:48-05:00 · machine cachyos-x8664 · kernel 7.2.9-1-cachyos · CachyOS on a Gigabyte B550 AORUS ELITE AX V2

## System

```text
$ hostnamectl
 Static hostname: cachyos-x8664
       Icon name: computer-desktop
         Chassis: desktop 🖥️
      Machine ID: c918fefaab2e4235b68284d69c2545b1
         Boot ID: e3c262feaefd4182ab2da0a89963984d
    Product UUID [redacted]
Operating System: CachyOS
          Kernel: Linux 7.2.9-1-cachyos
    Architecture: x86-64
 Hardware Vendor: Gigabyte Technology Co., Ltd.
  Hardware Model: B550 AORUS ELITE AX V2
 Hardware Serial: [redacted]
Firmware Version: FId
   Firmware Date: Tue 2026-08-18
    Firmware Age: 1month 2w 6d
```
```text
$ uptime -p; who -b 2>/dev/null
up 1 day, 13 hours, 0 minute
         system boot  2026-10-06 09:15
```
```text
$ timedatectl | head -8
 
Warning: The system is configured to read the RTC time in the local time zone.
         This mode cannot be fully supported. It will create various problems
         with time zone changes and daylight saving time adjustments. The RTC
         time is never updated, it relies on external facilities to maintain it.
         If at all possible, use RTC in UTC by calling
         'timedatectl set-local-rtc 0'.
               Local time: Wed 2026-10-07 22:15:48 CDT
           Universal time: Thu 2026-10-08 03:15:48 UTC
                 RTC time: Wed 2026-10-07 22:15:44
                Time zone: America/Chicago (CDT, -0500)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: yes
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
BootCurrent: 0002
Timeout: 1 seconds
BootOrder: 0002,0001,0000,0007,0003,0004,0005,0006,0008
Boot0000* Windows Boot Manager	HD(3,GPT,222670bc-076c-4994-9ec0-90ed9c7354fb,0x3d090800,0x32000)/\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI57494e444f5753000100000088000000780000004200430044004f0042004a004500430054003d007b00390064006500610038003600320063002d0035006300640064002d0034006500370030002d0061006300630031002d006600330032006200330034003400640034003700390035007d00000033000100000010000000040000007fff0400
      dp: 04 01 2a 00 03 00 00 00 00 08 09 3d 00 00 00 00 00 20 03 00 00 00 00 00 bc 70 26 22 6c 07 94 49 9e c0 90 ed 9c 73 54 fb 02 02 / 04 04 46 00 5c 00 45 00 46 00 49 00 5c 00 4d 00 49 00 43 00 52 00 4f 00 53 00 4f 00 46 00 54 00 5c 00 42 00 4f 00 4f 00 54 00 5c 00 42 00 4f 00 4f 00 54 00 4d 00 47 00 46 00 57 00 2e 00 45 00 46 00 49 00 00 00 / 7f ff 04 00
    data: 57 49 4e 44 4f 57 53 00 01 00 00 00 88 00 00 00 78 00 00 00 42 00 43 00 44 00 4f 00 42 00 4a 00 45 00 43 00 54 00 3d 00 7b 00 39 00 64 00 65 00 61 00 38 00 36 00 32 00 63 00 2d 00 35 00 63 00 64 00 64 00 2d 00 34 00 65 00 37 00 30 00 2d 00 61 00 63 00 63 00 31 00 2d 00 66 00 33 00 32 00 62 00 33 00 34 00 34 00 64 00 34 00 37 00 39 00 35 00 7d 00 00 00 33 00 01 00 00 00 10 00 00 00 04 00 00 00 7f ff 04 00
Boot0001* UEFI OS	HD(1,GPT,35e30959-a6e8-4319-8e32-1e98a48d4de0,0x1000,0x800000)/\EFI\BOOT\BOOTX64.EFI0000424f
      dp: 04 01 2a 00 01 00 00 00 00 10 00 00 00 00 00 00 00 00 80 00 00 00 00 00 59 09 e3 35 e8 a6 19 43 8e 32 1e 98 a4 8d 4d e0 02 02 / 04 04 30 00 5c 00 45 00 46 00 49 00 5c 00 42 00 4f 00 4f 00 54 00 5c 00 42 00 4f 00 4f 00 54 00 58 00 36 00 34 00 2e 00 45 00 46 00 49 00 00 00 / 7f ff 04 00
    data: 00 00 42 4f
Boot0002* Limine	HD(1,GPT,35e30959-a6e8-4319-8e32-1e98a48d4de0,0x1000,0x800000)/\EFI\LIMINE\LIMINE_X64.EFI
      dp: 04 01 2a 00 01 00 00 00 00 10 00 00 00 00 00 00 00 00 80 00 00 00 00 00 59 09 e3 35 e8 a6 19 43 8e 32 1e 98 a4 8d 4d e0 02 02 / 04 04 3a 00 5c 00 45 00 46 00 49 00 5c 00 4c 00 49 00 4d 00 49 00 4e 00 45 00 5c 00 4c 00 49 00 4d 00 49 00 4e 00 45 00 5f 00 58 00 36 00 34 00 2e 00 45 00 46 00 49 00 00 00 / 7f ff 04 00
Boot0003* ST12000DM0007-2GR116	BBS(HD,,0x0)0000424f
```
```text
$ if command -v mokutil >/dev/null; then mokutil --sb-state 2>&1 | head -2; else v=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1); if [ -n "$v" ]; then printf "SecureBoot efivar present; last byte (1 = enabled, 0 = disabled): %s\n" "$(od -An -tu1 "$v" | awk "{print \$NF}")"; else echo "no mokutil and no SecureBoot efivar"; fi; fi
SecureBoot efivar present; last byte (1 = enabled, 0 = disabled): 0
```
```text
$ sudo -n ls -la /boot | head -14
total 2152
drwx------ 6 root root  16384 Dec 31  1969 .
dr-xr-xr-x 1 root root    150 Sep 23 15:21 ..
-rwx------ 1 root root 307200 Sep 17 09:27 amd-ucode.img
drwx------ 5 root root   4096 Aug 29 22:28 c918fefaab2e4235b68284d69c2545b1
drwx------ 4 root root   4096 Aug 29 17:22 EFI
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0000.REC
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0001.REC
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0002.REC
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0003.REC
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0004.REC
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0005.REC
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0006.REC
-rwx------ 1 root root   4096 Dec 31  1979 FSCK0007.REC
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
CPU(s) scaling MHz:                      63%
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
Mem:            31Gi        16Gi       1.9Gi       308Mi        13Gi        14Gi
Swap:           31Gi        15Gi        15Gi
```
```text
$ swapon --show; echo; zramctl 2>/dev/null | head -4
NAME       TYPE       SIZE  USED PRIO
/dev/zram0 partition 31.3G 15.4G  100

NAME       ALGORITHM DISKSIZE  DATA COMPR TOTAL STREAMS MOUNTPOINT
/dev/zram0 zstd         31.3G 15.1G  6.8G  6.9G         [SWAP]
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
NVRM version: NVIDIA UNIX Open Kernel Module for x86_64  615.71.09  Release Build  (notroot@)  Sat Oct  3 18:52:37 UTC 2026
GCC version:  Selected multilib: .;@m64
```
```text
$ nvidia-smi --query-gpu=name,driver_version,vbios_version,memory.total,memory.used,temperature.gpu,power.draw,power.limit,clocks.sm,clocks.mem,utilization.gpu,pstate --format=csv 2>/dev/null
name, driver_version, vbios_version, memory.total [MiB], memory.used [MiB], temperature.gpu, power.draw [W], power.limit [W], clocks.current.sm [MHz], clocks.current.memory [MHz], utilization.gpu [%], pstate
NVIDIA GeForce RTX 3060, 615.71.09, 94.06.2F.00.9A, 12288 MiB, 1003 MiB, 49, 41.58 W, 170.00 W, 1807 MHz, 7501 MHz, 1 %, P0
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
    Currently available dedicated video memory: 10953 MB
OpenGL vendor string: NVIDIA Corporation
OpenGL renderer string: NVIDIA GeForce RTX 3060/PCIe/SSE2
OpenGL core profile version string: 4.6.0 NVIDIA 615.71.09
OpenGL core profile shading language version string: 4.60 NVIDIA
OpenGL core profile context flags: (none)
```

## Storage and filesystems

```text
$ lsblk -o NAME,SIZE,TYPE,FSTYPE,FSVER,MOUNTPOINTS,ROTA,MODEL
NAME          SIZE TYPE  FSTYPE            FSVER  MOUNTPOINTS ROTA MODEL
sda          10.9T disk                                          1 ST12000DM0007-2GR116
├─sda1         16M part                                          1 
├─sda2        5.5T part  ntfs                                    1 
└─sda3        5.5T part  btrfs                                   1 
sdb           2.7T disk                                          1 Hitachi HDS5C3030ALA630
├─sdb1        2.4G part  linux_raid_member 0.90.0                1 
├─sdb2          2G part  linux_raid_member 0.90.0                1 
└─sdb3        2.7T part  linux_raid_member 1.2                   1 
  └─md127     2.7T raid1 ext4              1.0                   1 
sdc          29.6G disk                                          1 USB 3.0 FD
└─sdc1       29.6G part  vfat              FAT32                 1 
zram0        31.3G disk  swap              1      [SWAP]         0 
nvme1n1     238.5G disk                                          0 INTEL SSDPEKKW256G7
├─nvme1n1p1     4G part  vfat              FAT32  /boot          0 
└─nvme1n1p2 234.5G part  btrfs                    /var/tmp       0 
                                                  /var/log         
                                                  /var/cache       
                                                  /srv             
                                                  /home            
                                                  /root            
                                                  /                
nvme0n1     931.5G disk                                          0 Samsung SSD 980 PRO 1TB
├─nvme0n1p1 487.5G part  ntfs                                    0 
├─nvme0n1p2   775M part  ntfs                                    0 
├─nvme0n1p3   100M part  vfat              FAT32                 0 
├─nvme0n1p4    16M part                                          0 
└─nvme0n1p5 443.1G part  btrfs                                   0 
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

       Update Time : Mon Jan  6 09:20:59 2025
             State : clean, degraded 
    Active Devices : 1
   Working Devices : 1
    Failed Devices : 0
     Spare Devices : 0

Consistency Policy : resync

              Name : DiskStation:2
              UUID [redacted]
            Events : 4421145

    Number   Major   Minor   RaidDevice State
```
```text
$ df -hT -x tmpfs -x devtmpfs -x efivarfs
Filesystem     Type   Size  Used Avail Use% Mounted on
/dev/nvme1n1p2 btrfs  235G  190G   42G  83% /
/dev/nvme1n1p2 btrfs  235G  190G   42G  83% /root
/dev/nvme1n1p2 btrfs  235G  190G   42G  83% /home
/dev/nvme1n1p2 btrfs  235G  190G   42G  83% /srv
/dev/nvme1n1p2 btrfs  235G  190G   42G  83% /var/cache
/dev/nvme1n1p2 btrfs  235G  190G   42G  83% /var/log
/dev/nvme1n1p2 btrfs  235G  190G   42G  83% /var/tmp
/dev/nvme1n1p1 vfat   4.0G  1.9G  2.2G  47% /boot
```
```text
$ findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS -t btrfs,vfat,ext4,swap,none 2>/dev/null | head -14
TARGET       SOURCE                  FSTYPE OPTIONS
/            /dev/nvme1n1p2[/@]      btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@
├─/root      /dev/nvme1n1p2[/@root]  btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=258,subvol=/@root
├─/home      /dev/nvme1n1p2[/@home]  btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=257,subvol=/@home
├─/srv       /dev/nvme1n1p2[/@srv]   btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=259,subvol=/@srv
├─/var/cache /dev/nvme1n1p2[/@cache] btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=260,subvol=/@cache
├─/var/log   /dev/nvme1n1p2[/@log]   btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=262,subvol=/@log
├─/var/tmp   /dev/nvme1n1p2[/@tmp]   btrfs  rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=261,subvol=/@tmp
└─/boot      /dev/nvme1n1p1          vfat   rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro
```
```text
$ sudo -n btrfs filesystem usage / 2>/dev/null | head -8
Overall:
    Device size:		 234.47GiB
    Device allocated:		 205.02GiB
    Device unallocated:		  29.45GiB
    Device missing:		     0.00B
    Device slack:		     0.00B
    Used:			 189.29GiB
    Free (estimated):		  41.33GiB	(min: 26.60GiB)
```
```text
$ sudo -n btrfs subvolume list / 2>/dev/null | head -12
ID 256 gen 107561 top level 5 path @
ID 257 gen 107562 top level 5 path @home
ID 258 gen 68232 top level 5 path @root
ID 259 gen 25 top level 5 path @srv
ID 260 gen 105228 top level 5 path @cache
ID 261 gen 107562 top level 5 path @tmp
ID 262 gen 107562 top level 5 path @log
ID 263 gen 27 top level 256 path var/lib/portables
ID 264 gen 27 top level 256 path var/lib/machines
ID 265 gen 104627 top level 256 path .snapshots
ID 271 gen 34 top level 265 path .snapshots/6/snapshot
ID 380 gen 48828 top level 265 path .snapshots/115/snapshot
```
```text
$ sudo -n snapper -c root list --columns number,type,date,description 2>/dev/null | tail -6
160 │ post   │ Tue 06 Oct 2026 11:20:40 AM CDT │ ccache cups hiredis libcups libcupsfilters libx11 sccache xorgproto
161 │ pre    │ Tue 06 Oct 2026 11:31:06 AM CDT │ pacman -Syu --noconfirm mold ninja hyperfine
162 │ post   │ Tue 06 Oct 2026 11:31:07 AM CDT │ hyperfine mold ninja
163 │ pre    │ Tue 06 Oct 2026 03:53:19 PM CDT │ pacman -U --noconfirm /tmp/MarkdownBlaze-1.0.23-1-x86_64.pkg.tar.zst
164 │ post   │ Tue 06 Oct 2026 03:53:20 PM CDT │ MarkdownBlaze
165 │ single │ Tue 06 Oct 2026 11:19:58 PM CDT │ pre: document /usr/local/bin shims
```
```text
$ for d in $(lsblk -dno NAME,TYPE | awk "\$2==\"disk\"{print \$1}"); do echo "== /dev/$d"; sudo -n smartctl -i -H -A "/dev/$d" 2>/dev/null | grep -i -e "Model Number" -e "Firmware" -e "Serial Number" -e "SMART overall" -e "Temperature" -e "Percentage Used" -e "Data Units Written" -e "Power On Hours" -e "Available Spare" -e "Media and Data" | head -12; done
== /dev/sda
Serial Number: [redacted]
Firmware Version: DN01
SMART overall-health self-assessment test result: PASSED
190 Airflow_Temperature_Cel 0x0022   050   043   040    Old_age   Always       -       50 (Min/Max 49/50)
194 Temperature_Celsius     0x0022   050   057   000    Old_age   Always       -       50 (0 19 0 0 0)
== /dev/sdb
Serial Number: [redacted]
Firmware Version: MEAOA580
SMART overall-health self-assessment test result: PASSED
194 Temperature_Celsius     0x0002   113   113   000    Old_age   Always       -       53 (Min/Max 13/59)
== /dev/sdc
== /dev/zram0
== /dev/nvme1n1
Model Number:                       INTEL SSDPEKKW256G7
Serial Number: [redacted]
Firmware Version:                   PSF100C
SMART overall-health self-assessment test result: PASSED
Temperature:                        35 Celsius
Available Spare:                    100%
Available Spare Threshold:          10%
Percentage Used:                    13%
Data Units Written:                 65,479,647 [33.5 TB]
Power On Hours:                     38,280
Media and Data Integrity Errors:    1
Warning  Comp. Temperature Time:    145
== /dev/nvme0n1
Model Number:                       Samsung SSD 980 PRO 1TB
Serial Number: [redacted]
Firmware Version:                   5B2QGXA7
SMART overall-health self-assessment test result: PASSED
Temperature:                        41 Celsius
Available Spare:                    100%
Available Spare Threshold:          10%
Percentage Used:                    3%
Data Units Written:                 34,336,181 [17.5 TB]
Power On Hours:                     1,981
Media and Data Integrity Errors:    0
Warning  Comp. Temperature Time:    0
```

## PCIe topology (which M.2 slot each NVMe sits in, and its link)

```text
$ for n in /sys/class/nvme/nvme*; do d=$(basename "$n"); dev=$(readlink -f "$n/device"); pci=$(basename "$dev"); parent=$(basename "$(dirname "$dev")"); printf "%-7s %s\n" "$d" "$(cat $n/model 2>/dev/null)"; sudo -n lspci -vv -s "$pci" 2>/dev/null | grep -m1 -o "LnkSta:.*" | sed "s/^/          link now : /"; sudo -n lspci -vv -s "$parent" 2>/dev/null | grep -m1 -o "LnkCap:.*Speed [0-9.]*GT/s" | sed "s/^/          slot max : /"; done
nvme0   Samsung SSD 980 PRO 1TB                 
          link now : LnkSta:	Speed 8GT/s (downgraded), Width x4
          slot max : LnkCap:	Port #4, Speed 8GT/s
nvme1   INTEL SSDPEKKW256G7                     
          link now : LnkSta:	Speed 8GT/s, Width x4
          slot max : LnkCap:	Port #1, Speed 16GT/s
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
	[01;34mModes: [0;0m 1:3440x1440@59.97!  2:3840x2160@120.00  3:3840x2160@119.88  4:3840x2160@59.94  5:3840x2160@60.00  6:3840x2160@50.00  7:[01;32m3440x1440@120.00*[0;0m  8:3440x1440@99.98  9:2560x1440@120.00  10:1920x1080@119.88  11:1920x1080@60.00  12:1920x1080@59.94  13:1920x1080@50.00  14:1680x1050@59.95  15:1280x1024@75.03  16:1280x1024@60.02  17:1440x900@59.89  18:1280x960@60.00  19:1280x800@59.81  20:1152x864@75.00  21:1280x720@119.88  22:1280x720@60.00  23:1280x720@59.94  24:1280x720@50.00  25:1024x768@75.03  26:1024x768@60.00  27:800x600@75.00  28:800x600@60.32  29:720x576@50.00  30:720x480@59.94  31:640x480@75.00  32:640x480@59.94  33:640x480@59.93 
[01;33m	Custom modes:[0;0m None
[01;33m	Geometry: [0;0m0,0 3440x1440
[01;33m	Scale: [0;0m1
[01;33m	Rotation: [0;0m1
[01;33m	Overscan: [0;0m0
[01;33m	Vrr: [0;0mNever
[01;33m	RgbRange: [0;0munknown
[01;33m	HDR: [0;0mdisabled
[01;33m	Wide Color Gamut: [0;0mdisabled
[01;33m	ICC profile: [0;0mnone
[01;33m	Color profile source: [0;0msRGB
[01;33m	Color power preference: [0;0mprefer efficiency and performance
[01;33m	Brightness control: [0;0msupported, set to 100% and dimming to 100%
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
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP> 
eno1             UP             74:56:3c:ca:b5:ae <BROADCAST,MULTICAST,UP,LOWER_UP> 
wlan0            DOWN           da:74:4c:b4:36:71 <BROADCAST,MULTICAST> 
docker0          DOWN           ea:41:38:ab:c8:da <NO-CARRIER,BROADCAST,MULTICAST,UP> 

lo               UNKNOWN        127.0.0.1/8 ::1/128 
eno1             UP             192.168.0.15/24 fe80::5cb:5188:ec9f:a776/64 
wlan0            DOWN           
docker0          DOWN           172.17.0.1/16 fe80::e841:38ff:feab:c8da/64 
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
1: phy0: Wireless LAN
	Soft blocked: yes
	Hard blocked: no
14: hci0: Bluetooth
	Soft blocked: no
	Hard blocked: no

	Interface wlan0
		type managed
```
```text
$ timeout 5 bluetoothctl show 2>/dev/null | head -8 || echo "bluetoothctl unavailable"
Controller BC:C7:46:9A:E8:89 (public)
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
01:00.0 Non-Volatile memory controller [0108]: Intel Corporation SSD 600P Series [8086:f1a5] (rev 03)
02:00.0 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset USB 3.1 XHCI Controller [1022:43ee]
02:00.1 SATA controller [0106]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset SATA Controller [1022:43eb]
02:00.2 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Upstream Port [1022:43e9]
03:04.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Downstream Port [1022:43ea]
03:08.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Downstream Port [1022:43ea]
03:09.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] 500 Series Chipset Switch Downstream Port [1022:43ea]
04:00.0 Non-Volatile memory controller [0108]: Samsung Electronics Co Ltd NVMe SSD Controller PM9A1/PM9A3/980PRO [144d:a80a]
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
Bus 003 Device 062: ID 05e3:0610 Genesys Logic, Inc. Hub
Bus 003 Device 063: ID 28e9:30ad GDMicroelectronics B87 Keyboard
Bus 003 Device 064: ID 2516:0141 Cooler Master Co., Ltd. MM720 Gaming Mouse
Bus 004 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 004 Device 002: ID 154b:00d2 PNY USB 3.0 FD
Bus 004 Device 043: ID 05e3:0626 Genesys Logic, Inc. Hub
Bus 004 Device 044: ID 046d:085e Logitech, Inc. BRIO Ultra HD Webcam
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
    |__ Port 004: Dev 062, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 002: Dev 063, If 0, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 002: Dev 063, If 1, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 002: Dev 063, If 2, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 002: Dev 063, If 3, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 003: Dev 064, If 0, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 003: Dev 064, If 1, Class=Human Interface Device, Driver=usbhid, 12M
        |__ Port 003: Dev 064, If 2, Class=Human Interface Device, Driver=usbhid, 12M
/:  Bus 004.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/4p, 10000M
    |__ Port 003: Dev 002, If 0, Class=Mass Storage, Driver=usb-storage, 5000M
    |__ Port 004: Dev 043, If 0, Class=Hub, Driver=hub/4p, 5000M
        |__ Port 004: Dev 044, If 0, Class=Video, Driver=uvcvideo, 5000M
        |__ Port 004: Dev 044, If 1, Class=Video, Driver=uvcvideo, 5000M
        |__ Port 004: Dev 044, If 2, Class=Video, Driver=uvcvideo, 5000M
        |__ Port 004: Dev 044, If 3, Class=Audio, Driver=snd-usb-audio, 5000M
        |__ Port 004: Dev 044, If 4, Class=Audio, Driver=snd-usb-audio, 5000M
        |__ Port 004: Dev 044, If 5, Class=Human Interface Device, Driver=usbhid, 5000M
```

## Sensors, thermals, power

```text
$ if command -v sensors >/dev/null; then sudo -n sensors 2>/dev/null | head -46; else echo "lm_sensors not installed"; fi
gigabyte_wmi-virtual-0
Adapter: Virtual device
temp1:        +38.0°C  
temp2:        +37.0°C  
temp3:        +54.0°C  
temp4:        +40.0°C  
temp5:        +41.0°C  
temp6:        +45.0°C  

nvme-pci-0400
Adapter: PCI adapter
Composite:    +40.9°C  (low  = -273.1°C, high = +81.8°C)
                       (crit = +84.8°C)
Sensor 1:     +40.9°C  (low  = -273.1°C, high = +65261.8°C)
Sensor 2:     +44.9°C  (low  = -273.1°C, high = +65261.8°C)

acpitz-acpi-0
Adapter: ACPI interface
temp1:        +16.8°C  
temp2:        +16.8°C  

r8169_0_500:00-mdio-0
Adapter: MDIO adapter
temp1:        +44.5°C  (high = +120.0°C)

k10temp-pci-00c3
Adapter: PCI adapter
Tctl:         +53.9°C  
Tccd1:        +38.2°C  
Tccd2:        +41.5°C  

nvme-pci-0100
Adapter: PCI adapter
Composite:    +34.9°C  (low  = -273.1°C, high = +69.8°C)
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
```
```text
$ sudo -n dmesg 2>/dev/null | grep -i -m3 -e "microcode" -e "Spectre" -e "MDS" | head -3
[91145.992189] Spectre V2 : Update user space SMT mitigation: STIBP always-on
[96711.748396] Spectre V2 : Update user space SMT mitigation: STIBP off
[96711.817035] Spectre V2 : Update user space SMT mitigation: STIBP always-on
```

## Kernel modules and packages in play

```text
$ lsmod | grep -i -e "^nvidia" -e "^kvm" -e "^snd_hda" -e "^iwlwifi" -e "^r8169" -e "^usbhid" -e "^amdgpu" | head -14
snd_hda_codec_alc662    20480  1
snd_hda_codec_realtek_lib    73728  1 snd_hda_codec_alc662
snd_hda_codec_generic   126976  2 snd_hda_codec_alc662,snd_hda_codec_realtek_lib
snd_hda_codec_nvhdmi    16384  1
snd_hda_codec_hdmi     61440  1 snd_hda_codec_nvhdmi
snd_hda_intel          69632  2
kvm_amd               270336  0
snd_hda_codec         241664  6 snd_hda_codec_generic,snd_hda_codec_hdmi,snd_hda_intel,snd_hda_codec_alc662,snd_hda_codec_nvhdmi,snd_hda_codec_realtek_lib
snd_hda_core          159744  6 snd_hda_codec_generic,snd_hda_codec_hdmi,snd_hda_intel,snd_hda_codec_alc662,snd_hda_codec,snd_hda_codec_realtek_lib
kvm                  1564672  1 kvm_amd
r8169                 180224  0
nvidia_drm            184320  74
nvidia_uvm           2383872  0
nvidia_modeset       1908736  18 nvidia_drm
```
```text
$ pacman -Q linux-cachyos linux-cachyos-lts linux-cachyos-nvidia-open nvidia-utils linux-firmware 2>/dev/null
linux-cachyos 7.2.9-1
linux-cachyos-lts 6.18.55-1
linux-cachyos-nvidia-open 7.2.9-1
nvidia-utils 615.71.09-1
linux-firmware 1:20260916-1
```
```text
$ rg -c . /proc/crypto >/dev/null 2>&1; ls /usr/lib/modules | head -6
6.18.55-1-cachyos-lts
7.2.9-1-cachyos
```
