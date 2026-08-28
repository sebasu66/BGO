#[compute]
#version 460

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D input_texture;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D output_image;

layout(push_constant, std430) uniform Parameters {
	vec2 direction;
	float sigma;
	float _pad0;
	
} parameters;

void main() {
    ivec2 local = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_image);
	
    if (local.x >= size.x || local.y >= size.y) return;
	
	vec2 texel = 1.0 / vec2(size);
	vec2 uv = (vec2(local) + 0.5) / vec2(size);
	
	// Incremental gaussian
	vec3 g = vec3(
		0.398942280401 / parameters.sigma,
		exp(-0.5 / (parameters.sigma * parameters.sigma)),
		0.0
	);
	g.z = g.y * g.y;
	
	// Initial sample at center of gaussian
	vec4 result = texture(input_texture, uv) * g.x;
    float sum = g.x;
	
	// N iterations stays within 3 standard deviations (99.7% accuracy)
	int N = int(ceil(0.5 * (abs(3.0 * parameters.sigma) - 0.5)));
	
	// Project texel size on direction
	vec2 delta = parameters.direction * dot(parameters.direction, texel);
	
	for (int i = 0; i < N; i ++) {
		g.xy *= g.yz;
		float w0 = g.x;
		
		g.xy *= g.yz;
		float w1 = g.x;
		
        float w = w0 + w1;
		
		vec2 o = (float(2 * i + 1) + w1 / w) * delta; // Hardware interpolation trick
		result += w * (texture(input_texture, uv - o) + texture(input_texture, uv + o)); // Kernel is symmetrical, sample both sides simultaneously
		sum += w + w;
	}
	
	result /= sum;
	
    imageStore(output_image, local, result);
}
