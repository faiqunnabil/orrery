class_name LunarTheory
extends RefCounted

const DELTA_T_SECONDS := 69.2
const MEAN_DISTANCE_KM := 385000.56
const PRECESSION_DEG_PER_CENTURY := 1.396888
const PRECESSION_DEG_PER_CENTURY_SQUARED := 0.000307

const LONGITUDE_DISTANCE_TERMS := [
	[0, 0, 1, 0, 6288774, -20905355],
	[2, 0, -1, 0, 1274027, -3699111],
	[2, 0, 0, 0, 658314, -2955968],
	[0, 0, 2, 0, 213618, -569925],
	[0, 1, 0, 0, -185116, 48888],
	[0, 0, 0, 2, -114332, -3149],
	[2, 0, -2, 0, 58793, 246158],
	[2, -1, -1, 0, 57066, -152138],
	[2, 0, 1, 0, 53322, -170733],
	[2, -1, 0, 0, 45758, -204586],
	[0, 1, -1, 0, -40923, -129620],
	[1, 0, 0, 0, -34720, 108743],
	[0, 1, 1, 0, -30383, 104755],
	[2, 0, 0, -2, 15327, 10321],
	[0, 0, 1, 2, -12528, 0],
	[0, 0, 1, -2, 10980, 79661],
	[4, 0, -1, 0, 10675, -34782],
	[0, 0, 3, 0, 10034, -23210],
	[4, 0, -2, 0, 8548, -21636],
	[2, 1, -1, 0, -7888, 24208],
	[2, 1, 0, 0, -6766, 30824],
	[1, 0, -1, 0, -5163, -8379],
	[1, 1, 0, 0, 4987, -16675],
	[2, -1, 1, 0, 4036, -12831],
	[2, 0, 2, 0, 3994, -10445],
	[4, 0, 0, 0, 3861, -11650],
	[2, 0, -3, 0, 3665, 14403],
	[0, 1, -2, 0, -2689, -7003],
	[2, 0, -1, 2, -2602, 0],
	[2, -1, -2, 0, 2390, 10056],
	[1, 0, 1, 0, -2348, 6322],
	[2, -2, 0, 0, 2236, -9884],
]
const LATITUDE_TERMS := [
	[0, 0, 0, 1, 5128122],
	[0, 0, 1, 1, 280602],
	[0, 0, 1, -1, 277693],
	[2, 0, 0, -1, 173237],
	[2, 0, -1, 1, 55413],
	[2, 0, -1, -1, 46271],
	[2, 0, 0, 1, 32573],
	[0, 0, 2, 1, 17198],
	[2, 0, 1, -1, 9266],
	[0, 0, 2, -1, 8822],
	[2, -1, 0, -1, 8216],
	[2, 0, -2, -1, 4324],
	[2, 0, 1, 1, 4200],
	[2, 1, 0, -1, -3359],
	[2, -1, -1, 1, 2463],
	[2, -1, 0, 1, 2211],
	[2, -1, -1, -1, 2065],
	[0, 1, -1, -1, -1870],
	[4, 0, -1, -1, 1828],
	[0, 1, 0, 1, -1794],
]


static func position_km(centuries: float) -> DVec3:
	var t := centuries + DELTA_T_SECONDS / Astro.SECONDS_PER_CENTURY
	var t2 := t * t
	var t3 := t2 * t
	var t4 := t3 * t
	var mean_longitude := 218.3164477 + 481267.88123421 * t - 0.0015786 * t2 + t3 / 538841.0 - t4 / 65194000.0
	var elongation := 297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868.0 - t4 / 113065000.0
	var sun_anomaly := 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000.0
	var moon_anomaly := 134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699.0 - t4 / 14712000.0
	var latitude_argument := 93.2720950 + 483202.0175233 * t - 0.0036539 * t2 - t3 / 3526000.0 + t4 / 863310000.0
	var a1 := deg_to_rad(119.75 + 131.849 * t)
	var a2 := deg_to_rad(53.09 + 479264.290 * t)
	var a3 := deg_to_rad(313.45 + 481266.484 * t)
	var eccentricity_factor := 1.0 - 0.002516 * t - 0.0000074 * t2
	var sum_longitude := 0.0
	var sum_distance := 0.0
	for term: Array in LONGITUDE_DISTANCE_TERMS:
		var argument := deg_to_rad(term[0] * elongation + term[1] * sun_anomaly + term[2] * moon_anomaly + term[3] * latitude_argument)
		var factor := pow(eccentricity_factor, absi(term[1]))
		sum_longitude += term[4] * factor * sin(argument)
		sum_distance += term[5] * factor * cos(argument)
	var sum_latitude := 0.0
	for term: Array in LATITUDE_TERMS:
		var argument := deg_to_rad(term[0] * elongation + term[1] * sun_anomaly + term[2] * moon_anomaly + term[3] * latitude_argument)
		sum_latitude += term[4] * pow(eccentricity_factor, absi(term[1])) * sin(argument)
	var l_rad := deg_to_rad(mean_longitude)
	var f_rad := deg_to_rad(latitude_argument)
	var mp_rad := deg_to_rad(moon_anomaly)
	sum_longitude += 3958.0 * sin(a1) + 1962.0 * sin(l_rad - f_rad) + 318.0 * sin(a2)
	sum_latitude += (
		-2235.0 * sin(l_rad) + 382.0 * sin(a3) + 175.0 * sin(a1 - f_rad) + 175.0 * sin(a1 + f_rad)
		+ 127.0 * sin(l_rad - mp_rad) - 115.0 * sin(l_rad + mp_rad)
	)
	var precession := PRECESSION_DEG_PER_CENTURY * t + PRECESSION_DEG_PER_CENTURY_SQUARED * t2
	var longitude := deg_to_rad(mean_longitude + sum_longitude / 1.0e6 - precession)
	var latitude := deg_to_rad(sum_latitude / 1.0e6)
	var distance := MEAN_DISTANCE_KM + sum_distance / 1000.0
	return DVec3.new(
		distance * cos(latitude) * cos(longitude), distance * cos(latitude) * sin(longitude), distance * sin(latitude)
	)
