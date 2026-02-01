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
	vec3 basePos = spherePos;

	// Finite repetition with per-cell variation (fract-driven)
	vec3 cellSize = vec3(1.1, 1.1, 1.1);
	vec3 cellId = pMod3(spherePos, cellSize);
	vec3 cellSeed = fract(cellId * vec3(0.318, 0.617, 0.127));
	float cellLimit = max(max(abs(cellId.x), abs(cellId.y)), abs(cellId.z));

	// HG_SDF domain twist (more dramatic, per-cell angle)
	float twist = 3.4; // radians per unit height
	float twistPhase = iTime * 0.6 + cellSeed.x * 6.28318;
	pR(spherePos.xz, spherePos.y * twist + twistPhase);
	// Apply same twist to the base so it doesn't pop out when cells change
	pR(basePos.xz, basePos.y * twist + iTime * 0.6);
	// Per-cell rotation around y
	pR(spherePos.xz, cellSeed.y * 3.14159 + iTime * 0.25);
	pR(basePos.xz, iTime * 0.25);
	// Slight anisotropy so the twist reads visually
	spherePos.x *= 1.15;
	spherePos.z *= 0.85;
	basePos.x *= 1.15;
	basePos.z *= 0.85;

	// Recursive SDF layering (stable fold + scale, limited cells)
	float sdf = fSphere(basePos, 0.28);
	if (cellLimit <= 1.0) {
		vec3 fp = spherePos;
		float scale = 1.0;
		vec3 offset = vec3(0.22, 0.16, 0.12);
		for (int i = 0; i < 3; i++) {
			float it = float(i);
			fp = abs(fp);
			fp -= offset * scale;
			float spin = iTime * (0.3 + it * 0.12) + cellSeed.z * 6.28318;
			pR(fp.xy, spin + it * 0.6 + cellSeed.x);
			pR(fp.yz, spin * 0.8 - it * 0.35 + cellSeed.y);
			float layer = fSphere(fp, 0.22) / scale;
			sdf = smin(sdf, layer, 0.1);
			scale *= 1.35;
		}
	}
	// Safety factor to reduce marching overshoot on non-Lipschitz blends
	sdf *= 0.9;

	Material sphereMat = createMaterial(vec3(0.5), 0.0, 0.6, vec3(0.0), 0.0);
	sphereMat.toonSteps = 16.0;

	SceneResult scene = sceneResult(
		sdf,
		sphereMat
	);

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Black background
vec3 edgeGlowHaloBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	// Analytic halo around the sphere to simulate radiating glow
	float bounce = sin(iTime * 1.2) * 0.18;
	vec3 baseCenter = vec3(0.0, 0.0 + bounce, 0.0);
	float radius = 0.28;

	vec3 glowCol = vec3(1.0, 0.1, 0.1);
	vec3 total = vec3(0.0);

	// Repeat the halo and apply recursive transforms so it reacts to rotation/scale
	for (int i = 0; i < 3; i++) {
		float it = float(i);
		vec3 center = baseCenter;
		float spin = iTime * (0.3 + it * 0.14);
		pR(center.xz, spin + it * 0.9);
		// Match repetition + per-cell angle variation
		vec3 cellSize = vec3(1.1);
		vec3 halfCount = vec3(1.0);
		vec3 q = center;
		vec3 cellId = clamp(round(q / cellSize), -halfCount, halfCount);
		center = q - cellSize * cellId;
		vec3 cellSeed = fract(cellId * vec3(0.318, 0.617, 0.127));
		pR(center.xz, cellSeed.y * 3.14159 + iTime * 0.2);
		center *= 1.0 + it * 0.12;

		// Distance from ray to sphere center
		vec3 oc = center - ro;
		float t = max(dot(oc, rd), 0.0);
		vec3 closest = oc - rd * t;
		float d2 = dot(closest, closest);

		// Staggered boundary to create ray-like projections
		float angle = atan(closest.z, closest.x);
		float rayMask = 0.75 + 0.25 * sin(angle * 12.0 + iTime * 0.8);
		float rayMask2 = 0.7 + 0.3 * sin(angle * 24.0 - iTime * 1.3);
		float outer = radius * (1.08 + 0.06 * rayMask + 0.04 * rayMask2) * (1.0 + it * 0.08);
		float inner = radius * 1.0 * (1.0 + it * 0.04);
		float glow = smoothstep(outer * outer, inner * inner, d2);
		glow *= exp(-t * 0.15);

		// Artistic modulation: pulsing rings + subtle angular shimmer
		float dist = sqrt(max(d2, 0.000001));
		float rings = 0.6 + 0.4 * sin(dist * 18.0 - iTime * 3.2 + it + cellSeed.x * 3.0);
		float shimmer = 0.85 + 0.15 * sin(angle * 6.0 + iTime * 1.7);
		float pulse = 0.85 + 0.15 * sin(iTime * 2.0 + it);

		total += glowCol * glow * rings * shimmer * pulse * (0.55 / (1.0 + it));
	}

	return total;
}

#endif
