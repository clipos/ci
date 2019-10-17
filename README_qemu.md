# Instrumented CLIP OS QEMU image

**WARNING: Those files are provided AS IS for TESTING PURPOSES ONLY and MUST
NOT BE USED IN A PRODUCTION CONTEXT.**

This archive contains a QEMU image with the CLIP OS system pre-installed with
non-production settings for test purposes.

## Launching a standalone virtual machine with QEMU

Use the `qemu.sh` script to launch a standalone QEMU virtual machine.

The LUKS passphrase to unlock the `core_state` partition is available in the
`core_state.keyfile` file.

**Note for non QWERTY keybord layout users:** You may have to enter the key
using the QWERTY keyboard layout!

## SSH access

Use the following commands to connect as root/admin/audit:

```
$ ssh -p 2222 -i ssh_root  root@localhost
$ ssh -p 2222 -i ssh_admin admin@localhost
$ ssh -p 2222 -i ssh_audit audit@localhost
```
