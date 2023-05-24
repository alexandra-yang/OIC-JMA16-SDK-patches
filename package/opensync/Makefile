#
# OpenSync QSDK package
#
# Requires that OpenSync build root is in $(PKG_DIR)/src/
#

include $(TOPDIR)/rules.mk

PKG_NAME := opensync
PKG_RELEASE := 1

include $(INCLUDE_DIR)/package.mk

OPENSYNC_DEPS := openvswitch libev jansson zlib openssl protobuf-c libprotobuf-c libmosquitto qca-wifi libnl qca-cfg80211 kmod-qca-wifi
OPENSYNC_DEPS += libcurl libiw mxml libpcap btconfig qca-hostap libnetfilter-conntrack libmnl libstdc
OPENSYNC_DEPS += libfdt libblkid
OPENSYNC_DEPS += libffi
OPENSYNC_DEPS += libzmq
OPENSYNC_DEPS += @BUSYBOX_CONFIG_TIMEOUT
OPENSYNC_DEVSHELL ?= n

OPENSYNC_DEPS := $(foreach X,$(OPENSYNC_DEPS),+$(X))
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

define Package/opensync
  SECTION    := net
  CATEGORY   := OpenSync
  TITLE      := OpenSync QSDK package
  MAINTAINER := OpenSync <info@opensync.io>
  DEPENDS    := $(OPENSYNC_DEPS)
endef

define Package/opensync/description
  OpenSync QSDK package
endef

define Package/opensync/config
	source "$(SOURCE)/Config.in"
endef

define Build/Configure
	@echo === Build/Configure
endef

define Build/Prepare
	@echo === Build/Prepare
	@echo "PKG_BUILD_DIR: $(PKG_BUILD_DIR)"
	@echo "OPENSYNC_TARGET: $(CONFIG_OPENSYNC_TARGET)"
	@echo "STAGING_DIR: $(STAGING_DIR)"
	@echo "OPENSYNC_SRC: $(OPENSYNC_SRC)"

	@if [ -z "$(OPENSYNC_SRC)" ]; then \
		echo "#####"; \
		echo "##### OpenSync sources missing; specify OPENSYNC_SRC=path"; \
		echo "#####"; \
		exit 1; \
	fi

	@mkdir -p $(PKG_BUILD_DIR)
	@ln -sf "$(OPENSYNC_SRC)" "$(PKG_BUILD_DIR)/src"

	$(Build/Prepare/Default)
endef

export MAKE_CMD := $(MAKE) -C $(PKG_BUILD_DIR)/src/core V=1 \
		TARGET=$(CONFIG_OPENSYNC_TARGET) \
		TOOLCHAIN_DIR=$(TOOLCHAIN_DIR) \
		TARGET_CROSS=$(TARGET_CROSS) \
		TARGET_DIR_NAME=$(TARGET_DIR_NAME) \
		CONF_OPENSYNC_NL_SUPPORT=$(CONFIG_OPENSYNC_NL_SUPPORT) \
		ARCH_64BIT=$(CONFIG_ARCH_64BIT)

define Build/Compile
	@echo === Build/Compile
	@echo
	@echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	@echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	@echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	@echo "PKG_BUILD_DIR: $(PKG_BUILD_DIR)"
	@echo "OPENSYNC_TARGET: $(CONFIG_OPENSYNC_TARGET)"
	@echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>"

	test $(OPENSYNC_DEVSHELL) = n || { echo starting devshell...; $(SHELL); }
	eval $(MAKE_CMD) rootfs
	@echo
endef

define Package/opensync/install
	@echo ======Package/opensync/install
	$(MAKE) -C $(PKG_BUILD_DIR)/src/core rootfs-install-only \
		TARGET=$(CONFIG_OPENSYNC_TARGET) \
		INSTALL_ROOTFS_DIR=$(1)
endef

define Build/Clean
	@echo === Build/Clean $(CONFIG_OPENSYNC_TARGET)
	@echo PKG_BUILD_DIR: $(PKG_BUILD_DIR)
	$(MAKE) -C $(PKG_BUILD_DIR)/src/core clean \
		TARGET=$(CONFIG_OPENSYNC_TARGET)
endef

# Don't run RSTRIP as we need rpath for OpenSync lib
RSTRIP := @echo SKIP RSTRIP:

$(eval $(call BuildPackage,opensync))
