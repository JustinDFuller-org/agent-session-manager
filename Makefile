APP_NAME = AgentSessionManager
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
SCHEME = AgentSessionManager
DERIVED_DATA = .build/DerivedData
RESULTS_PATH = .build/TestResults.xcresult

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
	xcodebuild test \
		-project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-resultBundlePath $(RESULTS_PATH) \
		-derivedDataPath $(DERIVED_DATA)

open-results:
	open $(RESULTS_PATH)

clean:
	rm -rf $(APP_BUNDLE) .build $(APP_NAME).xcodeproj
