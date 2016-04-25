// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

LOCAL_PATH := $(call my-dir)
cflags     := -frtti -Wall -Wextra -Wno-unused-parameter

core_path  := $(call my-dir)/../../../../vgcore
core_inc   := $(core_path)/core/include
core_lib   := $(core_path)/android/TouchVGCore/obj/local/$(APP_ABI)

core_incs  := $(core_inc) \
              $(core_inc)/canvas \
              $(core_inc)/geom \
              $(core_inc)/graph \
              $(core_inc)/jsonstorage \
              $(core_inc)/shape \
              $(core_inc)/gshape \
              $(core_inc)/storage \
              $(core_inc)/shapedoc \
              $(core_inc)/cmd \
              $(core_inc)/view \
              $(core_inc)/record

cplay_src  := ../../../core

include $(CLEAR_VARS)
LOCAL_MODULE    := libTouchVGCore
LOCAL_SRC_FILES := $(core_lib)/libTouchVGCore.a
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE           := vgplay
LOCAL_LDLIBS           := -L$(SYSROOT)/usr/lib -llog
LOCAL_PRELINK_MODULE   := false
LOCAL_CFLAGS           := $(cflags)
LOCAL_STATIC_LIBRARIES := libTouchVGCore

ifeq ($(TARGET_ARCH),arm)
# Ignore "note: the mangling of 'va_list' has changed in GCC 4.4"
LOCAL_CFLAGS += -Wno-psabi
endif
ifeq ($(TARGET_ARCH),x86)
# For SWIG, http://stackoverflow.com/questions/6753241
LOCAL_CFLAGS += -fno-strict-aliasing
endif

LOCAL_C_INCLUDES       := $(core_incs) $(core_inc)/../src/view $(cplay_src)
LOCAL_SRC_FILES        := $(cplay_src)/gicoreplay.cpp \
                          vgplay_java_wrap.cpp

include $(BUILD_SHARED_LIBRARY)
