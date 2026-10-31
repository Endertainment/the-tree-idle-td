## AudioMath — pure audio helpers (unit-testable, no autoloads).
class_name AudioMath
extends RefCounted


## dB for a linear 0..1 volume; 0 maps to −80 dB (muted).
static func volume_to_db(linear: float) -> float:
	var value := clampf(linear, 0.0, 1.0)
	if value <= 0.001:
		return -80.0
	return linear_to_db(value)
