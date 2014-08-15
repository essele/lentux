#
#
#
#


export LT_VERSION := 2014.08-v0

#
# Work out the base dir and then setup some standard variables
# for out directory structure
#
BASE_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DL_DIR := ${BASE_DIR}/dl

BUILD_DIR_H := $(BASE_DIR)/build/host
BUILD_DIR := $(BASE_DIR)/build/target

TARGET_DIR_H := $(BASE_DIR)/output/host
TARGET_DIR := $(BASE_DIR)/output/target

MCONF := support/kconfig/mconf

TARGETS = 

#include package/*.mk
#include package/*/*.mk

#
# Default target
#
all:	support/luajit
	echo LUAJIT=$(LUAJIT)

#
# Build the mconf binary for the menu configuration system
#
menuconfig:	$(MCONF)
	@$(MCONF) Config.in


#
# Make sure we can get and build luajit
#
include include/luajit.mk

