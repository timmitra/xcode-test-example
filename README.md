## Running XCTest Unit and UI Tests and Generating Coverage Reports

This project includes a helper script, `run_tests_with_coverage.sh`, to automate running Xcode UI tests and generating coverage reports.

### Setup

1. **Create a config file (optional but recommended):**

   In your project root, create a file named `.xcode_test_config` with the following content:

   ```bash
   # .xcode_test_config
   DEVICE_UUID=your-iphone-uuid-here
   OUTPUT_DIR=./output
   # SIMULATOR_NAME=Your Simulator Name Here
   # SCHEME=YourSchemeName
   # DESTINATION='platform=iOS Simulator,name=Your Simulator,OS=17.0'
   ```

   - `DEVICE_UUID`: Your iPhone’s device UUID (use `instruments -s devices` or Xcode’s Devices window to find it).
   - `OUTPUT_DIR`: Directory where test results and coverage reports will be saved.
   - `SIMULATOR_NAME`: (Optional) Default simulator name for running tests on a simulator.
   - `SCHEME`: (Optional) Default scheme to test. If not set, you will be prompted to select one.
   - `DESTINATION`: (Optional) Full xcodebuild destination string. If not set, you will be prompted to choose device or simulator and can override interactively.

2. **Make the script executable:**

   ```bash
   chmod +x run_tests_with_coverage.sh
   ```

### Usage

From your project root, run:

```bash
./run_tests_with_coverage.sh
```

The script will prompt you for:

- **JIRA ticket number** (no spaces, required)
- **Optional comment** (no spaces, can be blank)
- **Device UUID** (defaults to value in `.xcode_test_config` or a hardcoded default)
- **Output directory** (defaults to value in `.xcode_test_config` or `./output`)
- **Scheme** (if not set in config, you will be prompted to select from available schemes)
- **Destination** (if not set in config, you will be prompted to choose device UUID or simulator name/OS, with the option to override the full destination string)

You can press Enter to accept the defaults for any prompt that shows one.

### What the Script Does

- Runs `xcodebuild test` for your project’s scheme on the specified device or simulator.
- Saves the test results and coverage report in the output directory, with filenames including your JIRA ticket and comment.
- Coverage report is saved as a `.json` file for easy review.

### Example Output

TestResults-1234-mycomment-20240726-153000.xcresult

TestResults-1234-mycomment-20240726-153000.json

### Notes

- The script will not track or commit your test results or config file if they are listed in `.gitignore`.
- You can customize the config file for different users or environments.
- **Troubleshooting:** If you see an error like:
  
  > Cannot test target “YourAppTests” on “Your Simulator”: Simulator’s iOS version doesn’t match YourAppTests’s deployment target.
  
  Make sure the simulator or device OS version matches or exceeds your test target’s deployment target. You may need to select a newer simulator or lower your project’s deployment target in Xcode.
- **Testing on Real Devices:** If you want to run tests on a real (hardware) device, you must set the correct Team in your Xcode project settings (Signing & Capabilities tab) for the target. Otherwise, code signing will fail and tests will not run on hardware.