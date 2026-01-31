// Caustics demonstration scene
// Showcases colored shadows from transparent and SSS materials

#ifndef SCENE_CAUSTICS_GLSL
#define SCENE_CAUSTICS_GLSL

// O(1): Scene-specific lighting optimized for caustic shadow visibility
// Dynamic orbiting lights create sweeping caustic patterns across the floor
// hitPos: surface hit position
// normals: surface normal
// rd: view ray direction
// mate: surface albedo
// Returns: additional light contribution from scene lights
vec3 causticSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);
	
	// Animation parameters
	float orbitSpeed = 0.3;
	float pulseSpeed = 0.8;
	float time = iTime;
	
	// === ORBITING LIGHT CAROUSEL ===
	// 5 colored lights orbit in a tilted ring behind the glass objects
	// Creates constantly shifting caustic shadow patterns
	float numOrbitLights = 5.0;
	float orbitRadius = 1.4;
	float orbitHeight = 0.9;
	float orbitCenterZ = 1.2;  // Behind the glass spheres
	
	for (float i = 0.0; i < numOrbitLights; i += 1.0) {
		// Each light offset by equal angle, orbiting over time
		float baseAngle = (i / numOrbitLights) * 6.28318;
		float orbitAngle = baseAngle + time * orbitSpeed;
		
		// Tilted orbit path - lights bob up and down as they rotate
		float heightOffset = sin(orbitAngle * 2.0) * 0.25;
		
		vec3 orbitPos = vec3(
			cos(orbitAngle) * orbitRadius,
			orbitHeight + heightOffset,
			orbitCenterZ + sin(orbitAngle) * 0.4
		);
		
		// Spectrum colors - each light a different hue (shifted over time for variety)
		float hue = (i / numOrbitLights) + time * 0.05;
		vec3 orbitCol = 0.6 + 0.4 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
		
		// Intensity pulses slightly for each light at different phases
		float pulse = 0.85 + 0.15 * sin(time * pulseSpeed + i * 1.2);
		orbitCol *= pulse * 0.9;
		
		col += getPointLight(hitPos, orbitPos, normals, rd, refRd, orbitCol, mate);
	}
	
	// === PENDULUM SPOTLIGHT ===
	// Swings back and forth, casting dramatic sweeping caustic beams
#if RM_ENABLE_SPOTLIGHT
	{
		float swingAngle = sin(time * 0.5) * 0.8;  // -0.8 to +0.8 radians
		vec3 spotPos = vec3(sin(swingAngle) * 0.6, 1.6, 1.8);
		
		// Spotlight always aims at center of glass sphere arrangement
		vec3 spotTarget = vec3(0.0, 0.15, 0.7);
		vec3 spotDir = normalize(spotTarget - spotPos);
		
		// Warm white light with slight color shift based on swing position
		vec3 spotCol = vec3(1.0, 0.95, 0.85) * 1.8;
		spotCol.r += sin(swingAngle) * 0.1;
		spotCol.b -= sin(swingAngle) * 0.1;
		
		float innerAngle = 0.15;
		float outerAngle = 0.45;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, innerAngle, outerAngle);
	}
	
	// === COUNTER-ROTATING SPOTLIGHT ===
	// Rotates opposite to the carousel for dynamic shadow interplay
	{
		float counterAngle = -time * orbitSpeed * 1.5 + 1.57;
		vec3 counterSpotPos = vec3(
			cos(counterAngle) * 1.0,
			1.2,
			1.5 + sin(counterAngle) * 0.3
		);
		
		vec3 counterTarget = vec3(0.0, 0.1, 0.4);
		vec3 counterDir = normalize(counterTarget - counterSpotPos);
		
		// Cooler complementary color
		vec3 counterCol = vec3(0.7, 0.85, 1.0) * 1.2;
		
		float innerAngle = 0.2;
		float outerAngle = 0.5;
		col += getSpotLight(hitPos, counterSpotPos, counterDir, normals, rd, counterCol, innerAngle, outerAngle);
	}
#endif
	
	// === OVERHEAD PULSE LIGHT ===
	// Central light that breathes in intensity, creating pulsing caustic brightness
	{
		float breathe = 0.6 + 0.4 * sin(time * pulseSpeed * 0.7);
		vec3 overheadPos = vec3(0.0, 2.0, 0.8);
		vec3 overheadCol = vec3(1.0, 0.98, 0.96) * breathe * 1.2;
		col += getPointLight(hitPos, overheadPos, normals, rd, refRd, overheadCol, mate);
	}
	
	return col;
}

// O(1): Caustics demo scene - transparent objects casting colored shadows
// pos: world-space position being sampled
// Returns: vec4(albedo.rgb, distance)
vec4 causticScene(vec3 pos) {
	
	// Ground plane: light matte floor to clearly show caustic colors
	Material planeMat = createMaterial(vec3(0.9, 0.88, 0.85), 0.0, 0.6);
	float planeDist = fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0);
	SceneResult scene = sceneResult(planeDist, planeMat);
	
	// === GLASS SPHERES - Main caustic demonstration ===
	// Arranged in a wide arc at Z=0.7, spaced apart so each casts distinct caustics
	float glassRadius = 0.16;
	float glassY = glassRadius + 0.02;
	float glassZ = 0.7;  // Back row - caustics cast forward onto floor
	
	// Red glass sphere (far left)
	vec3 redGlassPos = pos - vec3(-0.75, glassY, glassZ);
	Material redGlass = Material(
		vec3(0.95, 0.15, 0.1),  // Deep ruby red
		0.0, 0.02,
		vec3(0.0),
		0.0, 0.0, vec3(1.0),
		0.95, 1.52, 0.0
	);
	SceneResult redGlassSphere = sceneResult(fSphere(redGlassPos, glassRadius), redGlass);
	scene = sceneMin(scene, redGlassSphere);
	
	// Green glass sphere (center-left)
	vec3 greenGlassPos = pos - vec3(-0.25, glassY, glassZ + 0.1);
	Material greenGlass = Material(
		vec3(0.1, 0.9, 0.2),  // Emerald green
		0.0, 0.02,
		vec3(0.0),
		0.0, 0.0, vec3(1.0),
		0.96, 1.45, 0.0
	);
	SceneResult greenGlassSphere = sceneResult(fSphere(greenGlassPos, glassRadius), greenGlass);
	scene = sceneMin(scene, greenGlassSphere);
	
	// Blue glass sphere (center-right)
	vec3 blueGlassPos = pos - vec3(0.25, glassY, glassZ + 0.05);
	Material blueGlass = Material(
		vec3(0.1, 0.35, 0.95),  // Sapphire blue
		0.0, 0.02,
		vec3(0.0),
		0.0, 0.0, vec3(1.0),
		0.95, 1.55, 0.0
	);
	SceneResult blueGlassSphere = sceneResult(fSphere(blueGlassPos, glassRadius), blueGlass);
	scene = sceneMin(scene, blueGlassSphere);
	
	// Amber glass sphere (far right)
	vec3 amberGlassPos = pos - vec3(0.75, glassY, glassZ);
	Material amberGlass = Material(
		vec3(0.95, 0.55, 0.05),  // Warm amber
		0.0, 0.02,
		vec3(0.0),
		0.0, 0.0, vec3(1.0),
		0.94, 1.48, 0.0
	);
	SceneResult amberGlassSphere = sceneResult(fSphere(amberGlassPos, glassRadius), amberGlass);
	scene = sceneMin(scene, amberGlassSphere);
	
	// === FRONT ROW - Water and Crystal ===
	// Positioned in front to show different caustic characteristics
	
	// Large water sphere (center front) - clear with cyan tint
	vec3 waterPos = pos - vec3(0.0, 0.14, 0.15);
	SceneResult waterDrop = sceneResult(
		fSphere(waterPos, 0.12),
		matWater()
	);
	scene = sceneMin(scene, waterDrop);
	
	// Crystal prism (left front) - high IOR for strong refraction
	vec3 prismPos = pos - vec3(-0.45, 0.1, 0.0);
	mat3 prismRot = getRotationMatrix(vec3(0.0, 1.0, 0.0), 0.3);
	vec3 rotPrismPos = prismRot * prismPos;
	Material prismMat = Material(
		vec3(0.95, 0.92, 1.0),  // Clear with slight violet
		0.0, 0.01,
		vec3(0.0),
		0.0, 0.0, vec3(1.0),
		0.97, 2.2, 0.0  // High IOR like diamond
	);
	SceneResult prism = sceneResult(
		fBox(rotPrismPos, vec3(0.05, 0.14, 0.035)),
		prismMat
	);
	scene = sceneMin(scene, prism);
	
#if RM_ENABLE_SSS
	// === SSS OBJECTS - Show colored shadow bleeding ===
	// Positioned to sides so their shadows don't overlap glass caustics
	
	// Skin sphere (right side)
	vec3 sssPos = pos - vec3(0.55, 0.13, 0.2);
	SceneResult sssSphere = sceneResult(
		fSphere(sssPos, 0.11),
		matSkin(vec3(0.95, 0.75, 0.65))
	);
	scene = sceneMin(scene, sssSphere);
	
	// Jade sphere (left side)
	vec3 jadePos = pos - vec3(-0.55, 0.12, 0.15);
	SceneResult jadeSphere = sceneResult(
		fSphere(jadePos, 0.1),
		matJade(vec3(0.2, 0.6, 0.35))
	);
	scene = sceneMin(scene, jadeSphere);
#endif

#if RM_ENABLE_IRIDESCENCE
	// Iridescent soap bubble (front center-right)
	vec3 iriPos = pos - vec3(0.35, 0.12, -0.1);
	SceneResult iriSphere = sceneResult(
		fSphere(iriPos, 0.1),
		matSoapBubble()
	);
	scene = sceneMin(scene, iriSphere);
#endif
	
	// Set global material for lighting to use
	gMaterial = scene.mat;
	
	// Return legacy format for compatibility (albedo.rgb, dist)
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene-specific background
vec3 causticBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	// Scene backgrounds should read as "sky": evaluate in ray-direction space (rd),
	// not in screen space (uv). This ensures the background sits behind geometry
	// and rotates naturally with the camera.

	// Base sky
	vec3 baseCol = rmDefaultBackground(rd, ro);

	// Re-introduce the geometric caustics pattern, but mapped onto the sky dome.
	// Using sky UV keeps the pattern stable in world space instead of overlaying the screen.
	vec2 suv = skyUV;

	// Fade pattern out near the horizon and below it.
	float aboveHorizon = smoothstep(0.02, 0.10, rd.y);
	float zenithFade = 1.0 - smoothstep(0.55, 0.95, suv.y);
	float patFade = aboveHorizon * zenithFade;

	// Hexagonal tiling coordinates
	const float HEX_SCALE = 22.0;
	const float SQRT3 = 1.7320508;
	vec2 uvHex = suv * HEX_SCALE;

	// Skew to hex grid coordinates
	vec2 q = vec2(
		uvHex.x - uvHex.y / SQRT3,
		uvHex.y * 2.0 / SQRT3
	);

	// Identify hex tile center
	vec2 id = floor(q);
	vec2 hex;
	hex.x = id.x + (id.y / 2.0);
	hex.y = id.y;

	// Center position of the current hex tile in "hex space"
	vec2 hexCenter = vec2(
		hex.x + 0.5 * mod(hex.y, 2.0),
		hex.y * SQRT3 * 0.5
	);

	// Local coordinates within the hex tile
	vec2 local = uvHex - hexCenter;

	// Animate color using tile ID and time
	float hue = fract((hex.x * 0.19 + hex.y * 0.073 + 0.13 * iTime));
	vec3 prism = 0.70 + 0.30 * cos(6.2831 * (hue + vec3(0.0, 0.33, 0.66)));

	// Mask out hexagon shape (distance from center in hex tile space)
	float hexRadius = 0.42;
	float ax = abs(local.x), ay = abs(local.y);
	float innerHex = max(
		ax * 0.8660254 + ay * 0.5,
		ay
	) - hexRadius;
	float edge = smoothstep(0.035, 0.0, innerHex);

	// Animated geometric line pattern inside hexes
	float linePattern = sin(36.0 * (local.x + local.y) + iTime * 0.7) * 0.5 + 0.5;
	linePattern *= smoothstep(0.10, 0.00, abs(local.x - local.y));

	// Micro tessellation inside each hex
	vec2 micro = fract(local * 10.0 + 0.5) - 0.5;
	float microD = max(abs(micro.x), abs(micro.y));
	float microShape = smoothstep(0.22, 0.08, microD);

	vec3 patternCol =
		prism * edge * (0.7 + 0.22 * linePattern)
		+ vec3(1.0) * linePattern * edge * 0.07
		+ vec3(0.85, 0.9, 1.0) * microShape * edge * 0.18;

	// Blend pattern into sky
	baseCol += patternCol * patFade * 0.55;

	return baseCol;
}

#endif
