shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 source_size;
uniform float rail_top;
uniform vec4 caret_rect;
uniform vec4 divider_rect;
uniform vec4 preview_rect;

bool inside_rect(vec2 pixel, vec4 rect) {
	return all(greaterThanEqual(pixel, rect.xy)) && all(lessThan(pixel, rect.xy + rect.zw));
}

void fragment() {
	vec2 pixel = UV * source_size;
	vec2 cell = floor(pixel / 4.0);
	float rank = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float retained = progress <= 0.0 ? 1.0 : (progress >= 1.0 ? 0.0 : step(progress, rank));
	if (pixel.y >= rail_top || inside_rect(pixel, caret_rect)
			|| inside_rect(pixel, divider_rect) || inside_rect(pixel, preview_rect)) {
		retained = 0.0;
	}
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= retained;
}
