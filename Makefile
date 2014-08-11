ARCHS = armv7 armv7s arm64
THEOS_PACKAGE_DIR_NAME = debs

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Protean

Protean_FILES = Tweak.xm Protean.mm \
                PRStatusApps.mm UIStatusBarItemView.xm \
                FlipswitchHooks.xm Bluetooth.xm \
                LockscreenStatusBar.xm LSStatusTime.xm \
  	        BatteryPercent.xm

Protean_FRAMEWORKS = UIKit
Protean_LIBRARIES = activator objcipc flipswitch applist
Protean_PRIVATE_FRAMEWORKS = 

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += proteansettings
include $(THEOS_MAKE_PATH)/aggregate.mk