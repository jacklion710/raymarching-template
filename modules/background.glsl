// Procedural sky/background utilities
// Background is evaluated in world space (ray direction), not screen space.

#ifndef RM_BACKGROUND_GLSL
#define RM_BACKGROUND_GLSL

// O(1): 2D hash (deterministic pseudo-random).
float rmHash12(vec2 p) {
	// Stable, cheap hash suitable for noise.
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// O(1): Value noise (2D).
float rmNoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = rmHash12(i + vec2(0.0, 0.0));
	float b = rmHash12(i + vec2(1.0, 0.0));
	float c = rmHash12(i + vec2(0.0, 1.0));
	float d = rmHash12(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// O(n): Fractal Brownian motion (2D).
float rmFbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(1.6, -1.2, 1.2, 1.6);
	for (int i = 0; i < 5; i++) {
		v += a * rmNoise2(p);
		p = m * p;
		a *= 0.5;
	}
	return v;
}

// O(1): Map view direction onto a stable sky UV.
// Returns UV in [0..1] with U wrapping around horizon.
vec2 rmSkyUV(vec3 rd) {
	vec3 d = normalize(rd);
	float u = atan(d.z, d.x) / 6.28318530718 + 0.5;
	float v = asin(clamp(d.y, -1.0, 1.0)) / 3.14159265359 + 0.5;
	return vec2(u, v);
}

// O(1): Base sky gradient + sun.
vec3 rmSkyBase(vec3 rd, vec3 ro) {
	float t = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);

	// Cool zenith, warm horizon.
	vec3 horizon = vec3(0.85, 0.88, 0.92);
	vec3 zenith = vec3(0.28, 0.45, 0.72);
	vec3 col = mix(horizon, zenith, smoothstep(0.0, 1.0, t));

	// Sun in direction of the main light (makes lighting feel coherent).
	vec3 sunDir = normalize(lightPos - ro);
	float sunDot = max(dot(normalize(rd), sunDir), 0.0);
	float sun = pow(sunDot, 900.0);
	float sunHalo = pow(sunDot, 60.0) * 0.15;
	col += vec3(1.0, 0.92, 0.78) * (sun * 3.0 + sunHalo);

	return col;
}

// O(1): Procedural cloud layer in sky space.
vec3 rmSkyClouds(vec3 rd, vec3 ro, vec3 baseCol) {
	vec2 suv = rmSkyUV(rd);

	// Fade clouds toward horizon and below it.
	float horizonFade = smoothstep(0.08, 0.55, suv.y);
	float aboveHorizon = smoothstep(0.02, 0.10, rd.y);
	float fade = horizonFade * aboveHorizon;

	// Animate clouds by scrolling in sky UV space.
	vec2 p = vec2(suv.x * 4.0, suv.y * 2.2) + vec2(iTime * 0.015, iTime * 0.01);
	float n = rmFbm2(p * 2.0);
	float n2 = rmFbm2(p * 5.0 + 10.0);
	float clouds = smoothstep(0.55, 0.78, n * 0.75 + n2 * 0.35);

	// Slight anisotropy: more contrast toward the sun.
	float sunBoost = pow(max(dot(normalize(rd), normalize(lightPos - ro)), 0.0), 2.0) * 0.25 + 0.75;

	vec3 cloudCol = vec3(1.0) * (0.75 + 0.25 * sunBoost);
	return mix(baseCol, mix(baseCol, cloudCol, 0.55) , clouds * fade);
}

// O(1): Default scene background: sky + clouds.
vec3 rmDefaultBackground(vec3 rd, vec3 ro) {
	vec3 base = rmSkyBase(rd, ro);
	return rmSkyClouds(rd, ro, base);
}

#endif

