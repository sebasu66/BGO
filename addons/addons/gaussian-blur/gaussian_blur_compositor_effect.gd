@tool
extends CompositorEffect
class_name GaussianBlurCompositorEffect

@export_range(0.001, 50.0) var sigma: float = 5.0

const SHADER_FILE: RDShaderFile = preload("gaussian_blur.glsl")
const CONTEXT: StringName = &"Gaussian Blur"
const PONG_TEXTURE: StringName = &"Pong"

var _rd := RenderingServer.get_rendering_device()

var _shader_rid: RID
var _pipeline_rid: RID
var _sampler_rid: RID

func _init() -> void:
	_shader_rid = _rd.shader_create_from_spirv(SHADER_FILE.get_spirv())
	_pipeline_rid = _rd.compute_pipeline_create(_shader_rid)
	
	var sampler_state := RDSamplerState.new()
	# Must use linear filter so that hardware filtering trick works
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_sampler_rid = _rd.sampler_create(sampler_state)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _shader_rid.is_valid():
			# Freeing shader also frees pipeline
			_rd.free_rid(_shader_rid)
		if _sampler_rid.is_valid():
			_rd.free_rid(_sampler_rid)

func _render_blur_pass(input_image_rid: RID, output_image_rid: RID, push: PackedFloat32Array, x_groups: int, y_groups: int) -> void:
	var input_uniform := RDUniform.new()
	input_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	input_uniform.binding = 0
	input_uniform.add_id(_sampler_rid)
	input_uniform.add_id(input_image_rid)
	
	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_uniform.binding = 1
	output_uniform.add_id(output_image_rid)
	
	var uniform_set := UniformSetCacheRD.get_cache(_shader_rid, 0, [input_uniform, output_uniform])
	
	var compute_list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline_rid)
	_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	_rd.compute_list_set_push_constant(compute_list, push.to_byte_array(), push.size() * 4)
	_rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	_rd.compute_list_end()

func _render_callback(current_callback_type: int, render_data: RenderData) -> void:
	if not _rd or current_callback_type != effect_callback_type or not _pipeline_rid.is_valid():
		return
	
	var render_scene_buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	if not render_scene_buffers:
		return
	
	var size := render_scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	
	# Ensure any existing buffers have the correct size
	if render_scene_buffers.has_texture(CONTEXT, PONG_TEXTURE):
		var format := render_scene_buffers.get_texture_format(CONTEXT, PONG_TEXTURE)
		if format.width != size.x or format.height != size.y:
			render_scene_buffers.clear_context(CONTEXT)

	if not render_scene_buffers.has_texture(CONTEXT, PONG_TEXTURE):
		var usage_bits: int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		render_scene_buffers.create_texture(CONTEXT, PONG_TEXTURE, RenderingDevice.DATA_FORMAT_R16G16B16A16_UNORM, usage_bits, RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false)
	
	var x_groups: int = size.x / 16 + 1
	var y_groups: int = size.y / 16 + 1
	
	var horizontal_push := PackedFloat32Array()
	horizontal_push.push_back(1.0) # Direction: (1.0, 0.0)
	horizontal_push.push_back(0.0)
	horizontal_push.push_back(sigma)
	horizontal_push.push_back(0.0) # Padding 
	
	var vertical_push := PackedFloat32Array()
	vertical_push.push_back(0.0) # Direction: (0.0, 1.0)
	vertical_push.push_back(1.0)
	vertical_push.push_back(sigma)
	vertical_push.push_back(0.0) # Padding
	
	_rd.draw_command_begin_label("Gaussian Blur", Color.WHITE)

	for view: int in range(render_scene_buffers.get_view_count()):
		var color_image_rid := render_scene_buffers.get_color_layer(view)
		var pong_image_rid := render_scene_buffers.get_texture_slice(CONTEXT, PONG_TEXTURE, view, 0, 1, 1)
		
		_render_blur_pass(color_image_rid, pong_image_rid, horizontal_push, x_groups, y_groups)
		_render_blur_pass(pong_image_rid, color_image_rid, vertical_push, x_groups, y_groups)
	
	_rd.draw_command_end_label()
