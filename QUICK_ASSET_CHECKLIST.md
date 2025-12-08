# Quick Asset Checklist

Add these image files to your Xcode Assets.xcassets:

## Priority 1: Most Common Mana Symbols (Start Here)
```
mana_w.png    mana_u.png    mana_b.png    mana_r.png    mana_g.png
mana_0.png    mana_1.png    mana_2.png    mana_3.png    mana_4.png
mana_5.png    mana_6.png    mana_7.png    mana_8.png    mana_9.png
mana_10.png   mana_x.png    mana_c.png
```

## Priority 2: Hybrid Mana (Common in some sets)
```
mana_wu.png   mana_wb.png   mana_ub.png   mana_ur.png   mana_br.png
mana_bg.png   mana_rw.png   mana_rg.png   mana_gw.png   mana_gu.png
```

## Priority 3: Special & Rare Symbols
```
mana_11.png through mana_16.png, mana_20.png
mana_wp.png   mana_up.png   mana_bp.png   mana_rp.png   mana_gp.png
mana_2w.png   mana_2u.png   mana_2b.png   mana_2r.png   mana_2g.png
mana_tap.png  mana_untap.png  mana_e.png  mana_s.png
```

## Where to Get Images
1. **Mana font by Andrew Gioia**: https://github.com/andrewgioia/mana
   - Free, open-source SVG icons
   - Can export to PNG at any size
   
2. **Scryfall CDN**: https://svgs.scryfall.io/card-symbols/
   - Official-looking symbols
   - Available as SVG (convert to PNG)

3. **Create Simple Placeholders**:
   - Colored circles with letters
   - Numbers on gray circles
   - Just to get started quickly

## Recommended Workflow
1. Start with Priority 1 symbols (covers 90% of cards)
2. Test your app - see which symbols are missing
3. Add Priority 2 & 3 as needed
4. The app will show text fallback for missing symbols
