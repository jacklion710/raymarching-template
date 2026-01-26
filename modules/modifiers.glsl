// O(1): Smooth minimum function.
// a: first value
// b: second value
// k: smoothing factor
float smin(float a, float b, float k){
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
}

// O(1): Smooth maximum function.
// a: first value
// b: second value
// k: smoothing factor
float smax(float a, float b, float k){
    float h = max(k - abs(a - b), 0.0) / k;
    return max(a, b) + h * h * k * (1.0 / 4.0);
}