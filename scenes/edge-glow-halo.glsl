// Edge-glow sphere scene (non-photoreal)

#ifndef SCENE_EDGE_GLOW_HALO_GLSL
#define SCENE_EDGE_GLOW_HALO_GLSL

// O(1): Scene-specific lighting (adds red rim glow)
vec3 edgeGlowHaloSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	float rim = pow(1.0 - max(dot(normals, -rd), 0.0), 2.2);
	col += vec3(1.0, 0.1, 0.1) * rim * 1.8;
	return col;
}

// O(1): Edge-glow sphere scene
vec4 edgeGlowHaloScene(vec3 pos) {
	float bounce = sin(iTime * 1.2) * 0.18;
	vec3 spherePos = pos - vec3(0.0, 0.0 + bounce, 0.0);

	Material sphereMat = createMaterial(vec3(0.5), 0.0, 0.6, vec3(0.0), 0.0);
	sphereMat.toonSteps = 16.0;

	SceneResult scene = sceneResult(
		fSphere(spherePos, 0.28),
		sphereMat
	);

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Black background
vec3 edgeGlowHaloBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	// Analytic halo around the sphere to simulate radiating glow
	float bounce = sin(iTime * 1.2) * 0.18;
	vec3 center = vec3(0.0, 0.0 + bounce, 0.0);
	float radius = 0.28;

	// Distance from ray to sphere center
	vec3 oc = center - ro;
	float t = max(dot(oc, rd), 0.0);
	vec3 closest = oc - rd * t;
	float d2 = dot(closest, closest);

	float inner = radius * 1.01;
	float outer = radius * 1.1;
	float glow = smoothstep(outer * outer, inner * inner, d2);
	glow *= exp(-t * 0.15);

	// Artistic modulation: pulsing rings + subtle angular shimmer
	float dist = sqrt(max(d2, 0.000001));
	float rings = 0.6 + 0.4 * sin(dist * 18.0 - iTime * 3.2);
	float angle = atan(closest.z, closest.x);
	float shimmer = 0.85 + 0.15 * sin(angle * 6.0 + iTime * 1.7);
	float pulse = 0.85 + 0.15 * sin(iTime * 2.0);

	vec3 glowCol = vec3(1.0, 0.1, 0.1);
	return glowCol * glow * rings * shimmer * pulse * 0.95;
}

#endif
