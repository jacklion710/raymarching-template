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


// O(1): Composite object SDF (box carved by spheres).
// pos: world-space position being sampled
// c: object center in world-space
// ra: object scale (per-axis extent)
float obj1(vec3 pos, vec3 c, vec3 ra){
    float closest;
	float cube = SDFbox(pos, c, vec3(0.14)*ra) - 0.01;
	float sphere = SDFsphere(pos, c, 0.18*ra.x);
	float sphere2 = SDFsphere(pos, c, 0.2*ra.x);
	closest = max(cube, -sphere);
	return max(closest, sphere2);
}