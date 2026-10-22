shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled;
uniform sampler2D art_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 art_tint : source_color = vec4(1.0);
void fragment() {
    vec4 ink = texture(art_map, UV);
    ALBEDO = ink.rgb * art_tint.rgb;
    ALPHA = ink.a * art_tint.a;
}
