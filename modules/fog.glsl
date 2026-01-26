// O(1): Distance fog.
// col: color of the object
// bgCol: background color
// dist: distance to the object
vec3 distanceFog(vec3 col, vec3 bgCol, float dist){
    // Distance fog is useful for simple linear fog.
	return mix(col, bgCol, dist / MAX_DIST);
}

// O(1): Color fog.
// col: color of the object
// bgCol: background color
// dist: distance to the object
vec3 colorFog(vec3 col, vec3 bgCol, float dist){
	// Color fog is useful for more complex fog that is based on the color of the object.
    return mix(col, bgCol, dist / MAX_DIST);
}

// O(1): Fog blend.
// col: color of the object
// bgCol: background color
// dist: distance to the object
vec3 fogBlend(vec3 col, vec3 bgCol, float dist){
	// Fog blend is useful for more complex fog that is based on the distance to the object and the color of the object.
    return mix(col, bgCol, dist / MAX_DIST);
}
