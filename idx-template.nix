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
  # We don't need any special packages to run the bootstrap script itself.
  packages = [];

  # The 'bootstrap' attribute contains the shell script that scaffolds the entire project.
  # Firebase Studio will execute this script in the new workspace directory ($out).
  bootstrap = ''
    # Exit immediately if any command fails
    set -e

    # --- START: Define Variables ---
    # Determine the minimum SDK version based on the selected WFF version.
    # **FIXED**: The variable is now exported to be available in subshells like cat <<EOF.
    export MIN_SDK_VERSION="33"
    if [ "${wffVersion}" = "2" ]; then export MIN_SDK_VERSION="34"; fi
    if [ "${wffVersion}" = "3" ]; then export MIN_SDK_VERSION="35"; fi
    if [ "${wffVersion}" = "4" ]; then export MIN_SDK_VERSION="36"; fi
    # Replace spaces in the watch face name for the Gradle project name.
    PROJECT_NAME=$(echo "${watchFaceName}" | sed 's/ //g')
    # --- END: Define Variables ---


    # --- START: Create Directory Structure ---
    echo "Creating project directory structure..."
    APP_DIR="$out/app"
    mkdir -p "$APP_DIR/src/main/res/raw"
    mkdir -p "$APP_DIR/src/main/res/xml"
    mkdir -p "$APP_DIR/src/main/res/drawable"
    mkdir -p "$APP_DIR/src/main/res/values"
    mkdir -p "$out/.idx"
    # --- END: Create Directory Structure ---


    # --- START: Copy Template Assets ---
    echo "Copying template assets..."
    # Copy assets from the template repo into the new project, if they exist.
    if [ -d ./assets/drawable ] && [ "$(ls -A ./assets/drawable)" ]; then
      cp ./assets/drawable/*.png "$APP_DIR/src/main/res/drawable/"
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
    echo "Generating AndroidManifest.xml..."
    cat <<EOF > "$APP_DIR/src/main/AndroidManifest.xml"
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
    if [ "${watchType}" = "Analog" ]; then
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
        <string name="app_name">${watchFaceName}</string>
    </resources>
    EOF

    echo "Generating app/build.gradle..."
    cat <<EOF > "$APP_DIR/build.gradle"
    plugins { id 'com.android.application' }
    android {
        namespace '${watchFacePkg}'
        compileSdk 34
        defaultConfig {
            applicationId "${watchFacePkg}"
            minSdk ${MIN_SDK_VERSION}
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
    rootProject.name = "${PROJECT_NAME}"
    include ':app'
    EOF

    # --- END: Generate Project Files ---


    # --- START: Generate Workspace Environment File ---
    # This creates the .idx/dev.nix file that sets up the Nix environment
    # for the new workspace.
    echo "Generating .idx/dev.nix..."
    # Note the DEV_NIX_EOF marker to prevent shell expansion of variables
    # inside this block that are intended for Nix.
    cat <<'DEV_NIX_EOF' > "$out/.idx/dev.nix"
    { pkgs, ... }: {
      channel = "unstable";
      packages = [
        pkgs.jdk17
        pkgs.gradle
        # Note: We use the MIN_SDK_VERSION variable passed from the shell script
        # into this Nix file's context. This is a special feature of this setup.
        # However, for simplicity here, we'll hardcode a default.
        # A more advanced template could pass MIN_SDK_VERSION into this file.
        (pkgs.pkgsCross.android-nixpkgs.sdk (sdkPkgs: with sdkPkgs; [
          platform-tools
          build-tools-34-0-0
          platforms-android-34 # Defaulting to API 34
          cmdline-tools-latest
          emulator
        ]))
      ];
      env = {
        ANDROID_SDK_ROOT = "${pkgs.pkgsCross.android-nixpkgs.sdk (sdkPkgs: [])}/libexec/android-sdk";
        ANDROID_HOME = "${pkgs.pkgsCross.android-nixpkgs.sdk (sdkPkgs: [])}/libexec/android-sdk";
        JAVA_HOME = "${pkgs.jdk17.home}";
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
    DEV_NIX_EOF
    # --- END: Generate Workspace Environment File ---

    echo "--- WFF project scaffolding complete! ---"
  '';
}
