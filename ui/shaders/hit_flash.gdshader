shader_type canvas_item;

// Hit flash (spec 4.7): the enemy sprite is tinted toward flash_color for 0.08 s.
// One uniform only, so it is cheap on mobile GPUs (ADR-001).
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.92, 0.82, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	base.rgb = mix(base.rgb, flash_color.rgb, flash_amount);
	COLOR = base * COLOR;
}
