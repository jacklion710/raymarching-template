// O(1): Smooth minimum function.
// a: first value
// b: second value
// k: smoothing factor
float smin(float a, float b, float k){
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
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