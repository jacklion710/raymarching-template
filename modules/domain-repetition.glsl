// O(1): Domain repetition with finite repetition count.
// p: world-space position being sampled
// cellSize: size of the repeating cell
// halfCount: half the number of repetitions in each direction
// origin: origin of the repeating pattern
// If only three arguments are provided, origin is assumed to be vec3(0).
vec3 opRepeatFinite(vec3 p, vec3 cellSize, vec3 halfCount, vec3 origin) {
    vec3 q = p - origin;
    vec3 cellIndex = clamp(round(q / cellSize), -halfCount, halfCount);
    return q - cellSize * cellIndex + origin;
}