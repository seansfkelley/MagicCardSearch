# Asset Catalog Setup Instructions

To add the mana symbol images to your Xcode project:

1. **In Xcode, navigate to your Assets.xcassets catalog**

2. **Create a new folder for mana symbols:**
   - Right-click in Assets.xcassets
   - Choose "New Folder"
   - Name it "Mana Symbols"

3. **Add each image:**
   - Drag and drop PNG files into the Mana Symbols folder
   - OR right-click and choose "New Image Set" for each symbol
   - Name each image set exactly as referenced in `ManaSymbolView.swift`:
     - mana_w, mana_u, mana_b, mana_r, mana_g, mana_c
     - mana_0 through mana_20
     - mana_x, mana_y, mana_z
     - mana_wu, mana_wb, mana_ub, etc.
     - And all other symbols listed in MANA_SYMBOLS_README.md

4. **Recommended image specifications:**
   - Format: PNG with transparency
   - Size: 64x64 or 128x128 pixels (@1x, @2x, @3x)
   - Color space: sRGB
   - Render as: Original Image (to preserve symbol colors)

5. **Optional: Create placeholder images**
   - Until you have real images, you can create simple colored circles
   - Use SF Symbols as temporary placeholders
   - The app will fall back to text if images are missing

## Quick Start: Temporary Placeholders

If you want to test the UI before adding real images:

1. Create simple 64x64 PNG files with colored circles
2. Use online tools like Photopea or Sketch to quickly generate them
3. Or use the SF Symbols app to export similar icons temporarily

## Finding Real Mana Symbols

Scryfall provides SVG versions of mana symbols at:
https://scryfall.com/docs/api/colors

You can also check:
- https://github.com/andrewgioia/mana (open source mana font)
- MTG JSON assets
- Wizard of the Coast's official resources (check licensing)
