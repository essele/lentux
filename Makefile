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

.PHONY: build-dirs

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

#
# Build all of the makefiles for our packages
#
PK_FILES=$(wildcard package/*.pk)
PMK_FILES=$(foreach p,$(PK_FILES),build/makefiles/$(basename $(notdir $(p))).mk)

-include $(PMK_FILES)

$(PMK_FILES): build/makefiles/%.mk : package/%.pk
	if [ ! -d $(@D) ]; then \
		echo "Would create $(@D)"; \
	fi
	echo "Would run $< ($@)"


lee: 
	echo LEE




