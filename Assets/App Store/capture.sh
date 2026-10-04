#!/bin/zsh
set -e

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h:h}
BUNDLE_ID=com.tsubuzaki.Fundsee
DEVICE_NAME="Fundsee Screenshots"
DERIVED_DATA=/tmp/fundsee-screenshots-dd
FAKETIME=/tmp/fundsee-faketime.dylib
LANGUAGES=(${@:-en ja})

epoch() { python3 -c "import datetime; print(int(datetime.datetime($1).timestamp()))" }
SEED_TIME=$(epoch "2026,10,23,12")
SHOT_TIME=$(epoch "2026,10,22,15,30")
JANUARY=$(( $(epoch "2026,1,1") - 978307200 ))

# MARK: - Simulator

UDID=$(xcrun simctl list devices available | grep "$DEVICE_NAME (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
if [[ -z $UDID ]]; then
  UDID=$(xcrun simctl create "$DEVICE_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0)
fi
xcrun simctl boot $UDID 2>/dev/null || true
xcrun simctl bootstatus $UDID -b >/dev/null
xcrun simctl ui $UDID appearance light
xcrun simctl status_bar $UDID override --time 9:41 \
  --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""

# MARK: - Build

xcrun --sdk iphonesimulator clang -dynamiclib -arch arm64 -mios-simulator-version-min=26.0 \
  -framework CoreFoundation "$SCRIPT_DIR/faketime.c" -o $FAKETIME
xcodebuild -project "$PROJECT_DIR/Fundsee.xcodeproj" -scheme Fundsee \
  -destination "id=$UDID" -derivedDataPath $DERIVED_DATA build -quiet
APP=$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Fundsee.app

export SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=$FAKETIME
GROUP_STORES=~/Library/Developer/CoreSimulator/Devices/$UDID/data/Containers/Shared/AppGroup

snap() {
  local attempt
  for attempt in 1 2 3 4 5; do
    sleep $1
    xcrun simctl io $UDID screenshot "$2" >/dev/null 2>&1
    python3 -c "
from PIL import Image
image = Image.open('$2').convert('L').crop((0, 300, 1206, 2400))
lo, hi = image.getextrema()
raise SystemExit(0 if hi - lo > 40 else 1)" && return 0
    echo "blank capture, retrying ${2:t}"
  done
  return 1
}

launch() {
  xcrun simctl terminate $UDID $BUNDLE_ID 2>/dev/null || true
  sleep 1
  SIMCTL_CHILD_FAKE_EPOCH=$1 xcrun simctl launch $UDID $BUNDLE_ID "${@:2}" >/dev/null
}

# MARK: - Capture

for language in $LANGUAGES; do
  raw_dir="$SCRIPT_DIR/Raw/$language"
  mkdir -p "$raw_dir"
  locale=$([[ $language == ja ]] && echo ja_JP || echo en_US)
  common=(-iCloudSyncEnabled NO -AppleLanguages "($language)" -AppleLocale $locale)

  xcrun simctl terminate $UDID $BUNDLE_ID 2>/dev/null || true
  xcrun simctl uninstall $UDID $BUNDLE_ID 2>/dev/null || true
  rm -f $GROUP_STORES/*/Library/"Application Support"/default.store*(N)
  xcrun simctl install $UDID $APP

  launch $SEED_TIME -hasCompletedOnboarding YES $common
  sleep 6
  launch $SEED_TIME -hasCompletedOnboarding YES $common -seedSampleData YES
  sleep 8
  xcrun simctl terminate $UDID $BUNDLE_ID
  sleep 2

  store=$(ls $GROUP_STORES/*/Library/"Application Support"/default.store)
  sqlite3 "$store" "delete from ZSPENDENTRY where ZTIMESTAMP > $SHOT_TIME - 978307200;"
  for weeks in 17 34 51; do
    sqlite3 "$store" "insert into ZSPENDENTRY (Z_PK, Z_ENT, Z_OPT, ZDAYKEY, ZTIMESTAMP, ZAMOUNT, ZCATEGORYNAME, ZSCOPERAW)
      select Z_PK + $weeks * 1000, Z_ENT, Z_OPT, ZDAYKEY - $weeks * 604800, ZTIMESTAMP - $weeks * 604800, ZAMOUNT, ZCATEGORYNAME, ZSCOPERAW
      from ZSPENDENTRY where Z_PK < 1000 and ZSCOPERAW = 'day' and ZDAYKEY - $weeks * 604800 >= $JANUARY;"
  done
  if [[ $language == ja ]]; then
    sqlite3 "$store" "update ZTEMPLATECATEGORY set ZAMOUNT = ZAMOUNT * 100; update ZSPENDENTRY set ZAMOUNT = ZAMOUNT * 100;"
  fi
  sqlite3 "$store" "update Z_PRIMARYKEY set Z_MAX = (select max(Z_PK) from ZSPENDENTRY) where Z_NAME = 'SpendEntry';"

  for tab in today week month year; do
    launch $SHOT_TIME -hasCompletedOnboarding YES $common -initialTab $tab
    snap 7 "$raw_dir/$tab.png"
    echo "captured $language/$tab"
  done

  for step in 1 2 3; do
    launch $SHOT_TIME -hasCompletedOnboarding NO $common -onboardingStep $step
    snap 5 "$raw_dir/onboarding-$step.png"
    echo "captured $language/onboarding-$step"
  done

  xcrun simctl terminate $UDID $BUNDLE_ID 2>/dev/null || true
done
