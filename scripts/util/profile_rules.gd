## ProfileRules — pure first-launch profile helpers (unit-testable).
class_name ProfileRules
extends RefCounted

const MIN_NICKNAME := 3
const MAX_NICKNAME := 16


## Returns an empty string when `value` is a valid nickname, else an error key.
static func validate_nickname(value: String) -> String:
	var text := value.strip_edges()
	if text.is_empty():
		return "onboarding.error.empty"
	if text.length() < MIN_NICKNAME:
		return "onboarding.error.short"
	if text.length() > MAX_NICKNAME:
		return "onboarding.error.long"
	var regex := RegEx.new()
	if regex.compile(r"^[\p{L}\p{N}_]+$") != OK or regex.search(text) == null:
		return "onboarding.error.chars"
	return ""


## Generates an RFC 4122 UUID v4 string.
static func make_uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]
