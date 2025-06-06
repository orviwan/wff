# **Wear OS Watch Face (WFF) Template**

A starter template for creating declarative Wear OS watch faces using the Watch Face Format (WFF) and a Nix-powered environment in Firebase Studio.

## **Quick Start**

1. **Define Your Vision**: Open BLUEPRINT.md and outline the features and design of your watch face.  
2. **Modify the Watch Face**: The main design file is located at app/src/main/res/raw/watchface.xml.  
3. **Add Image Assets**: Place your PNG assets (like clock hands or background images) in the app/src/main/res/drawable/ directory.  
4. **Preview Your Changes**:  
   * Open the terminal in Firebase Studio.  
   * Run `gradle :app:installDebug` to build and install the watch face on the emulator.  
   * On the emulator screen, long-press the current watch face to open the picker, then find and select your watch face to see it live.

## **Key Files**

* .idx/dev.nix: Defines the Nix environment, including the Android SDK and tools.  
* .idx/airules.md: Contains the system instructions for the integrated AI assistant.  
* BLUEPRINT.md: The high-level product plan for your watch face.  
* app/src/main/res/raw/watchface.xml: The core declarative layout of your watch face.