## TapGuard — accidental-tap protection for the "Next wave" skip button.
##
## Spec 4.8: the first three skips of a profile require a 250 ms press-and-hold or
## a confirm; afterwards a tap is enough because the player has learned the button.
## Pure so the gesture rules can be unit tested without input events.
class_name TapGuard
extends RefCounted

const FREE_USES := 3
const HOLD_SECONDS := 0.25


## True while `uses` successful skips still require the hold gesture.
static func requires_hold(uses: int) -> bool:
	return uses < FREE_USES


## True when a press was held long enough to accept.
static func is_hold_long_enough(held_seconds: float) -> bool:
	return held_seconds >= HOLD_SECONDS


## One-call decision for the HUD: may this release trigger the action?
static func allows(uses: int, held_seconds: float) -> bool:
	return not requires_hold(uses) or is_hold_long_enough(held_seconds)
