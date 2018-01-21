#!/usr/bin/make -f
#
# Raspberry pi3 makefile by babel.
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

BBLAYERS ?= \
	$(CURDIR)/meta-openembedded \
	$(CURDIR)/meta-qt5 \
	$(CURDIR)/meta-security \
	$(CURDIR)/meta-raspberrypi \
	$(CURDIR)/meta-rpi

GIT ?= git
GIT_REMOTE := $(shell $(GIT) remote)
GIT_USER_NAME := $(shell $(GIT) config user.name)
GIT_USER_EMAIL := $(shell $(GIT) symbolic-ref -q --short HEAD)

hash = $(shell echo $(1) | $(XSUM) | awk '{print $$1}')

.DEFAULT_GOAL = all

### Build init all.

all: init
	@echo
	@echo " Openembedded for Raspberry pi $(GIT_BRANCH) environment has been initialized"
	@echo " MACHINE=... make image"
	@echo
	@echo " or:"
	@echo " cd $(BUILD_DIR)"
	@echo " source env.source"
	@echo " MACHINE=... bitbake console-image"
	@echo

### BBLAYER update

$(BBLAYER):
	[ -d $@ ] || $(MAKE) $(MFLAGS) update

initialize: init

image: init
	@echo 'Building image for $(MACHINE)'
	@. $(TOPDIR)/env.source && cd $(TOPDIR) && bitbake console-image

feed: init
	@echo 'Building feed for $(MACHINE)'
	@. $(TOPDIR)/env.source && cd $(TOPDIR) && bitbake console-image

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
		echo "The openpli OE is now up-to-date."; \
	fi

.PHONY: all image init initialize update usage

BITBAKE_ENV_HASH := $(call hash, \
	'BITBAKE_ENV_VERSION = "0"' \
	'CURDIR = "$(CURDIR)"' \
	)

$(TOPDIR)/env.source: $(DEPDIR)/.env.source.$(BITBAKE_ENV_HASH)
	@echo 'Generating $@'
	@echo 'export BB_ENV_EXTRAWHITE="MACHINE"' > $@
	@echo 'export MACHINE' >> $@
	@echo 'export PATH=$(CURDIR)/openembedded-core/scripts:$(CURDIR)/bitbake/bin:$${PATH}' >> $@


$(TOPDIR)/conf/bblayers.conf: $(DEPDIR)/.bblayers.conf.$(BBLAYERS_CONF_HASH)
	@echo 'Generating $@'
	@test -d $(@D) || mkdir -p $(@D)
	@echo 'LCONF_VERSION = "5"' > $@
	@echo 'BBPATH = "$${TOPDIR}"' >> $@
	@echo 'BBFILES = ""' >> $@
	@echo 'BBLAYERS = "$(BBLAYERS)"' >> $@
