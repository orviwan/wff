# This template follows a simpler structure, using a single bootstrap script
# to avoid Nix evaluation and recursion errors with the templating system.
{
  # These arguments are passed in from the idx-template.json parameters.
  pkgs,
  watchFaceName,
  watchFacePkg,
  wffVersion,
  watchType,
  ...
}: {
  # We need gnused for cross-platform compatible `sed` command.
  packages = [ pkgs.gnused ];

  # The 'bootstrap' attribute contains the shell script that scaffolds the entire project.
  # Firebase Studio will execute this script in the new workspace directory ($out).
  bootstrap = ''
    # Exit immediately if any command fails, and treat unset variables as an error.
    set -eu

    # --- START: Define and Export Variables ---
    # By exporting the variables, we ensure they are available in all sub-processes,
    # including the 'cat <<EOF' blocks used for file generation.

    echo "--- Preparing Template Variables ---"
    export WATCH_FACE_NAME="${watchFaceName}"
    export WATCH_FACE_PKG="${watchFacePkg}"
    export WFF_VERSION="${wffVersion}"
    export WATCH_TYPE="${watchType}"

    # Determine the minimum SDK version based on the selected WFF version.
    if [ "$WFF_VERSION" = "2" ]; then export MIN_SDK_VERSION="34";
    elif [ "$WFF_VERSION" = "3" ]; then export MIN_SDK_VERSION="35";
    elif [ "$WFF_VERSION" = "4" ]; then export MIN_SDK_VERSION="36";
    else export MIN_SDK_VERSION="33"; fi

    # Create a Gradle-friendly project name by removing spaces.
    export PROJECT_NAME=$(echo "$WATCH_FACE_NAME" | sed 's/ //g')

    echo "Watch Face Name: $WATCH_FACE_NAME"
    echo "Package Name: $WATCH_FACE_PKG"
    echo "WFF Version: $WFF_VERSION -> Min SDK: $MIN_SDK_VERSION"
    echo "Project Name: $PROJECT_NAME"
    # --- END: Define and Export Variables ---


    # --- START: Create Directory Structure ---
    echo "--- Creating Project Directory Structure ---"
    APP_DIR="$out/app"
    mkdir -p "$APP_DIR/src/main/res/raw"
    mkdir -p "$APP_DIR/src/main/res/xml"
    mkdir -p "$APP_DIR/src/main/res/drawable"
    mkdir -p "$APP_DIR/src/main/res/values"
    mkdir -p "$out/.idx"
    # --- END: Create Directory Structure ---


    # --- START: Copy Template Assets ---
    echo "--- Copying Template Assets ---"
    # Copy assets from the template repo into the new project, if they exist.
    if [ -d ./assets/drawable ] && [ "$(ls -A ./assets/drawable)" ]; then
      cp ./assets/drawable/*.png "$APP_DIR/src/main/res/drawable/"
      echo "Copied images from ./assets/drawable"
    fi
    # Create an empty preview placeholder for now.
    touch "$APP_DIR/src/main/res/drawable/preview.png"

    # Copy other essential files from the template repo if they exist.
    if [ -f ./.idx/airules.md ]; then cp ./.idx/airules.md "$out/.idx/"; fi
    if [ -f ./.gitignore ]; then cp ./.gitignore "$out/"; fi
    if [ -f ./README.md ]; then cp ./README.md "$out/"; fi
    if [ -f ./blueprint.md ]; then cp ./blueprint.md "$out/"; fi
    # --- END: Copy Template Assets ---


    # --- START: Generate Project Files ---
    echo "--- Generating Project Files ---"

    echo "Generating AndroidManifest.xml..."
    cat <<EOF > "$APP_DIR/src/main/AndroidManifest.xml"
    <manifest xmlns:android="http://schemas.android.com/apk/res/android"
        package="$WATCH_FACE_PKG">
        <uses-permission android:name="android.permission.WAKE_LOCK" />
        <uses-feature android:name="android.hardware.type.watch" />
        <application
            android:allowBackup="true"
            android:icon="@drawable/preview"
            android:label="$WATCH_FACE_NAME"
            android:hasCode="false">
            <meta-data
                android:name="com.google.android.wearable.standalone"
                android:value="true" />
            <property
                android:name="com.google.wear.watchface.format.version"
                android:value="$WFF_VERSION" />
            <service
                android:name="androidx.wear.watchface.format.WatchFaceFormatService"
                android:exported="true"
                android:label="$WATCH_FACE_NAME"
                android:permission="android.permission.BIND_WALLPAPER">
                <meta-data
                    android:name="android.service.wallpaper"
                    android:resource="@xml/watch_face_info" />
            </service>
        </application>
    </manifest>
    EOF

    echo "Generating watch_face_info.xml..."
    cat <<EOF > "$APP_DIR/src/main/res/xml/watch_face_info.xml"
    <WatchFaceInfo>
        <Preview value="@drawable/preview" />
        <Category value="CATEGORY_EMPTY" />
        <Editable value="true" />
    </WatchFaceInfo>
    EOF

    echo "Generating watchface.xml..."
    if [ "$WATCH_TYPE" = "Analog" ]; then
      cat <<EOF > "$APP_DIR/src/main/res/raw/watchface.xml"
      <WatchFace width="450" height="450">
        <Scene>
          <PartImage x="0" y="0" width="450" height="450" resource="@drawable/background" />
          <AnalogClock x="0" y="0" width="450" height="450">
            <HourHand resource="@drawable/hour_hand" x="205" y="30" width="40" height="195" pivotX="0.5" pivotY="0.9" />
            <MinuteHand resource="@drawable/minute_hand" x="215" y="20" width="20" height="215" pivotX="0.5" pivotY="0.9" />
          </AnalogClock>
        </Scene>
      </WatchFace>
    EOF
    else
      cat <<EOF > "$APP_DIR/src/main/res/raw/watchface.xml"
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
    EOF
    fi

    echo "Generating strings.xml..."
    cat <<EOF > "$APP_DIR/src/main/res/values/strings.xml"
    <resources>
        <string name="app_name">$WATCH_FACE_NAME</string>
    </resources>
    EOF

    echo "Generating app/build.gradle..."
    cat <<EOF > "$APP_DIR/build.gradle"
    plugins { id 'com.android.application' }
    android {
        namespace '$WATCH_FACE_PKG'
        compileSdk 34
        defaultConfig {
            applicationId "$WATCH_FACE_PKG"
            minSdk $MIN_SDK_VERSION
            targetSdk 34
            versionCode 1
            versionName "1.0"
        }
    }
    EOF

    echo "Generating root build.gradle..."
    cat <<EOF > "$out/build.gradle"
    plugins { id 'com.android.application' version '8.2.0' apply false }
    EOF

    echo "Generating settings.gradle..."
    cat <<EOF > "$out/settings.gradle"
    pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
    dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
    rootProject.name = "$PROJECT_NAME"
    include ':app'
    EOF
    # --- END: Generate Project Files ---


    # --- START: Generate Workspace Environment File ---
    echo "--- Generating Workspace Environment (.idx/dev.nix) ---"
    # Create a template dev.nix with a placeholder for the SDK version
    cat <<'DEV_NIX_EOF' > "$out/.idx/dev.nix.template"
    { pkgs, ... }:
    let
      # Use the standard Nix mechanism for composing an Android SDK
      androidComposition = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "__MIN_SDK_VERSION__" ]; # This is a placeholder
        buildToolsVersions = [ "34.0.0" ];
        # **FIXED**: Removed the 'licenseAccepted' argument as it was causing an error.
        # The platform likely handles license acceptance automatically.
        includeEmulator = true;
      };
      sdk = androidComposition.androidsdk;
    in
    {
      channel = "stable-24.05";
      packages = [
        pkgs.jdk17
        pkgs.gradle
        sdk
      ];
      env = {
        ANDROID_HOME = "''${sdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "''${sdk}/libexec/android-sdk";
        JAVA_HOME = "''${pkgs.jdk17.home}";
      };
      idx = {
        previews = {
          enable = false; # Previews are disabled for debugging
        };
        workspace = {
          onCreate = {
            gradle-sync = "./gradlew --version";
          };
        };
        extensions = [ "VisualStudioExptTeam.vscodeintellicode" "redhat.java" "naco-siren.gradle-language" ];
      };
    }
    DEV_NIX_EOF

    # Replace the placeholder with the actual SDK version
    sed "s/__MIN_SDK_VERSION__/$MIN_SDK_VERSION/g" "$out/.idx/dev.nix.template" > "$out/.idx/dev.nix"
    rm "$out/.idx/dev.nix.template" # Clean up the template file
    # --- END: Generate Workspace Environment File ---

    echo "--- WFF project scaffolding complete! ---"
  '';
}
