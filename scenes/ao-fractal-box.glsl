// AO fractal box scene (inspired by reference shader)

#ifndef SCENE_AO_FRACTAL_BOX_GLSL
#define SCENE_AO_FRACTAL_BOX_GLSL

float aoFractalBoxSdf(vec3 p) {
	return rmFoldFractalSdf(p, 0, foldOffset, foldScaleFact, foldAngle, foldSminFact, 10);
}

// O(1): Scene-specific lighting (use only main light)
vec3 aoFractalBoxSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	return vec3(0.0);
}

// O(1): AO fractal box scene
vec4 aoFractalBoxScene(vec3 pos) {
	vec3 p = pos;
	p.y -= 0.1;

	float dist = aoFractalBoxSdf(p);

	float t = 0.3 + length(pos) * 0.2;
	PaletteSample pal = rmPaletteConcert(t);
	Material mat = createMaterial(pal.albedo, 0.0, 0.65, vec3(0.0), 0.0);

	gMaterial = mat;
	return vec4(mat.albedo, dist);
}

// O(1): Black background
vec3 aoFractalBoxBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	return vec3(0.0);
}

#endif
