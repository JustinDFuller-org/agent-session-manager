APP_NAME = AgentSessionManager
APP_NAME_DEV = AgentSessionManagerDev
BUILD_DIR = .build/release
BUILD_DIR_DEV = .build/debug
APP_BUNDLE = $(APP_NAME).app
APP_BUNDLE_DEV = $(APP_NAME_DEV).app
SCHEME = AgentSessionManager
DERIVED_DATA = .build/DerivedData
RESULTS_PATH = .build/TestResults.xcresult

BUNDLE_ID = com.justinfuller.agent-session-manager
BUNDLE_ID_DEV = com.justinfuller.agent-session-manager.dev

export PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)

# --- Production targets ---

build: build-prd

build-prd:
	swift build -c release

app: app-prd

app-prd: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	xcrun actool AppIcons/Assets.xcassets --compile $(APP_BUNDLE)/Contents/Resources \
		--app-icon AppIcon --output-partial-info-plist /dev/null \
		--platform macosx --minimum-deployment-target 14.0
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_ID)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --deep --sign - $(APP_BUNDLE)
	touch $(APP_BUNDLE)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f $(APP_BUNDLE)

run: run-prd

run-prd: app-prd
	open $(APP_BUNDLE)

watch: watch-prd

watch-prd:
	@echo "Building and running (prod)..."
	@$(MAKE) run-prd
	@touch /tmp/agent-session-manager-watch-prd-sentinel
	@echo "Watching Sources/ and Tests/ for changes... (Ctrl+C to stop)"
	@while true; do \
		if find Sources/ Tests/ -name '*.swift' -newer /tmp/agent-session-manager-watch-prd-sentinel | grep -q .; then \
			echo "Changes detected, rebuilding (prod)..."; \
			touch /tmp/agent-session-manager-watch-prd-sentinel; \
			pkill -x $(APP_NAME) 2>/dev/null || true; \
			sleep 0.5; \
			$(MAKE) run-prd || true; \
		fi; \
		sleep 1; \
	done

# --- Dev targets ---

build-dev:
	swift build -Xswiftc -D -Xswiftc DEV_BUILD

app-dev: build-dev
	mkdir -p $(APP_BUNDLE_DEV)/Contents/MacOS
	mkdir -p $(APP_BUNDLE_DEV)/Contents/Resources
	cp $(BUILD_DIR_DEV)/$(APP_NAME) $(APP_BUNDLE_DEV)/Contents/MacOS/$(APP_NAME_DEV)
	cp Info.plist $(APP_BUNDLE_DEV)/Contents/
	@if [ ! -f .build/dev-assets-compiled ] || \
	    [ AppIcons/Assets.xcassets -nt .build/dev-assets-compiled ]; then \
		xcrun actool AppIcons/Assets.xcassets --compile $(APP_BUNDLE_DEV)/Contents/Resources \
			--app-icon AppIcon-Dev --output-partial-info-plist /dev/null \
			--platform macosx --minimum-deployment-target 14.0; \
		touch .build/dev-assets-compiled; \
	fi
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(APP_NAME_DEV)" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_ID_DEV)" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(APP_NAME_DEV)" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon-Dev" $(APP_BUNDLE_DEV)/Contents/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon-Dev" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon-Dev" $(APP_BUNDLE_DEV)/Contents/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Set :CFBundleIconName AppIcon-Dev" $(APP_BUNDLE_DEV)/Contents/Info.plist
	codesign --force --deep --sign - $(APP_BUNDLE_DEV)
	touch $(APP_BUNDLE_DEV)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f $(APP_BUNDLE_DEV)

run-dev: app-dev
	open $(APP_BUNDLE_DEV)

watch-dev:
	@echo "Building and running (dev)..."
	@$(MAKE) run-dev
	@touch /tmp/agent-session-manager-watch-dev-sentinel
	@echo "Watching Sources/ and Tests/ for changes... (Ctrl+C to stop)"
	@while true; do \
		if find Sources/ Tests/ -name '*.swift' -newer /tmp/agent-session-manager-watch-dev-sentinel | grep -q .; then \
			echo "Changes detected, rebuilding (dev)..."; \
			touch /tmp/agent-session-manager-watch-dev-sentinel; \
			pkill -x $(APP_NAME_DEV) 2>/dev/null || true; \
			sleep 0.5; \
			$(MAKE) run-dev || true; \
		fi; \
		sleep 1; \
	done

# --- Shared targets ---

xcodeproj:
	xcodegen generate

test-ui: xcodeproj
	rm -rf $(RESULTS_PATH)
	xcodebuild test \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-resultBundlePath $(RESULTS_PATH) \
		-derivedDataPath $(DERIVED_DATA)

open-results:
	open $(RESULTS_PATH)

lint:
	swift-format lint --recursive --strict Sources/ Tests/ UITests/

setup-hooks:
	git config core.hooksPath .githooks

restart:
	pkill -x $(APP_NAME) 2>/dev/null || true
	sleep 0.5
	open $(APP_BUNDLE)

restart-dev:
	pkill -x $(APP_NAME_DEV) 2>/dev/null || true
	sleep 0.5
	open $(APP_BUNDLE_DEV)

clean:
	rm -rf $(APP_BUNDLE) $(APP_BUNDLE_DEV) .build $(APP_NAME).xcodeproj
