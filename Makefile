APP_NAME = AgentSessionManager
SCREENSHOTS_DIR = screenshots
APP_NAME_DEV = AgentSessionManagerDev
GIT_COMMON_ROOT := $(shell dirname "$$(git rev-parse --path-format=absolute --git-common-dir)")
BUILD_DIR = .build/release
BUILD_DIR_DEV = .build/debug
APP_BUNDLE = $(GIT_COMMON_ROOT)/$(APP_NAME).app
APP_BUNDLE_DEV = $(GIT_COMMON_ROOT)/$(APP_NAME_DEV).app
SCHEME = AgentSessionManager
DERIVED_DATA = .build/DerivedData
RESULTS_PATH = .build/TestResults.xcresult

BUNDLE_ID = com.justinfuller.agent-session-manager
BUNDLE_ID_DEV = com.justinfuller.agent-session-manager.dev

LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
ICON_PARTIAL_PRD = .build/icon-partial-prd.plist
ICON_PARTIAL_DEV = .build/icon-partial-dev.plist

export PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)

# --- Production targets ---

build: build-prd

build-prd:
	swift build -c release

app: app-prd

dist: app-prd
	@scripts/dist.sh "$(APP_BUNDLE)"

app-prd: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	mkdir -p .build
	xcrun actool AppIcons/Assets.xcassets --compile $(APP_BUNDLE)/Contents/Resources \
		--app-icon AppIcon --standalone-icon-behavior all \
		--output-partial-info-plist $(ICON_PARTIAL_PRD) \
		--platform macosx --minimum-deployment-target 14.0
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_ID)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" $(APP_BUNDLE)/Contents/Info.plist
	@ICON_FILE=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" $(ICON_PARTIAL_PRD) 2>/dev/null); \
	ICON_NAME=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" $(ICON_PARTIAL_PRD) 2>/dev/null); \
	if [ -n "$$ICON_FILE" ]; then \
		/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" $(APP_BUNDLE)/Contents/Info.plist 2>/dev/null || true; \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $$ICON_FILE" $(APP_BUNDLE)/Contents/Info.plist; \
	fi; \
	if [ -n "$$ICON_NAME" ]; then \
		/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" $(APP_BUNDLE)/Contents/Info.plist 2>/dev/null || true; \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string $$ICON_NAME" $(APP_BUNDLE)/Contents/Info.plist; \
	fi
	@COMMIT=$$(git rev-parse HEAD 2>/dev/null); \
	BRANCH=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null); \
	DATE=$$(git show -s --format=%cI HEAD 2>/dev/null); \
	PLIST=$(APP_BUNDLE)/Contents/Info.plist; \
	for kv in "ASMSourceCommit:$$COMMIT" "ASMSourceBranch:$$BRANCH" "ASMSourceCommitDate:$$DATE"; do \
		key=$${kv%%:*}; val=$${kv#*:}; \
		/usr/libexec/PlistBuddy -c "Delete :$$key" $$PLIST 2>/dev/null || true; \
		[ -n "$$val" ] && /usr/libexec/PlistBuddy -c "Add :$$key string $$val" $$PLIST; \
	done
	codesign --force --deep --sign - $(APP_BUNDLE)
	touch $(APP_BUNDLE)
	$(MAKE) repair-launch-services

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
	mkdir -p .build
	@if [ ! -f .build/dev-assets-compiled ] || \
	    [ AppIcons/Assets.xcassets -nt .build/dev-assets-compiled ] || \
	    [ Makefile -nt .build/dev-assets-compiled ]; then \
		xcrun actool AppIcons/Assets.xcassets --compile $(APP_BUNDLE_DEV)/Contents/Resources \
			--app-icon AppIcon-Dev --standalone-icon-behavior all \
			--output-partial-info-plist $(ICON_PARTIAL_DEV) \
			--platform macosx --minimum-deployment-target 14.0; \
		touch .build/dev-assets-compiled; \
	fi
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(APP_NAME_DEV)" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_ID_DEV)" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(APP_NAME_DEV)" $(APP_BUNDLE_DEV)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" $(APP_BUNDLE_DEV)/Contents/Info.plist
	@ICON_FILE=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" $(ICON_PARTIAL_DEV) 2>/dev/null); \
	ICON_NAME=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" $(ICON_PARTIAL_DEV) 2>/dev/null); \
	if [ -n "$$ICON_FILE" ]; then \
		/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" $(APP_BUNDLE_DEV)/Contents/Info.plist 2>/dev/null || true; \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $$ICON_FILE" $(APP_BUNDLE_DEV)/Contents/Info.plist; \
	fi; \
	if [ -n "$$ICON_NAME" ]; then \
		/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" $(APP_BUNDLE_DEV)/Contents/Info.plist 2>/dev/null || true; \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string $$ICON_NAME" $(APP_BUNDLE_DEV)/Contents/Info.plist; \
	fi
	@COMMIT=$$(git rev-parse HEAD 2>/dev/null); \
	BRANCH=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null); \
	DATE=$$(git show -s --format=%cI HEAD 2>/dev/null); \
	PLIST=$(APP_BUNDLE_DEV)/Contents/Info.plist; \
	for kv in "ASMSourceCommit:$$COMMIT" "ASMSourceBranch:$$BRANCH" "ASMSourceCommitDate:$$DATE"; do \
		key=$${kv%%:*}; val=$${kv#*:}; \
		/usr/libexec/PlistBuddy -c "Delete :$$key" $$PLIST 2>/dev/null || true; \
		[ -n "$$val" ] && /usr/libexec/PlistBuddy -c "Add :$$key string $$val" $$PLIST; \
	done
	codesign --force --deep --sign - $(APP_BUNDLE_DEV)
	touch $(APP_BUNDLE_DEV)
	$(MAKE) repair-launch-services

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

test-ui-dev: xcodeproj
	rm -rf $(RESULTS_PATH)
	xcodebuild test \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Dev \
		-destination 'platform=macOS' \
		-resultBundlePath $(RESULTS_PATH) \
		-derivedDataPath $(DERIVED_DATA)

screenshots: xcodeproj
	rm -rf $(SCREENSHOTS_DIR)
	mkdir -p $(SCREENSHOTS_DIR)
	rm -rf $(RESULTS_PATH)
	TEST_RUNNER_SCREENSHOTS_OUTPUT_PATH="$(CURDIR)/$(SCREENSHOTS_DIR)" xcodebuild test \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Dev \
		-destination 'platform=macOS' \
		-resultBundlePath $(RESULTS_PATH) \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing:AgentSessionManagerUITests/ScreenshotTests \
		-only-testing:AgentSessionManagerUITests/ScreenshotInjectedTests

build-for-testing: xcodeproj
	xcodebuild build-for-testing \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Dev \
		-destination 'platform=macOS' \
		-derivedDataPath $(DERIVED_DATA)

pr-screenshots:
	@bash "$(CURDIR)/scripts/pr-screenshots.sh"

reset-app-state:
	@for f in sessions.json settings.json codex-settings.json cursor-settings.json \
    opencode-settings.json opencode-env-var-settings.json \
    statusline-settings.json active-tools-settings.json \
    default-branch.json notification-settings.json restart-settings.json \
    worktree-cleanup.json existing-worktree-management.json debug-settings.json \
    pr-tracking-settings.json tracing-settings.json pr-polling-settings.json \
    terminal-settings.json worktree-base-ref.json exit-behavior.json \
    env-var-settings.json profiles.json session-name-settings.json \
    shell-settings.json onboarding-settings.json activity-indicator-settings.json \
	    focus-mode-settings.json update-check-settings.json; do \
		rm -f "$(HOME)/Library/Application Support/agent-session-manager/$$f"; \
	done
	@rm -rf "$(HOME)/Library/Application Support/agent-session-manager/traces"
	@rm -rf "$(HOME)/Library/Application Support/agent-session-manager/invariants"
	@echo "App state reset."

reset-app-state-dev:
	@for f in sessions.json settings.json codex-settings.json cursor-settings.json \
    opencode-settings.json opencode-env-var-settings.json \
    statusline-settings.json active-tools-settings.json \
    default-branch.json notification-settings.json restart-settings.json \
    worktree-cleanup.json existing-worktree-management.json debug-settings.json \
    pr-tracking-settings.json tracing-settings.json pr-polling-settings.json \
    terminal-settings.json worktree-base-ref.json exit-behavior.json \
    env-var-settings.json profiles.json session-name-settings.json \
    shell-settings.json onboarding-settings.json activity-indicator-settings.json \
	    focus-mode-settings.json update-check-settings.json; do \
		rm -f "$(HOME)/Library/Application Support/agent-session-manager.dev/$$f"; \
		rm -f "$(HOME)/Library/Application Support/dev/$$f"; \
	done
	@rm -rf "$(HOME)/Library/Application Support/agent-session-manager.dev/traces"
	@rm -rf "$(HOME)/Library/Application Support/dev/traces"
	@rm -rf "$(HOME)/Library/Application Support/agent-session-manager.dev/invariants"
	@rm -rf "$(HOME)/Library/Application Support/dev/invariants"
	@echo "Dev app state reset."

open-results:
	open $(RESULTS_PATH)

lint:
	swift-format lint --recursive --strict Sources/ Tests/ UITests/

setup-hooks:
	git config core.hooksPath "$$(dirname $$(git rev-parse --git-common-dir))/.githooks"

restart:
	pkill -x $(APP_NAME) 2>/dev/null || true
	sleep 0.5
	open $(APP_BUNDLE)

restart-dev:
	pkill -x $(APP_NAME_DEV) 2>/dev/null || true
	sleep 0.5
	open $(APP_BUNDLE_DEV)

repair-launch-services:
	@bash scripts/repair-launch-services.sh "$(APP_BUNDLE)" "$(APP_BUNDLE_DEV)"

clean:
	rm -rf $(APP_BUNDLE) $(APP_BUNDLE_DEV) .build $(APP_NAME).xcodeproj $(APP_NAME)-*.dmg
