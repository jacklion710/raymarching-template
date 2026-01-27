mat3 getRotationMatrix(vec3 v, float angle){
    float s = sin(angle);
    float c = cos(angle);
    float ic = 1.0 - c;
    return mat3(v.x*v.x*ic + c,     v.y*v.x*ic - s*v.z,     v.z*v.x*ic + s *v.y,
                v.x*v.y*ic + s*v.z, v.y*v.y*ic + c,         v.z*v.y*ic - s*v.x,
                v.x*v.z*ic - s*v.y, v.y*v.z*ic + s*v.x,     v.z*v.z*ic + c);
}