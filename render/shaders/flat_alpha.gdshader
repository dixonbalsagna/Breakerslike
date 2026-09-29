// Translucent flat greybox material (hidden fighters).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;

#define FLAT_ALPHA
#include "res://render/shaders/flat.gdshaderinc"
