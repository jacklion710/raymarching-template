// Fragment program for raymarching-template.jxs
#version 330 core

in jit_PerVertex {
	vec2 texcoord;
} jit_in;

layout (location = 0) out vec4 outColor;

// DoF toggle: comment out to disable depth of field entirely
// #define DOF_ENABLED

#ifdef DOF_ENABLED
	#define DOF_SAMPLES 4
#endif

void main(void) {
	// Output color
	vec3 col = vec3(0.0);
	float dist = 0.0;

	// Ray origin (camera position)
	vec3 ro = camPos;

	// Target point
	vec3 ta = vec3(0.0);
	float focalDistance = length(ro - ta);
	mat3 camMat = getCameraMatrix(ro, ta);
	
	// Ray direction
	float planeDist = 1.6; // Distance to the plane
	vec3 rd = normalize(camMat * vec3(jit_in.texcoord, planeDist));
	
	// UV coords for screen-space effects (0 to 1)
	vec2 uv = jit_in.texcoord * 0.5 + 0.5;
	vec3 bgCol = getBackground(rd, ro);

#ifdef DOF_ENABLED
	// DoF configuration
	DoFConfig dofConfig = getDefaultDoFConfig();
	dofConfig.aperture = 0.12;
	
	vec3 focalPoint = ro + rd * focalDistance;
	float distAccum = 0.0;

	for (int i = 0; i < DOF_SAMPLES; i++) {
		// Apply DoF offset
		vec3 offset = getDoFOffset(i, DOF_SAMPLES, camMat, dofConfig, iTime);
		vec3 newRo = ro + offset;
		vec3 newRd = normalize(focalPoint - newRo);
		
		// Raymarching
		vec4 scene = map(newRo, newRd);
		vec3 material = scene.rgb;
		float d = scene.w;
		distAccum += clamp(d, 0.0, farClip);

		// Color the scene based on the distance to the object
		if (d > farClip){
			col += bgCol;
		} else {
			vec3 hitPos = newRo + newRd * d;
			col += shadeHit(hitPos, newRd, material, bgCol);
		}
	}

	col /= float(DOF_SAMPLES);
	dist = distAccum / float(DOF_SAMPLES);

#else
	// No DoF - single ray
	vec4 scene = map(ro, rd);
	vec3 material = scene.rgb;
	dist = scene.w;

	if (dist > farClip){
		col = bgCol;
	} else {
		vec3 hitPos = ro + rd * dist;
		col = shadeHit(hitPos, rd, material, bgCol);
	}
#endif

	getPostProcessing(col, rd, ro, bgCol, dist, uv);
	
	// Output the color
	outColor = vec4(col, 1.0);
}
