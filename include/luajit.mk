#
# Early stage makefile to make sure we have a luajit built for the host
# so any lua based scripts can run in a consistent form
#

#
# TODO: move these to a central place
#
#BASE_DIR=/home/essele/dev/embedded
#DL_DIR=$(BASE_DIR)/dl
#H_BUILD_DIR=$(BASE_DIR)/build/host
#H_TARGET_DIR=$(BASE_DIR)/output/host

LUAJIT_VER=2.0.3
LUAJIT_SRC=http://luajit.org/download/LuaJIT-2.0.3.tar.gz
LUAJIT_SRCNAME=LuaJIT-$(LUAJIT_VER).tar.gz
LUAJIT_SRCFILE=$(DL_DIR)/$(LUAJIT_SRCNAME)
LUAJIT_SRCDIR=$(BUILD_DIR_H)/LuaJIT-$(LUAJIT_VER)

LUAJIT=$(BASE_DIR)/support/luajit

#
# Download the source file...
#
$(LUAJIT_SRCFILE):
	mkdir -p $(DL_DIR)
	wget -O $@ $(LUAJIT_SRC)

#
# Unpack the source archive...
#
$(LUAJIT_SRCDIR)/.unpacked:	$(LUAJIT_SRCFILE)
	mkdir -p $(BUILD_DIR_H)
	tar -C $(BUILD_DIR_H) -zxf $(LUAJIT_SRCFILE)
	touch $(LUAJIT_SRCDIR)/.unpacked


#
# Build the binaries...
#
$(LUAJIT_SRCDIR)/src/luajit:	$(LUAJIT_SRCDIR)/.unpacked
	make -C $(LUAJIT_SRCDIR) DESTDIR=$(TARGET_DIR_H) PREFIX=/usr

#
# Install the binary into the support tree...
#
$(LUAJIT):	$(LUAJIT_SRCDIR)/src/luajit
	cp $(LUAJIT_SRCDIR)/src/luajit $(LUAJIT)

#
# Standard syntax make targets for the package...
#

support/luajit:			$(LUAJIT)	
support/luajit/clean:
	rm -fr $(LUAJIT_SRCDIR)
	rm $(LUAJIT)


