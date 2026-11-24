# Troubleshooting

## No splash at all, just text

- **`splash` missing** from the kernel parameters? Check with `cat /proc/cmdline`.
- **HOOKS order wrong.** `plymouth` must come right after `systemd` or `udev`, and before
  `sd-encrypt` / `encrypt`. After any change: `sudo mkinitcpio -P`.
- **Theme not active?** `plymouth-set-default-theme` should print `kuro`.
  If not: `sudo plymouth-set-default-theme -R kuro`.
- **Is the theme in the initramfs?**
  ```bash
  lsinitcpio /boot/initramfs-linux.img | grep themes/kuro
  ```

## The splash shows up late, or the screen flickers first

The graphics driver loads too late, so Plymouth starts on the firmware framebuffer and has
to switch over. For Intel: `MODULES=(i915)` in `/etc/mkinitcpio.conf`, then `sudo mkinitcpio -P`.
For AMD: `amdgpu`. For NVIDIA: `nvidia nvidia_modeset nvidia_uvm nvidia_drm`, plus
`nvidia_drm.modeset=1` as a kernel parameter.

## "Loading Linux ..." / "Loading initial ramdisk ..." before the splash

That's GRUB, not Plymouth. See [bootloader.md](bootloader.md).

## Password prompt: dots yes, text no

The prompt text ("Please enter passphrase ...") and boot messages need a Plymouth label
plugin and a font in the initramfs. Without them the text is missing, but the dots
still work, so you can still unlock.

## The cat is too big or too small

Automatic scaling goes by screen height: below 1440 px → 1x, from 1440 px on → 2x.
If you don't like the result, set `scale_override` at the top of
`/usr/share/plymouth/themes/kuro/kuro.script` and run `sudo plymouth-set-default-theme -R kuro`.

## Testing without rebooting every time

From a TTY (Ctrl+Alt+F3), not from the desktop:

```bash
sudo plymouthd; sudo plymouth show-splash; sleep 8; sudo plymouth quit
```

Including the password prompt:

```bash
sudo plymouthd; sudo plymouth show-splash
sudo plymouth ask-for-password --prompt="Test"
sudo plymouth quit
```
