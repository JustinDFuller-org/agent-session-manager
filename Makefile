APP_NAME = AgentSessionManager
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
SCHEME = AgentSessionManager
DERIVED_DATA = .build/DerivedData
RESULTS_PATH = .build/TestResults.xcresult

export PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)

build:
	swift build -c release

app: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.justinfuller.agent-session-manager" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" $(APP_BUNDLE)/Contents/Info.plist

run: app
	open $(APP_BUNDLE)

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

setup-hooks:
	git config core.hooksPath .githooks

restart:
	pkill -x $(APP_NAME) 2>/dev/null || true
	sleep 0.5
	open $(APP_BUNDLE)

watch:
	@echo "Building and running..."
	@$(MAKE) run
	@touch /tmp/agent-session-manager-watch-sentinel
	@echo "Watching Sources/ and Tests/ for changes... (Ctrl+C to stop)"
	@while true; do \
		if find Sources/ Tests/ -name '*.swift' -newer /tmp/agent-session-manager-watch-sentinel | grep -q .; then \
			echo "Changes detected, rebuilding..."; \
			touch /tmp/agent-session-manager-watch-sentinel; \
			pkill -x $(APP_NAME) 2>/dev/null || true; \
			sleep 0.5; \
			$(MAKE) run || true; \
		fi; \
		sleep 1; \
	done

clean:
	rm -rf $(APP_BUNDLE) .build $(APP_NAME).xcodeproj
