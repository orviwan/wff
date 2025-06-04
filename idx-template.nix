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
  # We need gnused for cross-platform compatible `sed` command, and curl to download the wrapper.
  packages = [ pkgs.gnused pkgs.curl ];

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
    mkdir -p "$out/gradle/wrapper"
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

    # Generate the complete Gradle Wrapper, including the JAR file.
    echo "Generating gradle-wrapper.properties..."
    cat <<EOF > "$out/gradle/wrapper/gradle-wrapper.properties"
    distributionBase=GRADLE_USER_HOME
    distributionPath=wrapper/dists
    distributionUrl=https\://services.gradle.org/distributions/gradle-8.2-bin.zip
    zipStoreBase=GRADLE_USER_HOME
    zipStorePath=wrapper/dists
    EOF

    echo "Downloading gradle-wrapper.jar..."
    curl -L -o "$out/gradle/wrapper/gradle-wrapper.jar" "https://services.gradle.org/distributions/gradle-8.2-wrapper.jar"

    echo "Generating gradlew..."
    # **FIXED**: Use the full, standard gradlew script for robustness.
    # The 'EOF' is quoted to prevent any shell variable expansion inside the script.
    cat <<'EOF' > "$out/gradlew"
    #!/usr/bin/env sh

    #
    # Copyright 2015 the original author or authors.
    #
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    #
    #      https://www.apache.org/licenses/LICENSE-2.0
    #
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.
    #

    ##############################################################################
    ##
    ##  Gradle start up script for UN*X
    ##
    ##############################################################################

    # Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
    DEFAULT_JVM_OPTS=""

    APP_NAME="Gradle"
    APP_BASE_NAME=`basename "$0"`

    # Use the maximum available, or set MAX_FD != -1 to use that value.
    MAX_FD="maximum"

    warn () {
        echo "$*"
    }

    die () {
        echo
        echo "ERROR: $*"
        echo
        exit 1
    }

    # OS specific support (must be 'true' or 'false').
    cygwin=false
    msys=false
    darwin=false
    nonstop=false
    case "`uname`" in
        CYGWIN* )
            cygwin=true
            ;;
        Darwin* )
            darwin=true
            ;;
        MINGW* )
            msys=true
            ;;
        NONSTOP* )
            nonstop=true
            ;;
    esac

    # Attempt to set APP_HOME
    # Resolve links: $0 may be a link
    PRG="$0"
    # Need this for relative symlinks.
    while [ -h "$PRG" ] ; do
        ls=`ls -ld "$PRG"`
        link=`expr "$ls" : '.*-> \(.*\)$'`
        if expr "$link" : '/.*' > /dev/null; then
            PRG="$link"
        else
            PRG=`dirname "$PRG"`"/$link"
        fi
    done
    SAVED_PRG="$PRG"

    # Set APP_HOME
    APP_HOME=`dirname "$PRG"`

    # Add logic to check for problems with startup
    if [ -z "$JAVA_HOME" ] ; then
        # If a JDK is installed, it will be found below
        if [ -x /usr/libexec/java_home ] && [ $darwin = "true" ] ; then
            export JAVA_HOME=`/usr/libexec/java_home`
        fi
    fi
    if [ -z "$JAVA_HOME" ] ; then
        # If a JDK is installed, it will be found below
        if [ -d /usr/java/latest ] ; then
            export JAVA_HOME=/usr/java/latest
        fi
    fi

    # For Cygwin, ensure paths are in UNIX format before anything is touched
    if $cygwin ; then
        [ -n "$APP_HOME" ] &&
            APP_HOME=`cygpath --unix "$APP_HOME"`
        [ -n "$JAVA_HOME" ] &&
            JAVA_HOME=`cygpath --unix "$JAVA_HOME"`
        [ -n "$CLASSPATH" ] &&
            CLASSPATH=`cygpath --path --unix "$CLASSPATH"`
    fi

    # For MSYS, ensure paths are in UNIX format before anything is touched
    if $msys ; then
        [ -n "$APP_HOME" ] &&
            APP_HOME=`( cd "$APP_HOME" && pwd )`
        [ -n "$JAVA_HOME" ] &&
            JAVA_HOME=`( cd "$JAVA_HOME" && pwd )`
        # Add the gradle-wrapper.jar to the classpath
        if [ -n "$CLASSPATH" ] ; then
            CLASSPATH=`( cd "$CLASSPATH" && pwd )`
        fi
    fi

    # Set JAVA_EXE
    if [ -n "$JAVA_HOME" ] ; then
        if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
            # IBM's JDK on AIX uses jre/sh/java
            JAVA_EXE="$JAVA_HOME/jre/sh/java"
        else
            JAVA_EXE="$JAVA_HOME/bin/java"
        fi
    else
        JAVA_EXE="java"
    fi

    if ! "$JAVA_EXE" -version > /dev/null 2>&1 ; then
        die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH."
    fi

    # Set CLASSPATH
    if [ -n "$APP_HOME" ] ; then
        CLASSPATH="$APP_HOME/gradle/wrapper/gradle-wrapper.jar"
    fi

    # Split up the JVM options only if this is not running on a nonstop platform.
    if [ "$nonstop" = "false" ] ; then
        # Add the JAVA_OPTS to the list of JVM options.
        if [ -n "$JAVA_OPTS" ] ; then
            set -- $JAVA_OPTS
            for i in "$@"; do
                JVM_OPTS_ARRAY[${#JVM_OPTS_ARRAY[@]}]="$i"
            done
        fi
        # Add the GRADLE_OPTS to the list of JVM options.
        if [ -n "$GRADLE_OPTS" ] ; then
            set -- $GRADLE_OPTS
            for i in "$@"; do
                JVM_OPTS_ARRAY[${#JVM_OPTS_ARRAY[@]}]="$i"
            done
        fi
        # Add the DEFAULT_JVM_OPTS to the list of JVM options.
        if [ -n "$DEFAULT_JVM_OPTS" ] ; then
            set -- $DEFAULT_JVM_OPTS
            for i in "$@"; do
                JVM_OPTS_ARRAY[${#JVM_OPTS_ARRAY[@]}]="$i"
            done
        fi
    else
        # Nonstop platforms don't like splitting up arguments.
        JVM_OPTS="$JAVA_OPTS $GRADLE_OPTS $DEFAULT_JVM_OPTS"
    fi

    # Execute Gradle
    exec "$JAVA_EXE" "${JVM_OPTS_ARRAY[@]}" -classpath "$CLASSPATH" org.gradle.wrapper.GradleWrapperMain "$@"
    EOF

    # Make the gradlew script executable
    chmod +x "$out/gradlew"

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
    { pkgs, lib, ... }:
    let
      # Use an override to ensure the Android SDK license is accepted.
      androidEnv = pkgs.androidenv.override {
        inherit pkgs;
        licenseAccepted = true;
      };

      # Use the standard Nix mechanism for composing an Android SDK
      androidComposition = androidEnv.composeAndroidPackages {
        platformVersions = [ "__MIN_SDK_VERSION__" ];
        buildToolsVersions = [ "34.0.0" ];
        includeEmulator = true;
        includeSources = false;
      };
      sdk = androidComposition.androidsdk;
    in
    {
      channel = "stable-25.05";
      packages = [
        pkgs.jdk17
        pkgs.gradle_8
        sdk
        pkgs.nodePackages.firebase-tools
        pkgs.unzip
      ];
      env = {
        ANDROID_HOME = "''${sdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = lib.mkForce "''${sdk}/libexec/android-sdk";
        JAVA_HOME = "''${pkgs.jdk17.home}";
      };
      idx = {
        previews = {
          enable = true;
          previews = {
            "android" = {
              manager = "android";
            };
          };
        };
        workspace = {
          onCreate = {
            gradle-sync = "gradle --version";
          };
        };
        extensions = [ "VisualStudioExptTeam.vscodeintellicode" "naco-siren.gradle-language" "vscjava.vscode-java-pack" "vscjava.vscode-gradle" "vscjava.vscode-java-debug" "vscjava.vscode-java-dependency" "vscjava.vscode-java-test" "vscjava.vscode-maven" ];
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
