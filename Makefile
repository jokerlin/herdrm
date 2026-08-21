.PHONY: gen build run install test kit-test clean

gen:
	xcodegen generate

build: gen
	xcodebuild -project HerdrM.xcodeproj -scheme HerdrM -configuration Debug -derivedDataPath build build -skipPackagePluginValidation | tail -5

run: build
	open build/Build/Products/Debug/herdrm.app

# Local dev install: unsigned Release build over /Applications/herdrm.app.
# The version is pinned above the official Sparkle feed so the updater
# doesn't "upgrade" the local build away; deleting in /Applications is
# often permission-denied, so the old copy moves to the Trash instead.
INSTALL_VERSION ?= 0.3.7
install: gen
	xcodebuild -project HerdrM.xcodeproj -scheme HerdrM -configuration Release -derivedDataPath build build -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO MARKETING_VERSION=$(INSTALL_VERSION) CURRENT_PROJECT_VERSION=999 | tail -5
	osascript -e 'tell application "herdrm" to quit' 2>/dev/null || true
	sleep 1
	[ ! -d /Applications/herdrm.app ] || mv /Applications/herdrm.app ~/.Trash/herdrm-$$(date +%s).app
	ditto build/Build/Products/Release/herdrm.app /Applications/herdrm.app
	open /Applications/herdrm.app

kit-test:
	cd Packages/HerdrKit && swift test

test: kit-test

clean:
	rm -rf build HerdrM.xcodeproj Packages/HerdrKit/.build
