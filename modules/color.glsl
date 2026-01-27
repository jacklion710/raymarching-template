// O(1): Gamma correction.
// col: color to correct
vec3 gammaCorrection(vec3 col){
	// Output/display transform expects non-negative values.
	return pow(max(col, vec3(0.0)), vec3(1.0/2.2)); // From linear to sRGB space.
}

// O(1): Tone mapping.
// col: color to map
vec3 toneMapping(vec3 col){
	return col /= 1.0 + col;;
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