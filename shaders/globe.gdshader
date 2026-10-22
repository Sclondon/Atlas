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
// The chunky look: Salmon Run 2's own 1024 map (and the lights to match), with hard-edged texels.
uniform sampler2D day_low : source_color, filter_nearest, repeat_enable;
uniform sampler2D night_low : source_color, filter_nearest, repeat_enable;
uniform bool low_res = false;
// Turns the Earth so the place of interest faces the viewer (camera-from-world).
uniform mat3 view = mat3(1.0);
// Size of the picture, where the middle of the globe is in it and how big it is, in pixels.
uniform vec2 rect_size = vec2(400.0);
uniform vec2 center = vec2(200.0);
uniform float globe_radius = 170.0;
// How big the picture's pixels are drawn (1 for a smooth picture).
uniform float pixel = 2.0;
uniform vec3 space : source_color = vec3(0.006, 0.008, 0.02);
// The whole sky's stars (NASA's Deep Star Maps, in right ascension and declination), how bright
// they are drawn, and how far the Earth has turned under them (Greenwich sidereal time, radians).
uniform sampler2D star_map : source_color, filter_linear, repeat_enable;
uniform float star_gain = 0.45;
uniform float sky_turn = 0.0;
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

vec4 day_at(vec2 uv) {
	return low_res ? texture(day_low, uv) : texture(day_map, uv);
}

vec4 night_at(vec2 uv) {
	return low_res ? texture(night_low, uv) : texture(night_map, uv);
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
	vec3 c = day_at(uv).rgb;
	return smoothstep(0.02, 0.08, c.b - max(c.r, c.g * 0.9));
}

// The ground, as the old map draws it: parchment land, pale seas and an inked coast.
vec3 parchment(vec2 uv, vec3 sat) {
	float sea = ocean_at(uv);
	float e = low_res ? 1.0 / 1024.0 : 1.2 / 2048.0;
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

// The northern and southern lights, as curtains standing up off the Earth: a thin wavering
// ring round each magnetic pole, streaked with rays along its length. This is how dense the
// curtain is at a direction from the middle of the Earth; aurora_glow gives it its height.
const vec3 MAG_POLE = vec3(-0.155, 0.986, 0.049);
// How high the curtains reach, with the Earth's radius as 1 (far taller than life, to be seen).
const float AURORA_TOP = 0.13;

float aurora_ring(vec3 dir) {
	vec3 pole = dot(dir, MAG_POLE) >= 0.0 ? MAG_POLE : -MAG_POLE;
	vec3 e1 = normalize(cross(pole, vec3(0.0, 0.0, 1.0)));
	vec3 e2 = cross(pole, e1);
	float around = atan(dot(dir, e2), dot(dir, e1));
	float from_pole = acos(clamp(dot(dir, pole), -1.0, 1.0));
	// the ring snakes in and out, slowly, and folds over on itself in places
	vec2 ring = vec2(cos(around), sin(around));
	float wave = (noise(vec3(ring * 2.5, TIME * 0.08)) - 0.5) * 0.14 + (noise(vec3(ring * 8.0, TIME * 0.18 + 4.0)) - 0.5) * 0.05;
	float off = (from_pole - 0.33 - wave) / 0.022;
	float sheet = exp(-off * off);
	// a second, fainter curtain a little poleward
	float off2 = (from_pole - 0.29 - wave * 1.3) / 0.015;
	sheet += 0.45 * exp(-off2 * off2);
	float rays = noise(vec3(ring * 55.0, TIME * 0.6));
	float bright = noise(vec3(ring * 3.0, TIME * 0.05 + 9.0));
	return sheet * (0.3 + 0.7 * rays * rays) * smoothstep(0.2, 0.6, bright);
}

// The aurora seen along this pixel's line of sight, marched through the shell the curtains
// stand in: in front of the globe, and out past its edge into space. Green low down, going to
// red and violet at the tops.
vec3 aurora_glow(vec2 p, float r2, mat3 to_world, vec3 sun, float jitter) {
	float top = 1.0 + AURORA_TOP;
	if (r2 >= top * top) {
		return vec3(0.0);
	}
	float z_near = sqrt(top * top - r2);
	// (stopping at the ground where the line of sight meets it)
	float z_far = r2 < 1.0 ? sqrt(1.0 - r2) : -z_near;
	const int STEPS = 22;
	float dz = (z_near - z_far) / float(STEPS);
	vec3 glow = vec3(0.0);
	for (int i = 0; i < STEPS; i++) {
		float z = z_near - (float(i) + jitter) * dz;
		vec3 at = to_world * vec3(p, z);
		float r = length(at);
		vec3 dir = at / r;
		// only near the ring of either pole (a cheap test before the noise)
		float dp = abs(dot(dir, MAG_POLE));
		if (dp < 0.86 || dp > 0.99) {
			continue;
		}
		float h = (r - 1.0) / AURORA_TOP;
		// a sharp foot just above the ground and a long fade upward
		float tall = smoothstep(0.04, 0.12, h) * exp(-max(h - 0.12, 0.0) * 2.6);
		// (only in the dark: none at all when the whole globe is lit)
		float dark = 1.0 - mix(1.0, smoothstep(-0.2, 0.08, dot(dir, sun)), night);
		float d = aurora_ring(dir) * tall * dark;
		vec3 tint = mix(vec3(0.15, 1.0, 0.45), vec3(0.85, 0.2, 0.55), smoothstep(0.35, 0.95, h));
		glow += tint * d * dz;
	}
	return glow * 26.0;
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
	// space: the real sky behind the Earth (NASA's Deep Star Maps, as in Close Encounters), seen
	// past the globe in the way the camera faces, turned by the Earth's sidereal time so the stars
	// stand where they truly are over it. Going closer does not magnify them: they are far away.
	vec2 q = (px - center) / (0.5 * min(rect_size.x, rect_size.y));
	q.y = -q.y;
	vec3 look = to_world * normalize(vec3(q * 0.9, -1.0));
	float ra = atan(look.x, look.z) + sky_turn;
	vec2 sky_uv = vec2(0.5 - ra / TAU, 0.5 - asin(clamp(look.y, -1.0, 1.0)) / PI);
	// (darkened toward black between the stars, the bright ones brighter, and those twinkling)
	vec3 field = pow(texture(star_map, sky_uv).rgb, vec3(2.6)) * 1.3;
	float bright = max(field.r, max(field.g, field.b));
	vec2 star_cell = floor(sky_uv * 2048.0);
	float twinkle = 1.0 + smoothstep(0.35, 0.9, bright) * 0.45 * sin(TIME * (2.0 + hash(vec3(star_cell, 1.0)) * 7.0) + hash(vec3(star_cell, 3.0)) * 40.0);
	// (kept well behind the Earth: the Milky Way a soft band, the stars points)
	vec3 col = space + field * (star_gain + smoothstep(0.15, 0.6, bright) * 3.5) * twinkle;
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
		vec3 sat = day_at(uv).rgb;
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
		vec3 town = night_at(uv).rgb;
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
	}
	// the aurora's curtains, standing up off the night side (light, so they add on)
	if (aurora > 0.0 && old_map < 1.0) {
		col += aurora_glow(p, r2, to_world, sun, hash(vec3(cell, 11.0))) * aurora;
	}
	COLOR = vec4(col, 1.0);
}
