"""Generates docs/art_manifest.json - the single machine-readable source of placeholder art.

Run:  python tools/gen_manifest.py
Output is deterministic: same input -> same JSON (sorted by path).
Colors follow docs/AI_BUILD_PROMPT.md section 9.2 (placeholder color per area).
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "art_manifest.json")

# Palette (spec section 5)
PANEL_DARK = "#0F3D1E"
PANEL = "#1E6B2E"
GREEN_LIGHT = "#7BD93A"
GREEN_MID = "#5FBF2A"
GREEN_DARK = "#3E9A1E"
GOLD = "#F2C230"
GOLD_DARK = "#C99A20"
BLUE = "#3FA9F5"
BLUE_DARK = "#2E86C8"
PARCHMENT = "#E8D5A8"
DANGER = "#E0433C"
DANGER_DARK = "#B2342E"
WOOD = "#6B4A2A"
TREE = "#2E7D32"
PEDESTAL = "#6B7A66"
TOWER = "#4A6FA5"
UNIT = "#3FA9F5"
ENEMY = "#8A4A3A"
BOSS = "#5B2A2A"
FX = "#FFD54F"
BG = "#2C4A2A"
MUTED = "#4A5A48"

entries = []


def add(path, w, h, color, mode="plain", margins=None):
    e = {"path": path, "w": w, "h": h, "color": color, "mode": mode}
    if mode == "9p":
        e["margins"] = margins or [24, 24, 24, 24]
    entries.append(e)


def frames(prefix, count, w, h, color):
    for i in range(count):
        add(f"{prefix}_{i:02d}.png", w, h, color)


# ---------------------------------------------------------------- ui/common
add("ui/common/panel_9p_green.png", 96, 96, PANEL, "9p")
add("ui/common/panel_9p_dark.png", 96, 96, PANEL_DARK, "9p")
add("ui/common/panel_9p_wood.png", 96, 96, WOOD, "9p", [28, 28, 28, 28])
add("ui/common/panel_9p_parchment.png", 96, 96, PARCHMENT, "9p")
add("ui/common/row_9p_green.png", 96, 64, PANEL, "9p", [20, 18, 20, 18])
add("ui/common/header_9p.png", 96, 96, PANEL_DARK, "9p")
add("ui/common/tooltip_9p.png", 96, 64, PANEL_DARK, "9p", [20, 16, 20, 16])
add("ui/common/toast_9p.png", 96, 64, PANEL_DARK, "9p", [20, 16, 20, 16])
add("ui/common/chip_9p.png", 64, 48, GREEN_DARK, "9p", [16, 12, 16, 12])
add("ui/common/divider.png", 400, 6, BG)
add("ui/common/badge_dot.png", 40, 40, DANGER)
add("ui/common/scrollbar_track.png", 16, 64, PANEL_DARK, "9p", [0, 8, 0, 8])
add("ui/common/scrollbar_grab.png", 16, 64, GREEN_LIGHT, "9p", [0, 8, 0, 8])
add("ui/common/slider_track.png", 400, 32, PANEL_DARK, "9p", [0, 12, 0, 12])
add("ui/common/slider_fill.png", 400, 32, GREEN_LIGHT, "9p", [0, 12, 0, 12])
add("ui/common/slider_knob.png", 64, 64, GOLD)
add("ui/common/progress_bg.png", 400, 48, PANEL_DARK, "9p", [0, 16, 0, 16])
add("ui/common/progress_fill_green.png", 400, 48, GREEN_LIGHT, "9p", [0, 16, 0, 16])
add("ui/common/progress_fill_yellow.png", 400, 48, GOLD, "9p", [0, 16, 0, 16])
add("ui/common/progress_fill_blue.png", 400, 48, BLUE, "9p", [0, 16, 0, 16])
add("ui/common/progress_fill_red.png", 400, 48, DANGER, "9p", [0, 16, 0, 16])
add("ui/common/toggle_on.png", 128, 64, GREEN_LIGHT, "9p", [28, 0, 28, 0])
add("ui/common/toggle_off.png", 128, 64, MUTED, "9p", [28, 0, 28, 0])
add("ui/common/checkbox_on.png", 64, 64, GREEN_LIGHT)
add("ui/common/checkbox_off.png", 64, 64, MUTED)

# ---------------------------------------------------------------- buttons
BTN = "ui/buttons"
for name, base, pressed, disabled in [
    ("green", GREEN_LIGHT, GREEN_MID, MUTED),
    ("blue", BLUE, BLUE_DARK, MUTED),
    ("gold", GOLD, GOLD_DARK, MUTED),
]:
    add(f"{BTN}/button_{name}_normal.png", 320, 120, base, "9p", [40, 36, 40, 36])
    add(f"{BTN}/button_{name}_pressed.png", 320, 120, pressed, "9p", [40, 36, 40, 36])
    add(f"{BTN}/button_{name}_disabled.png", 320, 120, disabled, "9p", [40, 36, 40, 36])

for name, base, pressed in [("red", DANGER, DANGER_DARK), ("ghost", PANEL, GREEN_DARK)]:
    add(f"{BTN}/button_{name}_normal.png", 320, 120, base, "9p", [40, 36, 40, 36])
    add(f"{BTN}/button_{name}_pressed.png", 320, 120, pressed, "9p", [40, 36, 40, 36])

for name, base, pressed, size, margins in [
    ("button_icon_round", PANEL, GREEN_DARK, 128, [40, 40, 40, 40]),
    ("button_close", PANEL_DARK, GREEN_DARK, 96, [28, 28, 28, 28]),
    ("button_back", PANEL_DARK, GREEN_DARK, 96, [28, 28, 28, 28]),
    ("button_plus", GREEN_DARK, GREEN_LIGHT, 96, [28, 28, 28, 28]),
]:
    add(f"{BTN}/{name}_normal.png", size, size, base, "9p", margins)
    add(f"{BTN}/{name}_pressed.png", size, size, pressed, "9p", margins)

add(f"{BTN}/tab_normal.png", 240, 96, PANEL, "9p", [32, 24, 32, 24])
add(f"{BTN}/tab_selected.png", 240, 96, GREEN_LIGHT, "9p", [32, 24, 32, 24])

# ---------------------------------------------------------------- icons
ICONS = """coin gem cash stone settings sound_on sound_off music_on music_off
vibration language info close check lock clock play pause speed star trophy calendar
gift shop cards hammer magic shield sword heart arrow_right""".split()
for icon in ICONS:
    add(f"ui/icons/icon_{icon}.png", 96, 96, GOLD)
add("ui/icons/icon_ad.png", 72, 72, GOLD)
add("ui/icons/icon_reward.png", 72, 72, GOLD)

# ---------------------------------------------------------------- nav
add("ui/nav/nav_bg_9p.png", 96, 96, PANEL_DARK, "9p")
for item in ["home", "workshop", "cards", "missions", "shop"]:
    add(f"ui/nav/nav_{item}_normal.png", 160, 160, GREEN_DARK)
    add(f"ui/nav/nav_{item}_pressed.png", 160, 160, GREEN_LIGHT)

# ---------------------------------------------------------------- main menu
MENU = "ui/menu"
add(f"{MENU}/bg/menu_bg.png", 1080, 1920, BG)
add(f"{MENU}/logo_title.png", 760, 460, GOLD)
add(f"{MENU}/logo_subtitle_9p.png", 640, 140, WOOD, "9p", [28, 28, 28, 28])
add(f"{MENU}/top_bar_9p.png", 96, 96, PANEL_DARK, "9p")
add(f"{MENU}/currency_pill_9p.png", 96, 64, PANEL_DARK, "9p", [20, 16, 20, 16])
add(f"{MENU}/profile_frame.png", 240, 240, GOLD, "9p", [60, 60, 60, 60])
for i in range(1, 7):
    add(f"{MENU}/avatar_0{i}.png", 200, 200, UNIT)
add(f"{MENU}/stat_row_9p.png", 96, 64, PANEL, "9p", [20, 16, 20, 16])
add(f"{MENU}/battle_button_normal.png", 820, 300, GREEN_LIGHT, "9p", [60, 60, 60, 60])
add(f"{MENU}/battle_button_pressed.png", 820, 300, GREEN_MID, "9p", [60, 60, 60, 60])
add(f"{MENU}/speed_trial_9p.png", 660, 150, BLUE, "9p", [40, 40, 40, 40])
add(f"{MENU}/xp_bar_bg.png", 400, 32, PANEL_DARK)
add(f"{MENU}/xp_bar_fill.png", 400, 32, GREEN_LIGHT)
add(f"{MENU}/daily_card_9p.png", 96, 96, PANEL, "9p")

# ---------------------------------------------------------------- battle: world
B = "battle"
add(f"{B}/arena/arena_bg.png", 1080, 1920, BG)
add(f"{B}/arena/ground_shadow.png", 256, 128, "#000000")
add(f"{B}/tree/tree_base.png", 600, 680, TREE)
add(f"{B}/tree/tree_glow.png", 400, 400, BLUE)
add(f"{B}/tree/tree_hurt_mask.png", 600, 680, "#FFFFFF")
add(f"{B}/tree/unit_slot_empty.png", 120, 120, PEDESTAL)
add(f"{B}/tree/unit_slot_locked.png", 120, 120, MUTED)
add(f"{B}/tree/unit_slot_selected.png", 140, 140, GREEN_LIGHT)
add(f"{B}/pedestal/pedestal_empty.png", 180, 180, PEDESTAL)
add(f"{B}/pedestal/pedestal_selected.png", 200, 200, GREEN_LIGHT)
add(f"{B}/pedestal/pedestal_locked.png", 180, 180, MUTED)
add(f"{B}/pedestal/pedestal_rune.png", 140, 140, BLUE)
for tower in ["archer", "cannon", "frost", "totem"]:
    for tier in (1, 2, 3):
        add(f"{B}/towers/tower_{tower}_l{tier}.png", 160, 160, TOWER)
for unit in ["archer", "mage", "druid"]:
    add(f"{B}/units/unit_{unit}_idle.png", 110, 110, UNIT)
frames(f"{B}/enemies/enemy_grunt_walk", 6, 128, 128, ENEMY)
frames(f"{B}/enemies/enemy_runner_walk", 6, 128, 128, ENEMY)
frames(f"{B}/enemies/enemy_tank_walk", 6, 160, 160, ENEMY)
frames(f"{B}/enemies/enemy_shaman_walk", 6, 128, 128, ENEMY)
frames(f"{B}/enemies/enemy_boss_troll_walk", 8, 280, 280, BOSS)
add(f"{B}/enemies/enemy_shadow.png", 160, 80, "#000000")
add(f"{B}/enemies/hp_bar_bg.png", 72, 14, PANEL_DARK)
add(f"{B}/enemies/hp_bar_fill.png", 68, 10, GREEN_LIGHT)
add(f"{B}/projectiles/proj_arrow.png", 48, 24, GOLD)
add(f"{B}/projectiles/proj_cannonball.png", 48, 48, "#333333")
add(f"{B}/projectiles/proj_frost.png", 40, 40, BLUE)
add(f"{B}/projectiles/proj_bolt.png", 40, 40, BLUE)
add(f"{B}/projectiles/proj_mage.png", 48, 48, "#B06BFF")
add(f"{B}/fx/fx_hit.png", 64, 64, FX)
add(f"{B}/fx/fx_death.png", 128, 128, FX)
add(f"{B}/fx/fx_explosion_sheet.png", 512, 512, FX)
add(f"{B}/fx/fx_levelup.png", 160, 160, FX)
add(f"{B}/fx/fx_leak.png", 160, 160, DANGER)

# ---------------------------------------------------------------- battle HUD
H = f"{B}/hud"
add(f"{H}/wave_banner_9p.png", 96, 64, PANEL_DARK, "9p", [20, 16, 20, 16])
add(f"{H}/boss_hp_frame_9p.png", 96, 48, PANEL_DARK, "9p", [20, 12, 20, 12])
add(f"{H}/boss_hp_fill.png", 900, 36, DANGER, "9p", [0, 12, 0, 12])
add(f"{H}/top_bar_battle_9p.png", 96, 96, PANEL_DARK, "9p", [24, 24, 24, 24])
add(f"{H}/tree_hp_frame_9p.png", 96, 96, PANEL_DARK, "9p", [28, 28, 28, 28])
add(f"{H}/tree_hp_fill.png", 480, 40, GREEN_LIGHT, "9p", [0, 14, 0, 14])
add(f"{H}/tree_hp_fill_low.png", 480, 40, DANGER, "9p", [0, 14, 0, 14])
add(f"{H}/cash_pill_9p.png", 96, 64, PANEL_DARK, "9p", [20, 16, 20, 16])
for state, color in [("normal", PANEL), ("active", GREEN_LIGHT), ("locked", MUTED)]:
    add(f"{H}/speed_button_{state}.png", 180, 96, color, "9p", [28, 20, 28, 20])
for state, color in [("normal", GREEN_LIGHT), ("pressed", GREEN_MID), ("attention", GOLD)]:
    add(f"{H}/upgrade_button_{state}.png", 460, 140, color, "9p", [40, 30, 40, 30])
add(f"{H}/tower_sheet_9p.png", 96, 96, PANEL_DARK, "9p", [28, 28, 28, 28])
add(f"{H}/tower_card_normal.png", 96, 96, PANEL, "9p", [20, 20, 20, 20])
add(f"{H}/tower_card_selected.png", 96, 96, GREEN_LIGHT, "9p", [20, 20, 20, 20])
add(f"{H}/unit_card_normal.png", 96, 96, PANEL, "9p", [20, 20, 20, 20])
add(f"{H}/unit_card_selected.png", 96, 96, GREEN_LIGHT, "9p", [20, 20, 20, 20])
add(f"{H}/pause_panel_9p.png", 96, 96, PANEL_DARK, "9p", [28, 28, 28, 28])
add(f"{H}/notification_dot.png", 40, 40, DANGER)

# ---------------------------------------------------------------- meta screens
M = "meta"
for tab in ["attack", "defense", "utility", "environment"]:
    add(f"{M}/workshop/tab_{tab}.png", 96, 96, GOLD)
add(f"{M}/workshop/upgrade_row_9p.png", 96, 64, PANEL, "9p", [20, 16, 20, 16])
for icon in ["damage", "hp", "crit", "speed", "economy", "offline"]:
    add(f"{M}/workshop/track_icon_{icon}.png", 80, 80, GOLD)
for state in ["idle", "active", "done", "locked"]:
    add(f"{M}/magica/node_frame_{state}.png", 200, 200, BLUE if state == "active" else PANEL_DARK)
add(f"{M}/magica/branch_bg_9p.png", 96, 96, PANEL_DARK, "9p")
add(f"{M}/magica/timer_pill_9p.png", 96, 48, PANEL_DARK, "9p", [16, 12, 16, 12])
for rarity, color in [("common", "#8FA88A"), ("rare", BLUE), ("epic", "#B06BFF"), ("legendary", GOLD)]:
    add(f"{M}/cards/card_frame_{rarity}.png", 300, 420, color, "9p", [28, 28, 28, 28])
add(f"{M}/cards/card_back.png", 300, 420, PANEL_DARK, "9p", [28, 28, 28, 28])
add(f"{M}/cards/card_slot_empty.png", 300, 420, MUTED, "9p", [28, 28, 28, 28])
add(f"{M}/cards/card_art_placeholder.png", 256, 256, BG)
add(f"{M}/shop/offer_card_9p.png", 96, 96, PANEL, "9p")
add(f"{M}/shop/ribbon_best_value.png", 220, 64, DANGER)
add(f"{M}/shop/icon_no_ads.png", 96, 96, GOLD)
add(f"{M}/shop/icon_starter_pack.png", 96, 96, GOLD)
add(f"{M}/missions/mission_row_9p.png", 96, 64, PANEL, "9p", [20, 16, 20, 16])
add(f"{M}/missions/mission_icon.png", 88, 88, GOLD)
add(f"{M}/leaderboard/row_9p.png", 96, 48, PANEL_DARK, "9p", [16, 12, 16, 12])
for medal, color in [("1", GOLD), ("2", "#C0C0C0"), ("3", "#CD7F32")]:
    add(f"{M}/leaderboard/medal_{medal}.png", 80, 80, color)
add(f"{M}/leaderboard/rank_badge.png", 64, 64, GREEN_DARK)
add(f"{M}/settings/settings_row_9p.png", 96, 48, PANEL_DARK, "9p", [16, 12, 16, 12])
add(f"{M}/onboarding/input_9p.png", 96, 48, PANEL_DARK, "9p", [16, 12, 16, 12])
add(f"{M}/onboarding/avatar_frame.png", 220, 220, GOLD, "9p", [24, 24, 24, 24])
add(f"{M}/common/modal_9p.png", 96, 96, PANEL_DARK, "9p", [28, 28, 28, 28])

# ---------------------------------------------------------------- output
seen = set()
for e in entries:
    if e["path"] in seen:
        raise SystemExit(f"duplicate manifest path: {e['path']}")
    seen.add(e["path"])

entries.sort(key=lambda e: e["path"])
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(entries, fh, indent=2)
    fh.write("\n")

print(f"wrote {len(entries)} entries to {os.path.relpath(OUT, ROOT)}")


