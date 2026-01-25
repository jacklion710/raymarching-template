// Fragment program for raymarching-template.jxs
#version 330 core

in jit_PerVertex {
	vec2 texcoord;
} jit_in;

layout (location = 0) out vec4 outColor;

void main(void) {
	// Ray origin (camera position)
	vec3 ro = camPos;

	// Target point
	vec3 ta = vec3(0.0);
	mat3 camMat = getCameraMatrix(ro, ta);
	
	// Ray direction
	float planeDist = 0.6; // Distance to the plane
	vec3 rd = normalize(camMat * vec3(jit_in.texcoord, planeDist));
	
	// Raymarching
	float dist = map(ro, rd);

	// Output color
	vec3 col;
	vec3 bgCol = vec3(0.0);

	// Color the scene based on the distance to the object
	col = (dist > MAX_DIST) ? bgCol : getLight(ro + rd * dist, rd);

	// Output the color
	outColor = vec4(col, 1.0);
}