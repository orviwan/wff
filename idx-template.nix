# This is the function signature. It accepts an attribute set of arguments.
# **FIXED**: Corrected the function signature syntax to remove the invalid parentheses.
{ pkgs, watchFaceName, watchFacePkg, wffVersion, watchType, ... }:

let
  # This helper function generates the content for AndroidManifest.xml
  generateManifest = { watchFaceName, watchFacePkg, wffVersion, minSdkVersion }: ''
    <manifest xmlns:android="http://schemas.android.com/apk/res/android"
        package="${watchFacePkg}">
        <uses-permission android:name="android.permission.WAKE_LOCK" />
        <uses-feature android:name="android.hardware.type.watch" />
        <application
            android:allowBackup="true"
            android:icon="@drawable/preview"
            android:label="${watchFaceName}"
            android:hasCode="false">
            <meta-data
                android:name="com.google.android.wearable.standalone"
                android:value="true" />
            <property
                android:name="com.google.wear.watchface.format.version"
                android:value="${wffVersion}" />
            <service
                android:name="androidx.wear.watchface.format.WatchFaceFormatService"
                android:exported="true"
                android:label="${watchFaceName}"
                android:permission="android.permission.BIND_WALLPAPER">
                <meta-data
                    android:name="android.service.wallpaper"
                    android:resource="@xml/watch_face_info" />
            </service>
        </application>
    </manifest>
  '';

  # This helper function generates the starting watchface.xml content
  generateWatchFaceXml = { watchType }:
    if watchType == "Analog" then ''
      <WatchFace width="450" height="450">
        <Scene>
          <PartImage x="0" y="0" width="450" height="450" resource="@drawable/background" />
          <AnalogClock x="0" y="0" width="450" height="450">
            <HourHand resource="@drawable/hour_hand" x="205" y="30" width="40" height="195" pivotX="0.5" pivotY="0.9" />
            <MinuteHand resource="@drawable/minute_hand" x="215" y="20" width="20" height="215" pivotX="0.5" pivotY="0.9" />
          </AnalogClock>
        </Scene>
      </WatchFace>
    '' else ''
      <WatchFace width="450" height="450">
        <Scene>
          <PartImage x="0" y="0" width="450" height="450" resource="@drawable/background" />
          <DigitalClock x="0" y="195" width="450" height="60" alignment="CENTER">
            <TimeText format="HH:mm">
              <Font family="SANS_SERIF_THIN" size="60" weight="BOLD" color="#FFFFFFFF" />
            </TimeText>
          </DigitalClock>
        </Scene>
      </WatchFace>
    '';

  # This helper function generates the workspace's .idx/dev.nix file content
  generateDevNix = { minSdkVersion }: ''
    { pkgs, ... }: {
      channel = "unstable";

      packages = [
        pkgs.jdk17
        pkgs.gradle
        (pkgs.pkgsCross.android-nixpkgs.sdk (sdkPkgs: with sdkPkgs; [
          platform-tools
          build-tools-34-0-0
          platforms-android-${minSdkVersion}
          cmdline-tools-latest
          emulator
        ]))
      ];

      env = {
        ANDROID_SDK_ROOT = "''${pkgs.pkgsCross.android-nixpkgs.sdk (sdkPkgs: [])}/libexec/android-sdk";
        ANDROID_HOME = "''${pkgs.pkgsCross.android-nixpkgs.sdk (sdkPkgs: [])}/libexec/android-sdk";
        JAVA_HOME = "''${pkgs.jdk17.home}";
      };

      idx.previews = {
        enable = true;
        previews = [{
          id = "wear-os-emulator";
          manager = "android";
        }];
      };

      idx.workspace.onCreate = {
        gradle-sync = "./gradlew --version";
      };

      idx.extensions = [
        "VisualStudioExptTeam.vscodeintellicode",
        "redhat.java",
        "naco-siren.gradle-language"
      ];
    }
  '';

  # The logic for MIN_SDK_VERSION is now in the Nix `let` block,
  # so it's available during Nix evaluation time.
  MIN_SDK_VERSION =
    if wffVersion == "2" then "34"
    else if wffVersion == "3" then "35"
    else if wffVersion == "4" then "36"
    else "33"; # Default for v1

in
# This is the main shell script that Firebase Studio executes.
# It receives the parameters from idx-template.json and builds the project.
pkgs.writeShellScriptBin "scaffold-wff-project" ''
  # Exit immediately if any command fails
  set -e

  APP_DIR="$out/app"

  # Create the standard Android project directory structure
  mkdir -p "$APP_DIR/src/main/res/raw"
  mkdir -p "$APP_DIR/src/main/res/xml"
  mkdir -p "$APP_DIR/src/main/res/drawable"
  mkdir -p "$APP_DIR/src/main/res/values"
  mkdir -p "$out/.idx"

  # Copy assets from the template repo into the new project, if they exist
  echo "Copying drawable assets..."
  if [ -d ./assets/drawable ] && [ "$(ls -A ./assets/drawable)" ]; then
    cp ./assets/drawable/*.png "$APP_DIR/src/main/res/drawable/"
  fi
  # Create an empty preview placeholder for now
  touch "$APP_DIR/src/main/res/drawable/preview.png"

  # Generate AndroidManifest.xml using the helper function
  echo "Generating AndroidManifest.xml..."
  cat <<EOF > "$APP_DIR/src/main/AndroidManifest.xml"
  ${generateManifest {
    inherit watchFaceName watchFacePkg wffVersion;
    minSdkVersion = MIN_SDK_VERSION; # This now correctly uses the Nix variable
  }}
  EOF

  # Generate watch_face_info.xml
  echo "Generating watch_face_info.xml..."
  cat <<EOF > "$APP_DIR/src/main/res/xml/watch_face_info.xml"
  <WatchFaceInfo>
      <Preview value="@drawable/preview" />
      <Category value="CATEGORY_EMPTY" />
      <Editable value="true" />
  </WatchFaceInfo>
  EOF

  # Generate watchface.xml using the helper function
  echo "Generating watchface.xml..."
  cat <<EOF > "$APP_DIR/src/main/res/raw/watchface.xml"
  ${generateWatchFaceXml { inherit watchType; }}
  EOF

  # Generate strings.xml
  echo "Generating strings.xml..."
  cat <<EOF > "$APP_DIR/src/main/res/values/strings.xml"
  <resources>
      <string name="app_name">${watchFaceName}</string>
  </resources>
  EOF

  # Generate app/build.gradle
  echo "Generating app/build.gradle..."
  cat <<EOF > "$APP_DIR/build.gradle"
  plugins { id 'com.android.application' }
  android {
      namespace '${watchFacePkg}'
      compileSdk 34
      defaultConfig {
          applicationId "${watchFacePkg}"
          minSdk ${MIN_SDK_VERSION} # This now correctly uses the Nix variable
          targetSdk 34
          versionCode 1
          versionName "1.0"
      }
  }
  EOF

  # Generate root build.gradle
  echo "Generating root build.gradle..."
  cat <<EOF > "$out/build.gradle"
  plugins { id 'com.android.application' version '8.2.0' apply false }
  EOF

  # Generate settings.gradle, using the corrected Nix string replacement function
  echo "Generating settings.gradle..."
  cat <<EOF > "$out/settings.gradle"
  pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
  dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
  rootProject.name = "${(pkgs.lib.strings.replaceAll " " "" watchFaceName)}"
  include ':app'
  EOF

  # Copy workspace definition files from the template repo if they exist
  echo "Copying workspace definition files..."
  if [ -f ./.idx/airules.md ]; then cp ./.idx/airules.md "$out/.idx/"; fi
  if [ -f ./.gitignore ]; then cp ./.gitignore "$out/"; fi
  if [ -f ./README.md ]; then cp ./README.md "$out/"; fi
  if [ -f ./blueprint.md ]; then cp ./blueprint.md "$out/"; fi

  # Generate the workspace's .idx/dev.nix file using the helper function
  echo "Generating .idx/dev.nix..."
  cat <<EOF > "$out/.idx/dev.nix"
  ${generateDevNix { inherit MIN_SDK_VERSION; }} # This now correctly uses the Nix variable
  EOF

  echo "WFF project scaffolding complete!"
''
