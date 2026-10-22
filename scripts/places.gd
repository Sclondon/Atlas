extends RefCounted
## The places you can pick from when adding a stop (any spot on the globe can also be tapped),
## and the journeys a new player starts with. Each place is [name, latitude, longitude].

const LIST := [
	# North America
	["Anchorage", 61.22, -149.9], ["Vancouver", 49.28, -123.12], ["Seattle", 47.61, -122.33],
	["San Francisco", 37.77, -122.42], ["Los Angeles", 34.05, -118.24], ["Las Vegas", 36.17, -115.14],
	["Grand Canyon", 36.06, -112.14], ["Phoenix", 33.45, -112.07], ["Salt Lake City", 40.76, -111.89],
	["Denver", 39.74, -104.99], ["Roswell", 33.39, -104.52], ["Mexico City", 19.43, -99.13],
	["Chichen Itza", 20.68, -88.57], ["Dallas", 32.78, -96.8], ["Houston", 29.76, -95.37],
	["New Orleans", 29.95, -90.07], ["Chicago", 41.88, -87.63], ["Detroit", 42.33, -83.05],
	["Atlanta", 33.75, -84.39], ["Miami", 25.76, -80.19], ["Havana", 23.11, -82.37],
	["Washington, D.C.", 38.91, -77.04], ["New York", 40.71, -74.01], ["Boston", 42.36, -71.06],
	["Salem", 42.52, -70.9], ["Sleepy Hollow", 41.09, -73.86], ["Toronto", 43.65, -79.38],
	["Montreal", 45.5, -73.57], ["Niagara Falls", 43.08, -79.07], ["Honolulu", 21.31, -157.86],
	["Yellowstone", 44.43, -110.59], ["Mount Rushmore", 43.88, -103.46], ["Panama Canal", 9.08, -79.68],
	["Nuuk", 64.18, -51.72], ["North Pole", 89.99, 0.0],
	# South America
	["Bogota", 4.71, -74.07], ["Quito", -0.18, -78.47], ["Galapagos Islands", -0.74, -90.32],
	["Lima", -12.05, -77.04], ["Machu Picchu", -13.16, -72.55], ["Cusco", -13.53, -71.97],
	["Nazca Lines", -14.74, -75.13], ["La Paz", -16.5, -68.15], ["Amazon (Manaus)", -3.12, -60.02],
	["Rio de Janeiro", -22.91, -43.17], ["Sao Paulo", -23.55, -46.63], ["Buenos Aires", -34.6, -58.38],
	["Santiago", -33.45, -70.67], ["Easter Island", -27.11, -109.35], ["Tierra del Fuego", -54.8, -68.3],
	["Angel Falls", 5.97, -62.54],
	# Europe
	["Reykjavik", 64.15, -21.94], ["Dublin", 53.35, -6.26], ["Edinburgh", 55.95, -3.19],
	["Loch Ness", 57.32, -4.44], ["London", 51.51, -0.13], ["Stonehenge", 51.18, -1.83],
	["Paris", 48.86, 2.35], ["Brussels", 50.85, 4.35], ["Amsterdam", 52.37, 4.9],
	["Berlin", 52.52, 13.4], ["Prague", 50.08, 14.44], ["Vienna", 48.21, 16.37],
	["Venice", 45.44, 12.32], ["Rome", 41.9, 12.5], ["Pompeii", 40.75, 14.49],
	["Madrid", 40.42, -3.7], ["Lisbon", 38.72, -9.14], ["Barcelona", 41.39, 2.17],
	["Monte Carlo", 43.74, 7.43], ["Zurich", 47.38, 8.54], ["Copenhagen", 55.68, 12.57],
	["Oslo", 59.91, 10.75], ["Stockholm", 59.33, 18.07], ["Helsinki", 60.17, 24.94],
	["Warsaw", 52.23, 21.01], ["Budapest", 47.5, 19.04], ["Transylvania (Bran Castle)", 45.52, 25.37],
	["Athens", 37.98, 23.73], ["Santorini", 36.39, 25.46], ["Istanbul", 41.01, 28.98],
	["Moscow", 55.76, 37.62], ["St Petersburg", 59.93, 30.34], ["Kyiv", 50.45, 30.52],
	# Africa and the Middle East
	["Marrakesh", 31.63, -7.99], ["Casablanca", 33.57, -7.59], ["Tangier", 35.76, -5.83],
	["Timbuktu", 16.77, -3.01], ["Dakar", 14.72, -17.47], ["Lagos", 6.52, 3.38],
	["Cairo", 30.04, 31.24], ["Giza Pyramids", 29.98, 31.13], ["Tanis", 30.98, 31.88],
	["Valley of the Kings", 25.74, 32.6], ["Alexandria", 31.2, 29.92], ["Petra", 30.33, 35.44],
	["Jerusalem", 31.77, 35.21], ["Baghdad", 33.31, 44.37], ["Tehran", 35.69, 51.39],
	["Dubai", 25.2, 55.27], ["Mecca", 21.42, 39.83], ["Addis Ababa", 9.03, 38.74],
	["Nairobi", -1.29, 36.82], ["Kilimanjaro", -3.07, 37.35], ["Zanzibar", -6.17, 39.2],
	["Victoria Falls", -17.92, 25.86], ["Kinshasa", -4.44, 15.27], ["Cape Town", -33.92, 18.42],
	["Johannesburg", -26.2, 28.05], ["Madagascar", -18.88, 47.51], ["Sahara (Hoggar)", 23.29, 5.53],
	# Asia
	["Samarkand", 39.65, 66.96], ["Kabul", 34.53, 69.17], ["Karachi", 24.86, 67.0],
	["Delhi", 28.61, 77.21], ["Agra (Taj Mahal)", 27.18, 78.04], ["Mumbai (Bombay)", 19.08, 72.88],
	["Kolkata (Calcutta)", 22.57, 88.36], ["Kathmandu", 27.72, 85.32], ["Mount Everest", 27.99, 86.93],
	["Lhasa", 29.65, 91.11], ["Colombo", 6.93, 79.86], ["Bangkok", 13.76, 100.5],
	["Angkor Wat", 13.41, 103.87], ["Hanoi", 21.03, 105.85], ["Singapore", 1.35, 103.82],
	["Kuala Lumpur", 3.14, 101.69], ["Jakarta", -6.21, 106.85], ["Bali", -8.41, 115.19],
	["Manila", 14.6, 120.98], ["Hong Kong", 22.32, 114.17], ["Shanghai", 31.23, 121.47],
	["Beijing", 39.9, 116.41], ["Great Wall (Badaling)", 40.36, 116.02], ["Xi'an", 34.34, 108.94],
	["Ulaanbaatar", 47.89, 106.91], ["Seoul", 37.57, 126.98], ["Tokyo", 35.68, 139.69],
	["Yokohama", 35.44, 139.64], ["Kyoto", 35.01, 135.77], ["Mount Fuji", 35.36, 138.73],
	["Taipei", 25.03, 121.57], ["Vladivostok", 43.12, 131.89], ["Lake Baikal", 53.5, 108.0],
	["Tunguska", 60.89, 101.9], ["Novosibirsk", 55.0, 82.94],
	# Oceania and the poles
	["Sydney", -33.87, 151.21], ["Melbourne", -37.81, 144.96], ["Uluru", -25.34, 131.04],
	["Darwin", -12.46, 130.84], ["Perth", -31.95, 115.86], ["Great Barrier Reef", -18.29, 147.7],
	["Auckland", -36.85, 174.76], ["Queenstown", -45.03, 168.66], ["Fiji", -17.71, 178.07],
	["Tahiti", -17.65, -149.43], ["Port Moresby", -9.44, 147.18], ["Guam", 13.44, 144.79],
	["Midway Atoll", 28.21, -177.38], ["Pitcairn Island", -25.07, -130.1], ["Bermuda", 32.3, -64.78],
	["South Pole", -89.99, 0.0], ["McMurdo Station", -77.85, 166.67],
]

## The journeys a new player starts with.
const JOURNEYS := [
	{
		"name": "Raiders of the Lost Ark",
		"stops": [
			["Peruvian jungle", -6.23, -77.87], ["Marshall College", 41.31, -72.92],
			["San Francisco", 37.77, -122.42], ["Honolulu", 21.31, -157.86], ["Manila", 14.6, 120.98],
			["Nepal", 27.72, 85.32], ["Cairo", 30.04, 31.24], ["Tanis", 30.98, 31.88],
		],
	},
	{
		"name": "Around the World in 80 Days",
		"stops": [
			["London", 51.51, -0.13], ["Suez", 29.97, 32.55], ["Bombay", 19.08, 72.88],
			["Calcutta", 22.57, 88.36], ["Hong Kong", 22.32, 114.17], ["Yokohama", 35.44, 139.64],
			["San Francisco", 37.77, -122.42], ["New York", 40.71, -74.01], ["London", 51.51, -0.13],
		],
	},
	{
		"name": "Haunted Grand Tour",
		"stops": [
			["Salem", 42.52, -70.9], ["Sleepy Hollow", 41.09, -73.86], ["New Orleans", 29.95, -90.07],
			["Edinburgh", 55.95, -3.19], ["Transylvania (Bran Castle)", 45.52, 25.37],
			["Valley of the Kings", 25.74, 32.6], ["Roswell", 33.39, -104.52],
		],
	},
]


## The nearest place in the list to a spot, and how far away it is (radians).
static func nearest(lat: float, lon: float) -> Array:
	var at := vec(lat, lon)
	var best: Array = LIST[0]
	var best_d := INF
	for p: Array in LIST:
		var d := at.angle_to(vec(p[1], p[2]))
		if d < best_d:
			best_d = d
			best = p
	return [best, best_d]


## A point on the unit sphere: +y is north, and longitude 0 faces +z.
static func vec(lat: float, lon: float) -> Vector3:
	var a := deg_to_rad(lat)
	var o := deg_to_rad(lon)
	return Vector3(cos(a) * sin(o), sin(a), cos(a) * cos(o))


static func lat_lon(v: Vector3) -> Vector2:
	v = v.normalized()
	return Vector2(rad_to_deg(asin(clampf(v.y, -1.0, 1.0))), rad_to_deg(atan2(v.x, v.z)))


## "40.7°N 74.0°W"
static func coords(lat: float, lon: float) -> String:
	return "%.1f°%s %.1f°%s" % [absf(lat), "N" if lat >= 0.0 else "S", absf(lon), "E" if lon >= 0.0 else "W"]
