##
## This file is part of the coremenu project.
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; version 2 of the License.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##

src := $(CURDIR)
srctree := $(src)
srck := $(src)/../../util/kconfig
coremenu_obj := $(src)/build
objk := $(src)/build/util/kconfig

ifeq ($(filter %clean,$(MAKECMDGOALS)),)
export KERNELVERSION      := 0.1.0
export KCONFIG_AUTOHEADER := $(coremenu_obj)/config.h
export KCONFIG_AUTOCONFIG := $(coremenu_obj)/auto.conf
export KCONFIG_DEPENDENCIES := $(coremenu_obj)/auto.conf.cmd
export KCONFIG_SPLITCONFIG := $(coremenu_obj)/config
export KCONFIG_TRISTATE := $(coremenu_obj)/tristate.conf
export KCONFIG_CONFIG := $(CURDIR)/.config
export KCONFIG_NEGATIVES := 1
export Kconfig := Kconfig

export V := $(V)

CONFIG_SHELL := sh
KBUILD_DEFCONFIG := configs/defconfig
UNAME_RELEASE := $(shell uname -r)
HAVE_DOTCONFIG := $(wildcard .config)
MAKEFLAGS += -rR --no-print-directory

# Make is silent per default, but 'make V=1' will show all compiler calls.
ifneq ($(V),1)
.SILENT:
endif

HOSTCC ?= gcc
HOSTCXX ?= g++
HOSTCFLAGS := -I$(srck) -I$(objk)
HOSTCXXFLAGS := -I$(srck) -I$(objk)

LIBPAYLOAD_PATH := $(realpath ../libpayload)
LIBPAYLOAD_OBJ := $(coremenu_obj)/libpayload
HAVE_LIBPAYLOAD := $(wildcard $(LIBPAYLOAD_OBJ)/lib/libpayload.a)
LIBPAYLOAD_CONFIG ?= configs/defconfig-tinycurses
OBJCOPY ?= objcopy

INCLUDES = -I$(coremenu_obj) -include $(LIBPAYLOAD_OBJ)/include/kconfig.h -I$(src)/../../src/commonlib/include
OBJECTS = coremenu.o
OBJS    = $(patsubst %,$(coremenu_obj)/%,$(OBJECTS))
TARGET  = $(coremenu_obj)/coremenu.elf

all: real-all

# in addition to the dependency below, create the file if it doesn't exist
# to silence warnings about a file that would be generated anyway.
$(if $(wildcard .xcompile),,$(eval $(shell ../../util/xcompile/xcompile $(XGCCPATH) > .xcompile || rm -f .xcompile)))
.xcompile: ../../util/xcompile/xcompile
	$< $(XGCCPATH) > $@.tmp
	\mv -f $@.tmp $@ 2> /dev/null || rm -f $@.tmp $@

CONFIG_COMPILER_GCC := y
ARCH-y     := x86_32

include .xcompile

CC := $(CC_$(ARCH-y))
AS := $(AS_$(ARCH-y))
OBJCOPY := $(OBJCOPY_$(ARCH-y))

LPCC := CC="$(CC)" $(LIBPAYLOAD_OBJ)/bin/lpgcc
LPAS := AS="$(AS)" $(LIBPAYLOAD_OBJ)/bin/lpas

CFLAGS += -Wall -Wextra -Wmissing-prototypes -Wvla -Werror
CFLAGS += -Os -fno-builtin $(CFLAGS_$(ARCH-y)) $(INCLUDES)

ifneq ($(strip $(HAVE_DOTCONFIG)),)
include $(src)/.config
real-all: $(TARGET)

$(TARGET): $(src)/.config $(coremenu_obj)/config.h $(OBJS) libpayload
	printf "    LPCC       $(subst $(CURDIR)/,,$(@)) (LINK)\n"
	$(LPCC) -o $@ $(OBJS)
	$(OBJCOPY) --only-keep-debug $@ $(TARGET).debug
	$(OBJCOPY) --strip-debug $@
	$(OBJCOPY) --add-gnu-debuglink=$(TARGET).debug $@

$(coremenu_obj)/%.S.o: $(src)/%.S libpayload
	printf "    LPAS       $(subst $(CURDIR)/,,$(@))\n"
	$(LPAS) -o $@ $<

$(coremenu_obj)/%.o: $(src)/%.c libpayload
	printf "    LPCC       $(subst $(CURDIR)/,,$(@))\n"
	$(LPCC) $(CFLAGS) -c -o $@ $<

else
real-all: config
endif

defaultbuild:
	$(MAKE) olddefconfig
	$(MAKE) all

ifneq ($(strip $(HAVE_LIBPAYLOAD)),)
libpayload:
	printf "Found Libpayload $(LIBPAYLOAD_OBJ).\n"
else
LPOPTS=obj="$(CURDIR)/lpbuild" DOTCONFIG="$(CURDIR)/lp.config"
libpayload:
	printf "Building libpayload @ $(LIBPAYLOAD_PATH).\n"
	$(MAKE) -C $(LIBPAYLOAD_PATH) $(LPOPTS) distclean coremenu_obj=$(coremenu_obj)/libptmp
	#$(MAKE) -C $(LIBPAYLOAD_PATH) $(LPOPTS) defconfig KBUILD_DEFCONFIG=$(LIBPAYLOAD_CONFIG)
	$(MAKE) -C $(LIBPAYLOAD_PATH) $(LPOPTS) defconfig KBUILD_DEFCONFIG=$(CURDIR)/lpcfg
	$(MAKE) -C $(LIBPAYLOAD_PATH) $(LPOPTS) install DESTDIR=$(coremenu_obj)
endif

$(coremenu_obj)/config.h:
	$(MAKE) oldconfig

$(shell mkdir -p $(coremenu_obj) $(objk)/lxdialog $(KCONFIG_SPLITCONFIG))

include $(srck)/Makefile

.PHONY: $(PHONY) prepare

else

clean:
	rm -rf build/*.elf build/*.o .xcompile

distclean: clean
	rm -rf build lpbuild
	rm -f .config* lp.config*

.PHONY: clean distclean
endif
