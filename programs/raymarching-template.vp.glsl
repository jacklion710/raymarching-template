// Vertex program for raymarching-template.jxs
#version 330 core

in vec3 position;
in vec2 texcoord;
in vec2 viewport;

out jit_PerVertex {
	vec2 texcoord;
} jit_out;

uniform mat4 modelViewProjectionMatrix;

void main(void) {
	gl_Position = modelViewProjectionMatrix*vec4(position, 1.);
	float aspectRatio = 1280.0 / 720.0; // viewport.x / viewport.y;
	jit_out.texcoord = texcoord - 0.5;
	jit_out.texcoord.x *= aspectRatio;
}
