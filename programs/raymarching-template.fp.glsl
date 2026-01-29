// Fragment program for raymarching-template.jxs
#version 330 core

in jit_PerVertex {
	vec2 texcoord;
} jit_in;

layout (location = 0) out vec4 outColor;

void main(void) {
	const int DoF = 2;
	const float aperture = 0.3;

	// Output color
	vec3 col = vec3(0.0);
	vec3 bgCol = vec3(1.0);
	float distAccum = 0.0;

	// Ray origin (camera position)
	vec3 ro = camPos;

	// Target point
	vec3 ta = vec3(0.0);
	float focalDistance = length(ro - ta);
	mat3 camMat = getCameraMatrix(ro, ta);
	
	// Ray direction
	float planeDist = 1.6; // Distance to the plane
	vec3 rd = normalize(camMat * vec3(jit_in.texcoord, planeDist));
	vec3 focalPoint = ro + rd * focalDistance;

	for (int i = 0; i < DoF; i++) {

		vec3 rnd = hash(uvec3(jit_in.texcoord * iResolution, i)) - vec3(0.5);
		vec3 newRo = ro + rnd * aperture;
		vec3 newRd = normalize(focalPoint - newRo);
		// Raymarching
		vec4 scene = map(newRo, newRd);
		vec3 material = scene.rgb;
		float dist = scene.w;
		distAccum += clamp(dist, 0.0, farClip);

		// Color the scene based on the distance to the object
		if (dist > farClip){
			col += bgCol;
		} else {
			vec3 hitPos = newRo + newRd * dist;
			vec3 normals = getNorm(hitPos);
			float fresnel = pow(clamp(1. - dot(normals, -newRd), 0., 1.), 5.);

			col += getLight(hitPos, newRd, material, normals) * ((1.0 - fresnel) * 0.95 + 0.05);

			vec3 R = reflect(newRd, normals);
			vec3 reflRo = hitPos + normals * (MIN_DIST * 4.0);
			col += getFirstReflection(reflRo, R, bgCol) * fresnel;
		}
	}

	col /= float(DoF);
	
	float dist = distAccum / float(DoF);

	// Lens flare
	col += getLensFlare(rd, ro, lightPos, vec3(0.9, 0.2, 8.0), 10.0) * 0.5;

	// Distance fog
	col = distanceFog(col, bgCol, dist);

	// Post-processing
	col = toneMapping(col);// Tone mapping
	col = gammaCorrection(col);    // Apply gamma last (display transform)

	// Output the color
	outColor = vec4(col, 1.0);
}