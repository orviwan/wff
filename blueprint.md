# Watch Face Blueprint: "Pathfinder"

This document outlines the vision, features, and design principles for the "Pathfinder" watch face. It should be used as the guiding specification for all development.

## 1. Project Vision & Target Audience

* **Vision**: To create a clean, elegant, and highly legible analog watch face designed for the everyday professional. It should feel classic but modern, prioritizing at-a-glance readability and battery efficiency.
* **Target Audience**: Professionals, office workers, and anyone who appreciates minimalist design. They value style but need practical information without clutter.

## 2. Core Features & Complications

The watch face will include the following features, laid out in a balanced and symmetrical way.

* **Primary Display**:
    * [ ] Analog Clock with Hour, Minute, and Second hands.
    * [ ] The second hand must be hidden in ambient mode.

* **Complications**: The watch face will support three customizable complication slots.
    * [ ] **Top Slot (ID 101)**: A `SHORT_TEXT` complication, ideal for the date. Default should be Day + Date (e.g., "TUE 28").
    * [ ] **Bottom Slot (ID 102)**: A `RANGED_VALUE` complication, ideal for step count or battery life.
    * [ ] **Background Slot (ID 103)**: A `PHOTO_IMAGE` complication, allowing the user to set a background image. This must be disabled by default.

* **User Customization**:
    * [ ] A color theme option allowing the user to change the accent color of the second hand and complication icons.

## 3. Design Language & Assets

* **Background**: Default is a solid, very dark grey (`#1C1C1C`), not pure black.
* **Hour Markers**: Simple, clean tick marks. Longer/thicker marks at 12, 3, 6, and 9.
* **Hour Hand**: A "dauphine" style hand. It should be relatively short and wide.
* **Minute Hand**: A "dauphine" style hand, but longer and slimmer than the hour hand.
* **Second Hand**: A simple, thin "stick" style hand, with the chosen accent color.

## 4. Future Ideas (Out of Scope for v1)

* Add different styles for the hour markers (e.g., Roman numerals).
* Create a "sports" flavor with a digital time display.
* Add weather complications.