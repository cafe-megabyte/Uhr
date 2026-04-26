APP_NAME  := Uhr
APP_DIR   := $(APP_NAME).app
CONTENTS  := $(APP_DIR)/Contents
MACOS     := $(CONTENTS)/MacOS
RESOURCES := $(CONTENTS)/Resources

SOURCES    := main.m AppDelegate.m ClockWindow.m ClockView.m
FRAMEWORKS := -framework Cocoa -framework WebKit -framework QuartzCore
CFLAGS     := -fobjc-arc -O2 -mmacosx-version-min=10.11

.PHONY: all clean

all: clean $(MACOS)/$(APP_NAME)
	@echo "Build OK → $(APP_DIR)"

$(MACOS)/$(APP_NAME): $(SOURCES) Info.plist Uhr.icns index.html sbbUhr-1.3.js
	mkdir -p $(MACOS) $(RESOURCES)
	cp Info.plist $(CONTENTS)/
	cp Uhr.icns $(RESOURCES)/
	cp index.html $(RESOURCES)/
	cp sbbUhr-1.3.js $(RESOURCES)/
	clang $(FRAMEWORKS) $(CFLAGS) -o $@ $(SOURCES)

clean:
	-pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf $(APP_DIR)
