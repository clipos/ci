#!/bin/bash

echo ""
echo "---------------------------------------------------------------------"
echo "[*] Launching a standalone CLIP OS virtual machine..."
echo "[*] See README.md for instructions."
echo "---------------------------------------------------------------------"
echo ""

qemu-system-x86_64 \
    -name guest=clipos-instrumented,debug-threads=on \
    -machine pc-q35-2.11,accel=kvm,usb=off,vmport=off,smm=on,dump-guest-core=off \
    -drive file=./OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on \
    -drive file=./OVMF_VARS.fd,if=pflash,format=raw,unit=1 \
    -m 2048 \
    -overcommit mem-lock=off \
    -smp 2,sockets=2,cores=1,threads=1 \
    -no-user-config \
    -nodefaults \
    -rtc base=utc,driftfix=slew \
    -global kvm-pit.lost_tick_policy=delay \
    -no-hpet \
    -no-shutdown \
    -global ICH9-LPC.disable_s3=1 \
    -global ICH9-LPC.disable_s4=1 \
    -boot strict=on \
    -device ich9-usb-ehci1,id=usb,bus=pcie.0,addr=0x5.0x7 \
    -device ich9-usb-uhci1,masterbus=usb.0,firstport=0,bus=pcie.0,multifunction=on,addr=0x5 \
    -device ich9-usb-uhci2,masterbus=usb.0,firstport=2,bus=pcie.0,addr=0x5.0x1 \
    -device ich9-usb-uhci3,masterbus=usb.0,firstport=4,bus=pcie.0,addr=0x5.0x2 \
    -netdev user,id=network0,hostfwd=tcp:127.0.0.1:2222-:22 \
    -device virtio-net-pci,netdev=network0,mac=52:54:00:12:34:56,bus=pcie.0,addr=0x3 \
    -device virtio-serial-pci,id=virtio-serial0,bus=pcie.0,addr=0x6 \
    -drive file=./main.qcow2,format=qcow2,if=none,id=drive-virtio-disk0 \
    -device virtio-blk-pci,scsi=off,bus=pcie.0,addr=0x7,drive=drive-virtio-disk0,id=virtio-disk0,bootindex=1 \
    -device qxl-vga,id=video0,ram_size=67108864,vram_size=67108864,vram64_size_mb=0,vgamem_mb=16,max_outputs=1,bus=pcie.0,addr=0x2 \
    -device intel-hda,id=sound0,bus=pcie.0,addr=0x4 \
    -device hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0 \
    -device virtio-balloon-pci,id=balloon0,bus=pcie.0,addr=0x8 \
    -object rng-random,id=objrng0,filename=/dev/urandom \
    -device virtio-rng-pci,rng=objrng0,id=rng0,bus=pcie.0,addr=0x9 \
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
    -msg timestamp=on
