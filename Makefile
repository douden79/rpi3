#!/usr/bin/make -f
#
# Raspberrypi3 makefile by babel.
#
#

# Adjust according to the number CPU cores to use for parallel build.
# Default: Number of processors in /proc/cpuinfo, if present, or 1.
NR_CPU := $(shell [ -f /proc/cpuinfo ] && grep -c '^processor\s*:' /proc/cpuinfo || echo 1)
BB_NUMBER_THREADS ?= $(NR_CPU)
PARALLEL_MAKE ?= -j $(NR_CPU)

XSUM ?= md5sum

BUILD_DIR = $(CURDIR)/build
TOPDIR = $(BUILD_DIR)
DL_DIR = $(CURDIR)/sources
SSTATE_DIR = $(TOPDIR)/sstate-cache
TMPDIR = $(TOPDIR)/tmp
DEPDIR = $(TOPDIR)/.deps

# ========================================================================================================
# layer define
# ========================================================================================================
CONFFILES = \
	$(TOPDIR)/conf/bblayers.conf \
	$(TOPDIR)/conf/local.conf \
	$(TOPDIR)/conf/sanity_info \
	$(TOPDIR)/conf/templateconf.cfg \
	$(TOPDIR)/env.source

CONFDEPS = \
	$(DEPDIR)/.bblayers.conf.$(BBLAYERS_CONF_HASH) \
	$(DEPDIR)/.local.conf.$(LOCAL_CONF_HASH) \
	$(DEPDIR)/.sanity_info.$(SANITY_CONF_HASH) \
	$(DEPDIR)/.templateconf.cfg.$(TEMPLATE_CONF_HASH) \
	$(DEPDIR)/.env.source.$(BITBAKE_ENV_HASH)

# ========================================================================================================
# Git config
# ========================================================================================================
GIT ?= git
GIT_REMOTE := $(shell $(GIT) remote)
GIT_USER_NAME := $(shell $(GIT) config user.name)
GIT_USER_EMAIL := $(shell $(GIT) config user.email)
GIT_BRANCH := $(shell $(GIT) symbolic-ref -q --short HEAD)

hash = $(shell echo $(1) | $(XSUM) | awk '{print $$1}')

.DEFAULT_GOAL := all
all: init
	@echo
	@echo "Openembedded for the Raspberrypi3 $(GIT_BRANCH) environment has been initialized"
	@echo "properly. Now you can start building your image, by doing either:"
	@echo
	@echo " MACHINE=... make image"
	@echo
	@echo "	or:"
	@echo
	@echo " cd $(BUILD_DIR)"
	@echo " source env.source"
	@echo " MACHINE=... bitbake console-image"
	@echo
	@echo "	or, if you want to build not just the image, but the optional packages in the feed as well:"
	@echo
	@echo " MACHINE=... make feed"
	@echo "	or:"
	@echo " MACHINE=... bitbake console-image-feed"
	@echo

$(BBLAYERS):
	[ -d $@ ] || $(MAKE) $(MFLAGS) update

initialize: init

init: $(BBLAYERS) $(CONFFILES)

image: init
	@echo 'Building image for $(MACHINE)'
	@. $(TOPDIR)/env.source && cd $(TOPDIR) && bitbake console-image

console-image: init
	@echo 'Building image for $(MACHINE)'
	@. $(TOPDIR)/env.source && cd $(TOPDIR) && bitbake console-image

qt5-image:
	@echo 'Building image for $(MACHINE)'
	@. $(TOPDIR)/env.source && cd $(TOPDIR) && bitbake qt5-image

qt5-basic-image:
	@echo 'Building image for $(MACHINE)'
	@. $(TOPDIR)/env.source && cd $(TOPDIR) && bitbake qt5-basic-image



feed: init
	@echo 'Building feed for $(MACHINE)'
	@. $(TOPDIR)/env.source && cd $(TOPDIR) && bitbake console-image-feed

update:
	@echo 'Updating Git repositories...'
	@HASH=`$(XSUM) $(MAKEFILE_LIST)`; \
	if [ -n "$(GIT_REMOTE)" ]; then \
		$(GIT) pull --ff-only || $(GIT) pull --rebase; \
	fi; \
	if [ "$$HASH" != "`$(XSUM) $(MAKEFILE_LIST)`" ]; then \
		echo 'Makefile changed. Restarting...'; \
		$(MAKE) $(MFLAGS) --no-print-directory $(MAKECMDGOALS); \
	else \
		$(GIT) submodule sync && \
		$(GIT) submodule update --init && \
		echo "The raspberrypi is now up-to-date."; \
	fi



# ========================================================================================================
# preference
# ========================================================================================================

.PHONY: all image init initialize update usage

BITBAKE_ENV_HASH := $(call hash, \
	'BITBAKE_ENV_VERSION = "0"' \
	'CURDIR = "$(CURDIR)"' \
	)

$(TOPDIR)/env.source: $(DEPDIR)/.env.source.$(BITBAKE_ENV_HASH)
	@echo 'Generating $@'
	@test -d $(@D) || mkdir -p $(@D)
	@echo 'export BB_ENV_EXTRAWHITE="MACHINE"' > $@
	@echo 'export MACHINE' >> $@
	@echo 'export PATH=$(CURDIR)/meta-rpi/scripts:$(CURDIR)/bitbake/bin:$${PATH}' >> $@

LOCAL_CONF_HASH := $(call hash, \
	'LOCAL_CONF_VERSION = "0"' \
	'CURDIR = "$(CURDIR)"' \
	'TOPDIR = "$(TOPDIR)"' \
	)

$(TOPDIR)/conf/local.conf: $(DEPDIR)/.local.conf.$(LOCAL_CONF_HASH)
	@echo 'Generating $@'
	@test -d $(@D) || mkdir -p $(@D)
	@echo '# Local configuration for meta-rpi images' > $@
	@echo '# Yocto Project 2.4 Poky distribution [rocko] branch' >> $@
	@echo '# This is a sysvinit system' >> $@
	@echo 'LICENSE_FLAGS_WHITELIST = "commercial"' >> $@
	@echo 'DISTRO_FEATURES = "ext2 pam opengl usbhost ${DISTRO_FEATURES_LIBC}"' >> $@
	@echo 'DISTRO_FEATURES_BACKFILL_CONSIDERED += "pulseaudio"' >> $@
	@echo 'PREFERRED_PROVIDER_jpeg = "libjpeg-turbo"' >> $@
	@echo 'PREFERRED_PROVIDER_jpeg-native = "libjpeg-turbo-native"' >> $@
	@echo 'PREFERRED_PROVIDER_udev = "eudev"' >> $@
	@echo 'VIRTUAL-RUNTIME_init_manager = "sysvinit"' >> $@
	@echo 'MACHINE_FEATURES_remove = "apm"' >> $@
	@echo 'IMAGE_FSTYPES = "tar.xz"' >> $@
	@echo 'PREFERRED_VERSION_linux-raspberrypi = "4.9.%"' >> $@
	@echo '# Choose the board you are building for' >> $@
	@echo 'MACHINE ?= "${MACHINE}"' >> $@
	@echo '# Choices are Image or zImage if NOT using u-boot (no u-boot is the default)' >> $@
	@echo '# Choices are uImage or zImage if using u-boot, though if you choose zImage' >> $@
	@echo '# with u-boot you will also have to change the boot script boot command' >> $@
	@echo 'KERNEL_IMAGETYPE = "zImage"' >> $@
	@echo 'ENABLE_UART="1"' >> $@
	@echo 'DISTRO = "poky"' >> $@
	@echo 'PACKAGE_CLASSES = "package_ipk"' >> $@
	@echo 'SDKMACHINE = "x86_64"' >> $@
	@echo 'INHERIT += "extrausers"' >> $@
	@echo 'EXTRA_USERS_PARAMS = "usermod -P jumpnowtek root; "' >> $@
	@echo 'USER_CLASSES = "image-mklibs image-prelink"' >> $@
	@echo 'PATCHRESOLVE = "noop"' >> $@
	@echo 'RM_OLD_IMAGE = "1"' >> $@
	@echo 'INHERIT += "rm_work"' >> $@
	@echo 'CONF_VERSION = "1"' >> $@
	@echo '#EXTRA_IMAGE_FEATURES = "debug-tweaks"' >> $@

BBLAYERS_CONF_HASH := $(call hash, \
	'BBLAYERS_CONF_VERSION = "0"' \
	'CURDIR = "$(CURDIR)"' \
	'BBLAYERS = "$(BBLAYERS)"' \
	)

$(TOPDIR)/conf/bblayers.conf: $(DEPDIR)/.bblayers.conf.$(BBLAYERS_CONF_HASH)
	@echo 'Generating $@'
	@test -d $(@D) || mkdir -p $(@D)
	@echo 'POKY_BBLAYERS_CONF_VERSION = "2"' > $@
	@echo 'BBPATH = "${CURDIR}/meta"' >> $@
#	@echo 'BBPATH = "${TOPDIR}"' >> $@
	@echo 'BBFILES ?= ""' >> $@
	@echo 'BBLAYERS ?= " \' >> $@
	@echo '$(CURDIR)/meta \' >> $@
	@echo '$(CURDIR)/meta-poky \' >> $@
	@echo '$(CURDIR)/meta-yocto-bsp \' >> $@
	@echo '$(CURDIR)/meta-openembedded/meta-oe \' >> $@
	@echo '$(CURDIR)/meta-openembedded/meta-multimedia \' >> $@
	@echo '$(CURDIR)/meta-openembedded/meta-networking \' >> $@
	@echo '$(CURDIR)/meta-openembedded/meta-perl \' >> $@
	@echo '$(CURDIR)/meta-openembedded/meta-python \' >> $@
	@echo '$(CURDIR)/meta-qt5 \' >> $@
	@echo '$(CURDIR)/meta-raspberrypi \' >> $@
	@echo '$(CURDIR)/meta-security \' >> $@
	@echo '$(CURDIR)/meta-rpi"' >> $@

SANITY_CONF_HASH := $(call hash, \
	'SANITY_CONF_VERSION = "0"' \
	'CURDIR = "$(CURDIR)"' \
	'SANITY = "$(SANITY)"' \
	)

$(TOPDIR)/conf/sanity_info: $(DEPDIR)/.sanity_info.$(SANITY_CONF_HASH)
	@echo 'Generating $@'
	@test -d $(@D) || mkdir -p $(@D)
	@echo 'SANITY_VERSION 1' > $@
	@echo 'TMPDIR $(BUILD_DIR)/tmp' >> $@
	@echo 'SSTATE_DIR $(BUILD_DIR)/sstate-cache' >> $@

TEMPLATE_CONF_HASH := $(call hash, \
	'TEMPLATE_CONF_VERSION = "0"' \
	'CURDIR = "$(CURDIR)"' \
	'TEMPLATE = "$(TEMPLATE)"' \
	)

$(TOPDIR)/conf/templateconf.cfg: $(DEPDIR)/.templateconf.cfg.$(TEMPLATE_CONF_HASH)
	@echo 'Generating $@'
	@test -d $(@D) || mkdir -p $(@D)
	@echo 'meta-poky/conf' > $@

$(CONFDEPS):
	@test -d $(@D) || mkdir -p $(@D)
	@$(RM) $(basename $@).*
	@touch $@
