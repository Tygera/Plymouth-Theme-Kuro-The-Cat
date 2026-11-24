# Bootloader: GRUB vs. systemd-boot

Plymouth starts inside the initramfs. Everything before that is up to your bootloader,
including the text that shows up before the cat does.

```
Firmware  →  bootloader (GRUB / systemd-boot)  →  kernel  →  initramfs + Plymouth  →  system
                  ^ prints "Loading ..." here                   ^ only now does the cat start
```

## GRUB

GRUB prints `Loading Linux linux ...` and `Loading initial ramdisk ...` on every
boot. `quiet` doesn't help, because that parameter is for the kernel, and the kernel
isn't running yet.

### Removing the messages

The lines are hardcoded in `/etc/grub.d/10_linux`. First check that the pattern only
matches those two lines:

```bash
sed -n '/echo.*\$message/p' /etc/grub.d/10_linux
```

It should show exactly two `echo '$(echo "$message" | grub_quote)'` lines. Then:

```bash
sudo sed -i '/echo.*\$message/s/^/#/' /etc/grub.d/10_linux
```

Also in `/etc/default/grub`:

```
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_GFXPAYLOAD_LINUX=keep
```

- `hidden` skips the menu. Hold Esc or Shift during boot to get it back.
- `keep` keeps the framebuffer resolution through the handover to the kernel, which means
  less flicker before Plymouth starts.

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Keeping it that way

Every `grub` package update restores `10_linux`, and the messages come back.
This pacman hook comments them out again automatically:

`/etc/pacman.d/hooks/grub-quiet.hook`

```ini
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = grub

[Action]
Description = Silencing GRUB "Loading ..." messages
When = PostTransaction
Exec = /bin/sh -c "sed -i '/^[^#]*echo.*\\$message/s/^/#/' /etc/grub.d/10_linux && grub-mkconfig -o /boot/grub/grub.cfg"
```

The `^[^#]*` makes sure lines that are already commented out don't get a second `#`.

It works, but it's a workaround for something systemd-boot simply doesn't do.

## Switching to systemd-boot

Requirements: **UEFI** (no BIOS/CSM boot) and the kernel on the **EFI system
partition (ESP)**. systemd-boot only reads FAT, so it can't see kernels on an
ext4 `/boot`.

Effort: about ten minutes. Risk: low, if you keep GRUB until the first successful boot.

### 0. Check

```bash
ls /sys/firmware/efi >/dev/null && echo UEFI      # must say "UEFI"
findmnt /boot; findmnt /efi; findmnt /boot/efi    # where is the ESP mounted?
cat /proc/cmdline                                 # current kernel parameters, needed below
```

- **ESP mounted at `/boot`** (vfat): kernels are already on the ESP, so carry on.
- **ESP at `/boot/efi` or `/efi`**: kernels sit next to it on ext4. Either mount the ESP
  at `/boot` (copy over the contents of `/boot`, adjust fstab, make sure the ESP is at
  least ~300 MB), or use unified kernel images (UKI). Both are documented in the
  [ArchWiki](https://wiki.archlinux.org/title/Systemd-boot).

### 1. Install

```bash
sudo bootctl install
sudo systemctl enable systemd-boot-update.service   # keeps the bootloader updated
```

### 2. `/boot/loader/loader.conf`

```
default arch.conf
timeout 0
console-mode keep
editor no
```

- `timeout 0`: no menu. Hold Space during boot to get it.
- `editor no`: nobody gets to add `init=/bin/sh` to the kernel line at boot.

### 3. Boot entries

`/boot/loader/entries/arch.conf`

```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=xxxx rw quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0
```

Take the `options` from your `/proc/cmdline` and leave out `BOOT_IMAGE=...`. Keep
encryption parameters (`rd.luks.name=...` or `cryptdevice=...`).

You don't need a separate `initrd /intel-ucode.img` line if your HOOKS include `microcode`,
because that hook already puts the microcode into the initramfs.

`/boot/loader/entries/arch-fallback.conf` is the same, but with the fallback image:

```
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options root=UUID=xxxx rw
```

The fallback image is built without the `autodetect` hook and contains every module.
It's bigger, but it boots even when the normal image is missing a driver (after a
hardware change, or an initramfs built from a chroot). Check whether it exists:

```bash
ls /boot/initramfs-*
grep PRESETS /etc/mkinitcpio.d/linux.preset    # should include 'fallback'
```

### 4. Test

```bash
bootctl list    # are both entries detected?
reboot
```

### 5. Clean up (only once it boots reliably)

```bash
sudo pacman -Rns grub
sudo rm -r /boot/grub
efibootmgr                      # find the old GRUB entry
sudo efibootmgr -b XXXX -B      # and remove it
sudo rm /etc/pacman.d/hooks/grub-quiet.hook   # if you set it up
```

### Mac quirk

Apple firmware sometimes ignores NVRAM boot entries. `bootctl install` also installs
itself to the fallback path `/EFI/BOOT/BOOTX64.EFI`, so it usually works anyway.
If not, hold **Option** at boot and pick "EFI Boot".
