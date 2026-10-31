# Store assets (placeholders)

These are **placeholders generated from the game's own placeholder art**, not
final marketing art. They exist so the Play Console listing can be filled and
reviewed end-to-end before the art pass. Regenerate with:

```powershell
python tools/generate_store_assets.py
```

| File | Play Console slot | Required size | Source |
|---|---|---|---|
| `icon_512.png` | App icon | 512×512 PNG, 32-bit | `tools/generate_store_assets.py` (stylised tree) |
| `feature_graphic_1024x500.png` | Feature graphic | 1024×500 PNG/JPEG | menu capture + title plate |
| `screenshot_1_menu.png` | Phone screenshot 1 | 1080×1920 (9:16) | `docs/preview/m5b_menu_en.png` |
| `screenshot_2_battle.png` | Phone screenshot 2 | 1080×1920 | `docs/preview/m3_battle.png` |
| `screenshot_3_workshop.png` | Phone screenshot 3 | 1080×1920 | `docs/preview/m4_workshop.png` |

## Replace before production

- Icon: painted tree with gold rim, readable at 64 px, no text.
- Feature graphic: final key art; do not overlay UI text from a capture.
- Screenshots: capture on a real device with the release build and a populated
  profile (best wave > 0, cards and workshop visible). The current shots are
  from the M3–M5 debug builds.
- Add a 7-inch tablet set and a 10-inch set if the listing targets tablets
  (the game is portrait-only; `screen/support_*` are enabled).
- Short description (80 chars), full description (4 000 chars), privacy policy
  URL and data-safety answers live in `docs/RELEASE.md`, not here.
