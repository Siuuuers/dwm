# Retired Shop pagination

`source/ShopApp.gd.txt` preserves the exact paginated Shop implementation from
PR #167 commit `ed070f9a38af419396adc99a66499bc4a3025e73`, before the owner's
single-page amendment. It is a reference snapshot, not an imported script.

The current Shop shows all nine slots in a fixed 3×3 grid. Its balance strip
spans only the catalogue. Previous, Next and page-number controls are hidden,
inactive and excluded from focus; their preserved implementation can be found
in the snapshot. The panel measures its height to retain complete card text at
100%, 125% and 150%, using the desktop's existing scrolling on smaller windows.
