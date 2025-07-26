#!/bin/bash

# NOTE: JIRA ticket should have no spaces
# You can set a default device UUID and output directory in .xcode_test_config like:
# DEVICE_UUID=00000000-000ABCDE12345678
# OUTPUT_DIR=./output

# Load config file if it exists
CONFIG_FILE=".xcode_test_config"
DEFAULT_UUID="00008120-0009752636B9A01E" # your device UUID
DEFAULT_OUTPUT_DIR="./output"
DEFAULT_SIMULATOR_NAME="iPhone 16 Pro"
DEFAULT_SCHEME=""
DEFAULT_DESTINATION=""
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
  if [ -n "$DEVICE_UUID" ]; then
    DEFAULT_UUID="$DEVICE_UUID"
  fi
  if [ -n "$OUTPUT_DIR" ]; then
    DEFAULT_OUTPUT_DIR="$OUTPUT_DIR"
  fi
  if [ -n "$SCHEME" ]; then
    DEFAULT_SCHEME="$SCHEME"
  fi
  if [ -n "$DESTINATION" ]; then
    DEFAULT_DESTINATION="$DESTINATION"
  fi
  if [ -n "$SIMULATOR_NAME" ]; then
    DEFAULT_SIMULATOR_NAME="$SIMULATOR_NAME"
  fi
fi

# Prompt for JIRA ticket number (no spaces)
while true; do
  read -p "Enter JIRA ticket number (no spaces): " JIRA_TICKET
  if [[ "$JIRA_TICKET" =~ \  ]]; then
    echo "JIRA ticket must not contain spaces. Please try again."
  elif [[ -z "$JIRA_TICKET" ]]; then
    echo "JIRA ticket cannot be empty. Please try again."
  else
    break
  fi
done
# Prompt for optional comment (no spaces)
while true; do
  read -p "Enter optional comment (no spaces, leave blank for none): " COMMENT
  if [[ "$COMMENT" =~ \  ]]; then
    echo "Comment must not contain spaces. Please try again."
  else
    break
  fi
done
# Prompt for device UUID, with config/default
read -p "Enter device UUID (default: $DEFAULT_UUID): " USER_UUID
DEVICE_UUID=${USER_UUID:-$DEFAULT_UUID}
# Prompt for output directory, with config/default
read -p "Enter output directory (default: $DEFAULT_OUTPUT_DIR): " USER_OUTPUT_DIR
OUTPUT_DIR=${USER_OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Find the first .xcodeproj in the current directory
XCODEPROJ=$(find . -maxdepth 1 -name "*.xcodeproj" | head -n 1)
if [ -z "$XCODEPROJ" ]; then
  echo "No .xcodeproj file found in the current directory."
  exit 1
fi

# --- Scheme selection logic ---
SCHEME=""
if [ -n "$DEFAULT_SCHEME" ]; then
  SCHEME="$DEFAULT_SCHEME"
else
  # Try to get schemes from xcodebuild -list -json
  if command -v jq >/dev/null 2>&1; then
    SCHEMES=$(xcodebuild -list -json -project "$XCODEPROJ" 2>/dev/null | jq -r '.project.schemes[]' 2>/dev/null)
    if [ -n "$SCHEMES" ]; then
      echo "Available schemes:"
      i=1
      declare -A SCHEME_MAP
      while read -r scheme; do
        echo "  $i) $scheme"
        SCHEME_MAP[$i]="$scheme"
        i=$((i+1))
      done <<< "$SCHEMES"
      read -p "Select scheme [1]: " SCHEME_IDX
      SCHEME_IDX=${SCHEME_IDX:-1}
      SCHEME="${SCHEME_MAP[$SCHEME_IDX]}"
    fi
  fi
  # Fallback if jq or xcodebuild fails
  if [ -z "$SCHEME" ]; then
    SCHEME=$(basename "$XCODEPROJ" .xcodeproj)
    read -p "Enter scheme name (default: $SCHEME): " USER_SCHEME
    SCHEME=${USER_SCHEME:-$SCHEME}
  fi
fi

# --- Destination selection logic ---
DESTINATION=""
if [ -n "$DEFAULT_DESTINATION" ]; then
  DESTINATION="$DEFAULT_DESTINATION"
  read -p "Enter destination string (default: $DESTINATION): " USER_DEST
  DESTINATION=${USER_DEST:-$DESTINATION}
else
  echo "Choose destination type:"
  echo "  1) Device UUID"
  echo "  2) Simulator name (with optional OS)"
  read -p "Select option [1]: " DEST_TYPE
  DEST_TYPE=${DEST_TYPE:-1}
  if [ "$DEST_TYPE" = "1" ]; then
    read -p "Enter device UUID (default: $DEFAULT_UUID): " USER_UUID
    DEVICE_UUID=${USER_UUID:-$DEFAULT_UUID}
    DESTINATION="platform=iOS,id=$DEVICE_UUID"
  else
    while true; do
      if [ -n "$DEFAULT_SIMULATOR_NAME" ]; then
        read -p "Enter simulator name (default: $DEFAULT_SIMULATOR_NAME): " SIM_NAME
        SIM_NAME=${SIM_NAME:-$DEFAULT_SIMULATOR_NAME}
      else
        read -p "Enter simulator name (required): " SIM_NAME
      fi
      if [ -n "$SIM_NAME" ]; then
        break
      else
        echo "Simulator name cannot be empty. Please try again."
      fi
    done
    read -p "Enter OS version (optional, e.g., 17.0): " SIM_OS
    if [ -n "$SIM_OS" ]; then
      DESTINATION="platform=iOS Simulator,name=$SIM_NAME,OS=$SIM_OS"
    else
      DESTINATION="platform=iOS Simulator,name=$SIM_NAME"
    fi
  fi
  read -p "Override destination string (leave blank to use above: $DESTINATION): " USER_DEST
  if [ -n "$USER_DEST" ]; then
    DESTINATION="$USER_DEST"
  fi
fi

# Build result bundle name
DATE=$(date +%Y%m%d-%H%M%S)
BUNDLE_NAME="TestResults-${JIRA_TICKET}"
if [ -n "$COMMENT" ]; then
  BUNDLE_NAME="${BUNDLE_NAME}-${COMMENT}"
fi
BUNDLE_NAME="${BUNDLE_NAME}-${DATE}"
BUNDLE_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.xcresult"
JSON_PATH="$OUTPUT_DIR/${BUNDLE_NAME}.json"

# Run tests
echo "Running tests for scheme '$SCHEME' on destination $DESTINATION..."
xcodebuild test -scheme "$SCHEME" -destination "$DESTINATION" -resultBundlePath "$BUNDLE_PATH"
if [ $? -ne 0 ]; then
  echo "xcodebuild test failed."
  exit 1
fi

# Generate coverage report
echo "Generating coverage report..."
xcrun xccov view --report "$BUNDLE_PATH" > "$JSON_PATH"
if [ $? -eq 0 ]; then
  echo "Coverage report saved to $JSON_PATH"
else
  echo "Failed to generate coverage report."
fi 