// O(1): Gamma correction.
// col: color to correct
vec3 gammaCorrection(vec3 col){
	// Output/display transform expects non-negative values.
	return pow(max(col, vec3(0.0)), vec3(1.0/2.2)); // From linear to sRGB space.
}

// O(1): ACES Filmic tone mapping.
// Preserves contrast and saturation better than Reinhard.
// col: color to map
vec3 toneMapping(vec3 col){
	// ACES input matrix (sRGB -> ACES)
	mat3 inputMat = mat3(
		0.59719, 0.07600, 0.02840,
		0.35458, 0.90834, 0.13383,
		0.04823, 0.01566, 0.83777
	);
	// ACES output matrix (ACES -> sRGB)
	mat3 outputMat = mat3(
		1.60475, -0.10208, -0.00327,
		-0.53108, 1.10813, -0.07276,
		-0.07367, -0.00605, 1.07602
	);
	
	col = inputMat * col;
	
	// RRT and ODT fit (attempt to match ACES curve)
	vec3 a = col * (col + 0.0245786) - 0.000090537;
	vec3 b = col * (0.983729 * col + 0.4329510) + 0.238081;
	col = a / b;
	
	col = outputMat * col;
	
	return clamp(col, 0.0, 1.0);
}

// O(1): Exposure.
// col: color to expose
// exposure: exposure value
vec3 exposure(vec3 col, float exposure){
	// Simple photographic-style exposure curve that compresses highlights.
	// exposure is typically in ~[0.5, 4.0] depending on scene brightness.
	return vec3(1.0) - exp(-max(col, vec3(0.0)) * exposure);
}

// O(1): Contrast.
// col: color to contrast
// contrast: contrast value
vec3 contrast(vec3 col, float contrast){
	return (col - 0.5) * contrast + 0.5;
}

// O(1): Saturation.
// col: color to saturate
// saturation: saturation value
vec3 saturation(vec3 col, float saturation){
	return mix(vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), col, saturation);
}

// O(1): Hue shift.
// col: color to shift
// hueShift: hue rotation amount (in radians)
vec3 hueShift(vec3 col, float hueShift){
	// Convert to YIQ color space
    float Y = dot(col, vec3(0.299, 0.587, 0.114));
    float I = dot(col, vec3(0.596, -0.274, -0.322));
    float Q = dot(col, vec3(0.211, -0.523, 0.312));

    float angle = hueShift;
    float cosA = cos(angle);
    float sinA = sin(angle);

    float I2 = I * cosA - Q * sinA;
    float Q2 = I * sinA + Q * cosA;

    // Convert back to RGB
    vec3 rgb;
    rgb.r = Y + 0.956 * I2 + 0.621 * Q2;
    rgb.g = Y - 0.272 * I2 - 0.647 * Q2;
    rgb.b = Y - 1.105 * I2 + 1.702 * Q2;

    return rgb;
}

// O(1): Vignette effect.
// Darkens the edges of the screen to draw focus to center.
// col: color to apply vignette to
// uv: screen coordinates (normalized -0.5 to 0.5 from center)
// strength: vignette intensity (0.0 = none, 1.0 = strong)
// softness: falloff softness (higher = softer edge)
vec3 vignette(vec3 col, vec2 uv, float strength, float softness) {
	float dist = length(uv);
	float vig = 1.0 - smoothstep(1.0 - softness, 1.0, dist * (1.0 + strength));
	return col * vig;
}

// O(1): Film grain effect.
// Adds organic noise texture for cinematic feel.
// col: color to add grain to
// uv: screen coordinates
// time: animation time for varying grain
// amount: grain intensity (0.0 = none, 0.1 = subtle, 0.3 = heavy)
vec3 filmGrain(vec3 col, vec2 uv, float time, float amount) {
	// Hash-based noise for random grain pattern
	float noise = fract(sin(dot(uv + fract(time), vec2(12.9898, 78.233))) * 43758.5453);
	noise = (noise - 0.5) * amount;
	return col + vec3(noise);
}

// O(1): Chromatic aberration effect.
// Simulates RGB color fringing at screen edges (lens imperfection).
// Uses texture sampling offsets - call before other effects.
// uv: normalized screen coordinates (0 to 1)
// center: screen center (typically 0.5, 0.5)
// strength: aberration intensity (0.001 = subtle, 0.01 = strong)
// Note: Returns offset UVs for R, G, B channels respectively
vec3 chromaticAberrationOffsets(vec2 uv, vec2 center, float strength) {
	vec2 dir = uv - center;
	float dist = length(dir);
	vec2 offset = dir * dist * strength;
	// Returns: x = red offset multiplier, y = green (none), z = blue offset multiplier
	return vec3(-1.0, 0.0, 1.0) * length(offset);
}

// O(1): Dithering to reduce color banding.
// Adds subtle noise before quantization to smooth gradients.
// col: color to dither
// uv: screen coordinates
// bitDepth: target bit depth (8.0 for standard displays)
vec3 dither(vec3 col, vec2 uv, float bitDepth) {
	float levels = pow(2.0, bitDepth);
	// Triangular dither noise (better than uniform)
	float noise1 = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
	float noise2 = fract(sin(dot(uv + 0.5, vec2(12.9898, 78.233))) * 43758.5453);
	float triNoise = (noise1 + noise2 - 1.0) / levels;
	return col + vec3(triNoise);
}

// O(1): Sharpening filter (unsharp mask approximation).
// Enhances edge detail. Best applied after blur/fog effects.
// col: center pixel color
// neighbors: average of surrounding pixels (requires sampling)
// amount: sharpening strength (0.0 = none, 1.0 = strong)
vec3 sharpen(vec3 col, vec3 neighbors, float amount) {
	vec3 sharpened = col + (col - neighbors) * amount;
	return clamp(sharpened, 0.0, 1.0);
}

// O(1): Split toning effect.
// Applies different color tints to shadows vs highlights.
// col: color to tone
// shadowTint: color to add to dark areas
// highlightTint: color to add to bright areas
// balance: crossover point (0.5 = middle gray)
vec3 splitToning(vec3 col, vec3 shadowTint, vec3 highlightTint, float balance) {
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float shadowWeight = smoothstep(balance, 0.0, luma);
	float highlightWeight = smoothstep(balance, 1.0, luma);
	col = mix(col, col * shadowTint, shadowWeight * 0.5);
	col = mix(col, col + highlightTint * 0.2, highlightWeight);
	return col;
}

// O(1): Color temperature adjustment.
// Shifts white balance between warm (yellow/orange) and cool (blue).
// col: color to adjust
// temperature: -1.0 = cool/blue, 0.0 = neutral, 1.0 = warm/orange
vec3 colorTemperature(vec3 col, float temperature) {
	// Warm shift increases red/yellow, decreases blue
	// Cool shift increases blue, decreases red/yellow
	vec3 warm = vec3(1.0 + temperature * 0.1, 1.0, 1.0 - temperature * 0.15);
	vec3 cool = vec3(1.0 + temperature * 0.1, 1.0 + temperature * 0.02, 1.0 - temperature * 0.1);
	return col * (temperature > 0.0 ? warm : cool);
}

// O(1): Brightness adjustment.
// Simple additive brightness control.
// col: color to adjust
// brightness: amount to add (-1.0 to 1.0, 0.0 = no change)
vec3 brightness(vec3 col, float brightness) {
	return col + vec3(brightness);
}

// O(1): Lift/Gamma/Gain color correction.
// Professional color grading controls.
// col: color to correct
// lift: adjusts blacks/shadows (vec3 for RGB control)
// gamma: adjusts midtones
// gain: adjusts highlights/whites
vec3 liftGammaGain(vec3 col, vec3 lift, vec3 gamma, vec3 gain) {
	col = col * gain + lift;
	col = pow(max(col, vec3(0.0)), 1.0 / gamma);
	return col;
}