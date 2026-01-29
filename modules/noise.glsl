vec3 hash(uvec3 x){
    x = ((x>>8U) ^ x.yzx) * 1103515245U;
    x = ((x>>8U) ^ x.yzx) * 1103515245U;
    x = ((x>>8U) ^ x.yzx) * 1103515245U;

    return vec3(x) * (1.0 / float(0xffffffffU));
}