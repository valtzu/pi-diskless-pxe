FW_URL		:= https://raw.githubusercontent.com/raspberrypi/firmware/master/boot

SHELL	= /bin/bash
EFI_BUILD	:= RELEASE
EFI_ARCH	:= AARCH64
EFI_TOOLCHAIN	:= GCC5
EFI_TIMEOUT	:= 3
EFI_FLAGS	:= --pcd=PcdPlatformBootTimeOut=$(EFI_TIMEOUT) --pcd=PcdRamLimitTo3GB=0 --pcd=PcdRamMoreThan3GB=1
EFI_SRC		:= edk2-platforms
EFI_DSC		:= $(EFI_SRC)/Platform/RaspberryPi/RPi4/RPi4.dsc
EFI_FDF		:= $(EFI_SRC)/Platform/RaspberryPi/RPi4/RPi4.fdf
EFI_FD		:= Build/RPi4/$(EFI_BUILD)_$(EFI_TOOLCHAIN)/FV/RPI_EFI.fd

SDCARD_MB	:= 8
export MTOOLSRC	:= mtoolsrc

all: tftpboot.zip boot.img

firmware: firmware/start4.elf firmware/fixup4.dat firmware/bcm2711-rpi-4-b.dtb firmware/overlays/overlay_map.dtb

firmware/%:
	[ -d $(shell dirname $@) ] || mkdir -p $(shell dirname $@)
	wget -O $@ $(FW_URL)/$*

efi: $(EFI_FD)

efi-basetools:
	$(MAKE) -C edk2/BaseTools

$(EFI_FD): efi-basetools $(IPXE_EFI)
	. ./edksetup.sh && \
	build -b $(EFI_BUILD) -a $(EFI_ARCH) -t $(EFI_TOOLCHAIN) -p $(EFI_DSC) $(EFI_FLAGS)

pxe: firmware efi
	$(RM) -rf pxe
	mkdir -p pxe
	cp -r $(sort $(filter-out firmware/kernel%,$(wildcard firmware/*))) pxe/
	cp config.txt $(EFI_FD) edk2/License.txt pxe/

tftpboot.zip: pxe
	$(RM) -f $@
	( pushd $< ; zip -q -r ../$@ * ; popd )

boot.img: pxe
	truncate -s $(SDCARD_MB)M $@
	mpartition -I -c -b 32 -s 32 -h 64 -t $(SDCARD_MB) -a "z:"
	mformat -v "pi-pxe" "z:"
	mcopy -s $(sort $(filter-out pxe/efi%,$(wildcard pxe/*))) "z:"

.PHONY: firmware efi efi-basetools $(EFI_FD) pxe

clean:
	$(RM) -rf firmware Build pxe tftpboot.zip boot.img
