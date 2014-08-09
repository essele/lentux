

BASE_DIR := $(shell pwd)
BUILD_DIR := $(BASE_DIR)/build

MCONF := support/kconfig/mconf

menuconfig:	$(MCONF)
	@$(MCONF) Config.in

