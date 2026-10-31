## TutorialService — three one-shot first-run hints (M8).
##
## The hint ids and their localized copy live here; `GameState.tutorial.shown`
## persists what the player has already seen so a restart never repeats a tip.
## Hints are deliberately non-blocking: they never pause the battle or open a
## modal, and every hint can be dismissed with its own button.
extends Node

const HINTS: Dictionary = {
	"first_build": {
		"key": "tutorial.build_hint",
		"fallback": "Tap a pedestal to build",
	},
	"first_upgrade": {
		"key": "tutorial.upgrade_hint",
		"fallback": "Spend cash to grow stronger",
	},
	"first_defeat": {
		"key": "tutorial.coins_hint",
		"fallback": "Coins are permanent — upgrade the Workshop",
	},
}

const FALLBACK_BUILD := "Tap a pedestal to build"
const FALLBACK_UPGRADE := "Spend cash to grow stronger"
const FALLBACK_DEFEAT := "Coins are permanent — upgrade the Workshop"


## True when `hint_id` was never shown on this profile.
func should_show(hint_id: StringName) -> bool:
	if not HINTS.has(String(hint_id)):
		return false
	var shown: Variant = GameState.tutorial.get("shown", {})
	if not (shown is Dictionary):
		return true
	return not bool((shown as Dictionary).get(String(hint_id), false))


## Marks a hint as shown and returns true when it had not been shown yet.
## `persist` is false only for pure headless tests that must not touch user://.
func take(hint_id: StringName, persist: bool = true) -> bool:
	if not should_show(hint_id):
		return false
	mark_shown(hint_id, persist)
	return true


## Records the hint without asking whether it was shown.
func mark_shown(hint_id: StringName, persist: bool = true) -> void:
	if not HINTS.has(String(hint_id)):
		return
	if not (GameState.tutorial.get("shown", {}) is Dictionary):
		GameState.tutorial["shown"] = {}
	(GameState.tutorial["shown"] as Dictionary)[String(hint_id)] = true
	if persist:
		SaveService.request_save()


## Localized copy for a hint id (falls back to the authored English line).
func text(hint_id: StringName) -> String:
	match String(hint_id):
		"first_build":
			return LocaleService.t("tutorial.build_hint", FALLBACK_BUILD)
		"first_upgrade":
			return LocaleService.t("tutorial.upgrade_hint", FALLBACK_UPGRADE)
		"first_defeat":
			return LocaleService.t("tutorial.coins_hint", FALLBACK_DEFEAT)
	return ""


## Dismiss button label.
func dismiss_text() -> String:
	return LocaleService.t("tutorial.dismiss", "Got it")


## Hint ids already shown (debug/tests).
func shown_ids() -> Array[String]:
	var result: Array[String] = []
	var shown: Variant = GameState.tutorial.get("shown", {})
	if shown is Dictionary:
		for key: Variant in (shown as Dictionary).keys():
			if bool((shown as Dictionary)[key]):
				result.append(str(key))
	result.sort()
	return result


## Wipes the one-shot flags (profile reset / tests).
func reset() -> void:
	GameState.tutorial = {"shown": {}}
