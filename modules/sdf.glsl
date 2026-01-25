// O(1): Axis-aligned box signed distance function.
// p: world-space position being sampled
// c: box center in world-space
// ra: box half-size (extent) per axis
float SDFbox(vec3 p, vec3 c, vec3 ra){
    vec3 d = abs(p - c) - ra;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// O(1): Sphere signed distance function.
// p: world-space position being sampled
// c: sphere center in world-space
// ra: sphere radius
float SDFsphere(vec3 p, vec3 c, float ra){
	return length(p - c) - ra;
}