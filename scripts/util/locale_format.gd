## LocaleFormat — pure locale formatting rules used by LocaleService.
##
## Kept free of autoload references so headless unit tests can preload it.
class_name LocaleFormat
extends RefCounted


## Formats an integer with locale-aware thousands separators: 12 480 / 12,480.
static func format_number(value: int, code: String) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = group_separator(code) + grouped
	return ("-" if value < 0 else "") + grouped


static func group_separator(code: String) -> String:
	return "\u00a0" if code == "uk" else ","


## Formats "2h 15m" (en) or "2г 15хв" (uk); seconds below a minute.
static func format_duration(seconds: int, code: String) -> String:
	var total := maxi(seconds, 0)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if hours > 0:
		return "%d%s %d%s" % [hours, duration_unit("h", code), minutes, duration_unit("m", code)]
	if minutes > 0:
		return "%d%s" % [minutes, duration_unit("m", code)]
	return "%d%s" % [secs, duration_unit("s", code)]


## Formats a countdown with days/hours/minutes (missions reset timer).
static func format_countdown(seconds: int, code: String) -> String:
	var total := maxi(seconds, 0)
	var days := total / 86400
	var hours := (total % 86400) / 3600
	var minutes := (total % 3600) / 60
	var d := "\u0434" if code == "uk" else "d"
	var h := "\u0433" if code == "uk" else "h"
	var m := "\u0445\u0432" if code == "uk" else "m"
	if days > 0:
		return "%d%s %02d%s %02d%s" % [days, d, hours, h, minutes, m]
	if hours > 0:
		return "%d%s %02d%s" % [hours, h, minutes, m]
	return "%d%s" % [minutes, m]


static func duration_unit(kind: String, code: String) -> String:
	if code == "uk":
		match kind:
			"h":
				return "\u0433"
			"m":
				return "\u0445\u0432"
			_:
				return "\u0441"
	match kind:
		"h":
			return "h"
		"m":
			return "m"
		_:
			return "s"


## Pure Ukrainian/English plural category selector.
static func plural_form(count: int, code: String) -> String:
	var value := absi(count)
	if code == "uk":
		var mod10 := value % 10
		var mod100 := value % 100
		if mod10 == 1 and mod100 != 11:
			return "one"
		if mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14):
			return "few"
		return "many"
	return "one" if value == 1 else "other"


## Debug pseudo-locale: doubles vowels and appends the overflow marker.
static func pseudo(text: String) -> String:
	if text.is_empty():
		return text
	var doubled := ""
	for index in text.length():
		var character := text[index]
		doubled += character
		if is_vowel(character):
			doubled += character
	if doubled.ends_with("\u2026"):
		return doubled
	return doubled + "\u2026"


static func is_vowel(character: String) -> bool:
	return "aeiouyAEIOUYаеєиіїоуюяАЕЄИІЇОУЮЯ".contains(character)
