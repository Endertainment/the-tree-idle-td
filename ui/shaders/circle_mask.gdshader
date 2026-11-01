// Circular avatar mask.
//
// The avatar art is a square, the frame art is a ring: drawing the square on top
// of the ring looks wrong. This shader keeps the texture inside a circle and
// feathers the last pixel so the ring never shows a hard seam.
shader_type canvas_item;

uniform float radius : hint_range(0.1, 0.75) = 0.5;
uniform float feather : hint_range(0.0, 0.1) = 0.015;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 offset = UV - center;
	float distance_to_center = length(offset);
	float mask = 1.0 - smoothstep(radius - feather, radius, distance_to_center);
	COLOR.a *= mask;
}
