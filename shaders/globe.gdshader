// The Earth hanging in space: Salmon Run 2's globe (NASA's Blue Marble wrapped on a sphere, under
// drifting cloud and hurricanes, in big pixels) with Close Encounters' night side (the lights of
// towns, here NASA's City Lights picture) and its thin blue rim of air.
//
// The sun is a real direction in the Earth's own frame (see sun_dir), so the night side turns
// with the globe. All the weather is set from weather.gd: how much cloud, how far it has
// drifted, where the hurricanes are and where lightning is flashing.
shader_type canvas_item;

uniform sampler2D day_map : source_color, filter_linear, repeat_enable;
uniform sampler2D night_map : source_color, filter_linear, repeat_enable;
// Turns the Earth so the place of interest faces the viewer (camera-from-world).
uniform mat3 view = mat3(1.0);
// Size of the picture, where the middle of the globe is in it and how big it is, in pixels.
uniform vec2 rect_size = vec2(400.0);
uniform vec2 center = vec2(200.0);
uniform float globe_radius = 170.0;
// How big the picture's pixels are drawn (1 for a smooth picture).
uniform float pixel = 2.0;
uniform vec3 space : source_color = vec3(0.012, 0.016, 0.045);
uniform vec3 air : source_color = vec3(0.4, 0.75, 1.0);

// Towards the sun, in the Earth's frame.
uniform vec3 sun_dir = vec3(0.0, 0.0, 1.0);
// 1 has a night side; 0 lights the whole globe as if it were noon everywhere.
uniform float night = 1.0;
uniform float city_lights = 1.0;
uniform float aurora = 0.0;
// 0 the satellite picture, 1 an old explorer's map: parchment land, pale seas, inked coasts.
uniform float old_map = 0.0;
uniform float grid = 0.0;

uniform float cloud_cover = 0.42;
uniform float cloud_opacity = 0.85;
// How far (in radians) the clouds have drifted east, and how long the storms have been turning.
uniform float cloud_drift = 0.0;
uniform float storm_turn = 0.0;
// How far above the ground the clouds float: the radius of their sphere, with the Earth's as 1.
uniform float cloud_height = 1.025;
// Hurricanes: the eye (a direction from the middle of the Earth) and the size in radians.
uniform int storm_count = 0;
uniform vec4 storms[6];
// Lightning: where (a direction) and how bright.
uniform vec4 flash = vec4(0.0, 0.0, 1.0, 0.0);

// A hash built from small multiplications rather than the sine of a big number: the sine
// trick loses its precision on phones and leaves seams and blocks in the noise.
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
			f.z);
}

vec2 map_uv(vec3 world) {
	float lat = asin(clamp(world.y, -1.0, 1.0));
	float lon = atan(world.x, world.z);
	return vec2(lon / TAU + 0.5, 0.5 - lat / PI);
}

// How much a storm covers a point: two arms winding in towards a dense middle with a clear eye.
// They turn anticlockwise north of the equator and clockwise south of it.
float storm_at(vec3 world, vec4 storm, float seed) {
	vec3 centre = storm.xyz;
	float d = acos(clamp(dot(world, centre), -1.0, 1.0)) / storm.w;
	if (d > 1.15) {
		return 0.0;
	}
	vec3 east = normalize(cross(vec3(0.0, 1.0, 0.0), centre) + vec3(0.0001, 0.0, 0.0));
	vec3 north = cross(centre, east);
	float angle = atan(dot(world, north), dot(world, east));
	float spin = centre.y >= 0.0 ? 1.0 : -1.0;
	// rough it up: the noise turns with the storm, pushing the bands in and out and tearing
	// holes in them, so it reads as weather rather than a drawn spiral
	float turn = spin * storm_turn * 0.12;
	vec2 local = vec2(cos(angle + turn), sin(angle + turn)) * d;
	float rough = noise(vec3(local * 5.0, seed * 3.0) + 9.0);
	float fine = noise(vec3(local * 13.0, seed * 7.0) + 4.0);
	d += (rough - 0.5) * 0.18;
	float arms = sin(angle * 2.0 + spin * (log(max(d, 0.0) + 0.04) * 4.5 - storm_turn * 0.5) + (rough - 0.5) * 1.4);
	float body = smoothstep(1.0, 0.35, d);
	float core = smoothstep(0.5, 0.22, d);
	float eye = smoothstep(0.04, 0.1, d);
	float cloud = max(smoothstep(-0.2, 0.6, arms) * body, core) * eye;
	return cloud * smoothstep(0.1, 0.42, fine + core * 0.6);
}

// How much cloud there is over a point (a direction from the centre of the Earth).
float cloud_at(vec3 world) {
	// noise on the sphere itself rather than on a flat map, drifting east; kept away from the
	// origin, where the lattice mirrors itself. Squashed north-south, so it lies in bands.
	float a = cloud_drift;
	vec3 c = vec3(world.x * cos(a) - world.z * sin(a), world.y * 1.6, world.x * sin(a) + world.z * cos(a)) + 23.0;
	float n = noise(c * 3.2) * 0.58 + noise(c * 7.0 + 11.0) * 0.27 + noise(c * 15.0 + 5.0) * 0.1 + noise(c * 34.0 + 2.0) * 0.05;
	float cloud = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.16, n);
	// with the cover all the way up it closes over completely
	cloud = max(cloud, smoothstep(0.85, 1.0, cloud_cover));
	for (int i = 0; i < 6; i++) {
		if (i >= storm_count) {
			break;
		}
		// a storm sweeps the sky around it clear, so it stands out as one system
		float d = acos(clamp(dot(world, storms[i].xyz), -1.0, 1.0)) / storms[i].w;
		cloud *= smoothstep(0.75, 1.35, d);
		cloud = max(cloud, storm_at(world, storms[i], float(i) * 1.7 + 1.0));
	}
	return cloud;
}

float ocean_at(vec2 uv) {
	vec3 c = texture(day_map, uv).rgb;
	return smoothstep(0.02, 0.08, c.b - max(c.r, c.g * 0.9));
}

// The ground, as the old map draws it: parchment land, pale seas and an inked coast.
vec3 parchment(vec2 uv, vec3 sat) {
	float sea = ocean_at(uv);
	float e = 1.2 / 2048.0;
	float coast = abs(ocean_at(uv + vec2(e, 0.0)) - ocean_at(uv - vec2(e, 0.0)))
			+ abs(ocean_at(uv + vec2(0.0, e)) - ocean_at(uv - vec2(0.0, e)));
	float lum = dot(sat, vec3(0.3, 0.5, 0.2));
	vec3 land = mix(vec3(0.74, 0.58, 0.36), vec3(0.96, 0.89, 0.7), clamp(lum * 2.2, 0.0, 1.0));
	vec3 water = mix(vec3(0.6, 0.68, 0.64), vec3(0.72, 0.76, 0.66), clamp(lum * 4.0, 0.0, 1.0));
	vec3 c = mix(land, water, sea);
	return mix(c, vec3(0.3, 0.18, 0.1), clamp(coast, 0.0, 1.0) * 0.85);
}

// Lines of latitude and longitude every 15 degrees.
float graticule(vec3 world, float width) {
	float lat = degrees(asin(clamp(world.y, -1.0, 1.0)));
	float lon = degrees(atan(world.x, world.z));
	float a = abs(fract(lat / 15.0 + 0.5) - 0.5) * 15.0;
	float b = abs(fract(lon / 15.0 + 0.5) - 0.5) * 15.0 * cos(radians(lat));
	return 1.0 - smoothstep(width * 0.5, width, min(a, b));
}

// The northern and southern lights: a thin wavering ring of curtains round each magnetic pole,
// streaked along its length, seen on the night side.
float aurora_at(vec3 world) {
	const vec3 POLE = vec3(-0.155, 0.986, 0.049);
	vec3 pole = dot(world, POLE) >= 0.0 ? POLE : -POLE;
	vec3 e1 = normalize(cross(pole, vec3(0.0, 0.0, 1.0)));
	vec3 e2 = cross(pole, e1);
	float around = atan(dot(world, e2), dot(world, e1));
	float from_pole = acos(clamp(dot(world, pole), -1.0, 1.0));
	// the ring snakes in and out, slowly
	vec2 ring = vec2(cos(around), sin(around));
	float wave = (noise(vec3(ring * 2.5, TIME * 0.08)) - 0.5) * 0.12 + (noise(vec3(ring * 7.0, TIME * 0.15 + 4.0)) - 0.5) * 0.04;
	float off = from_pole - 0.33 - wave;
	// a sharp lower edge with a glow trailing off above it
	float band = off < 0.0 ? exp(-off * off / 0.00025) : exp(-off / 0.035);
	float streaks = noise(vec3(ring * 40.0, TIME * 0.5));
	float bright = noise(vec3(ring * 3.0, TIME * 0.05 + 9.0));
	return band * (0.35 + 0.65 * streaks) * smoothstep(0.25, 0.65, bright);
}

void fragment() {
	vec2 cell = floor(UV * rect_size / pixel);
	vec2 px = (cell + 0.5) * pixel;
	vec2 p = (px - center) / globe_radius;
	p.y = -p.y;
	float r2 = dot(p, p);
	mat3 to_world = transpose(view);
	vec3 sun = normalize(sun_dir);
	vec3 eye = to_world * vec3(0.0, 0.0, 1.0);
	// space, with a scatter of stars that stay put as the globe turns
	float star = hash(vec3(cell * pixel / 3.0, 7.0));
	vec3 col = space + vec3(0.9, 0.95, 1.0) * step(0.9965, star) * (0.4 + 0.6 * hash(vec3(cell, 3.0)));
	if (r2 > 1.0) {
		// outside the globe: the atmosphere fading out into space, brighter on the sunny side
		vec3 edge = to_world * vec3(normalize(p), 0.0);
		float lit = mix(1.0, smoothstep(-0.35, 0.3, dot(edge, sun)), night);
		float d = (sqrt(r2) - 1.0) / 0.07;
		col = mix(col, air, pow(clamp(1.0 - d, 0.0, 1.0), 2.5) * 0.6 * lit);
	} else {
		vec3 cam = vec3(p, sqrt(1.0 - r2));
		vec3 world = to_world * cam;
		vec2 uv = map_uv(world);
		vec3 sat = texture(day_map, uv).rgb;
		float l = dot(world, sun);
		float day = mix(1.0, smoothstep(-0.12, 0.12, l), night);
		// the clouds are up in the air, so their shadows fall away from the sun
		float shadow = cloud_at(normalize(world * cloud_height + sun * (cloud_height - 1.0) * 2.0)) * cloud_opacity;
		vec3 ground = mix(sat, parchment(uv, sat), old_map);
		ground *= 1.0 - 0.45 * shadow * day;
		float light = mix(0.35 + 0.8 * clamp(l, 0.0, 1.0), 1.0, 1.0 - night);
		ground *= mix(light, 0.85 + 0.2 * light, old_map);
		// the sun glinting off the sea
		float sea = ocean_at(uv) * (1.0 - old_map);
		ground += vec3(1.0, 0.92, 0.75) * pow(max(dot(reflect(-sun, world), eye), 0.0), 140.0) * sea * 0.4 * night;
		// a warm band along the line between day and night
		ground += vec3(0.9, 0.35, 0.1) * 0.12 * exp(-abs(l) * 14.0) * night * (1.0 - old_map);
		// the night side: dark, but for the lights of towns
		// (by moonlight: dim and blue, but the shapes of the land still there)
		vec3 dark = mix(sat * vec3(0.09, 0.11, 0.17) + vec3(0.0, 0.004, 0.012), ground * 0.32, old_map);
		vec3 town = texture(night_map, uv).rgb;
		float glow = smoothstep(0.12, 0.55, town.r) * city_lights * (1.0 - shadow * 0.8);
		dark += vec3(1.0, 0.78, 0.42) * glow * 1.3 * (1.0 - old_map * 0.5);
		ground = mix(dark, ground, day);
		if (grid > 0.0) {
			float g = graticule(world, max(0.25, 90.0 * pixel / globe_radius));
			ground = mix(ground, mix(vec3(0.85, 0.92, 1.0), vec3(0.42, 0.24, 0.12), old_map), g * grid * 0.45);
		}
		// the air thickening towards the edge
		col = mix(ground, air, pow(1.0 - cam.z, 2.5) * 0.5 * mix(day, 1.0, old_map * 0.5));
	}
	// the cloud layer: a bigger sphere than the Earth, so it stands clear of the ground and
	// carries on past the edge of the globe
	float h2 = cloud_height * cloud_height;
	if (r2 < h2 && cloud_opacity > 0.0) {
		vec3 cam = vec3(p, sqrt(h2 - r2)) / cloud_height;
		vec3 world = to_world * cam;
		float cloud = cloud_at(world) * cloud_opacity * mix(1.0, 0.55, old_map);
		float l = dot(world, sun);
		float lit = mix(1.0, smoothstep(-0.15, 0.25, l), night);
		vec3 white = mix(vec3(0.07, 0.08, 0.12), vec3(1.0) * (0.6 + 0.5 * clamp(l, 0.0, 1.0)), lit);
		white = mix(white, vec3(0.97, 0.93, 0.82), old_map * 0.7);
		// lightning lights the cloud round it from inside
		float zap = acos(clamp(dot(world, flash.xyz), -1.0, 1.0));
		float bolt = flash.w * exp(-zap * zap / 0.0012);
		white += vec3(0.75, 0.82, 1.0) * bolt * 2.0;
		col = mix(col, white, clamp(cloud + bolt * cloud * 0.5, 0.0, 1.0));
		// aurora, glowing over the cloud tops on the night side
		if (aurora > 0.0 && old_map < 1.0) {
			float glow = aurora_at(world) * aurora * (1.0 - lit);
			col += mix(vec3(0.2, 1.0, 0.5), vec3(0.8, 0.3, 0.7), smoothstep(0.6, 0.1, glow)) * glow * 0.7;
		}
	}
	COLOR = vec4(col, 1.0);
}
