// O(1): Smooth minimum function.
// a: first value
// b: second value
// k: smoothing factor
float smin(float a, float b, float k){
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
}

// O(1): Smooth minimum for vec4(albedoRGB, distance).
// Blends both distance and albedo in the smoothing region.
// a: vec4(albedoRGB, distance)
// b: vec4(albedoRGB, distance)
// k: smoothing factor (larger = smoother)
vec4 getSmin (vec4 a, vec4 b, float k){
    float h = max(k - abs(a.w - b.w), 0.0) / k;
    float m = h * h * h * 0.5;
    float s = m * k * (1.0 / 3.0);
    return (a.w < b.w) ? vec4(mix(a.rgb, b.rgb, vec3(m)), a.w - s) : vec4(mix(b.rgb, a.rgb, vec3(m)), b.w - s);

}

// O(1): Get the minimum of two values.
// a: first value
// b: second value
// w: weight of the value
vec4 getMin(vec4 a, vec4 b){
    return (a.w < b.w) ? a : b;
}

// O(1): Get the maximum of two values.
// a: first value
// b: second value
// w: weight of the value
vec4 getMax(vec4 a, vec4 b){
    return (a.w > b.w) ? a : b;
}

// O(1): Smooth maximum function.
// a: first value
// b: second value
// k: smoothing factor
float smax(float a, float b, float k){
    float h = max(k - abs(a - b), 0.0) / k;
    return max(a, b) + h * h * k * (1.0 / 4.0);
}

// O(1): Smooth maximum for vec4(albedoRGB, distance).
// a: vec4(albedoRGB, distance)
// b: vec4(albedoRGB, distance)
// k: smoothing factor (larger = smoother)
vec4 getSmax(vec4 a, vec4 b, float k) {
    vec4 na = vec4(a.rgb, -a.w);
    vec4 nb = vec4(b.rgb, -b.w);
    vec4 r = getSmin(na, nb, k);
    return vec4(r.rgb, -r.w);
}