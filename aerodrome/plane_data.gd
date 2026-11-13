class_name PlaneData
extends RefCounted

const ROUTE_TIMES := [1.0, 0.9, 0.6, 0.6, 1.4, 0.6, 0.6, 0.7, 1.1, 0.8]

const ERAS := {
	"1920s": ["avro504k", "dh4a", "dh16", "goliath"],
}

const ALL := {
	"avro504k": {
		"name": "Avro 504K", "era": "1920s", "role": "Joyride biplane",
		"seats": 2, "min_pax": 2, "runway": 1, "weight": 4.0,
		"landing": 30, "takeoff": 20, "size": 0.8, "engines": 1,
		"body": Color(0.82, 0.76, 0.58), "wing": Color(0.74, 0.62, 0.38),
		"blurb": "A First World War trainer that became the joyride plane of the early 1920s. Nigel Love's company assembled Avro 504Ks at Mascot, and a flight cost four guineas.",
	},
	"dh4a": {
		"name": "Airco DH.4A", "era": "1920s", "role": "Converted bomber",
		"seats": 2, "min_pax": 2, "runway": 1, "weight": 3.0,
		"landing": 40, "takeoff": 25, "size": 0.9, "engines": 1,
		"body": Color(0.55, 0.58, 0.4), "wing": Color(0.48, 0.5, 0.32),
		"blurb": "A de Havilland wartime bomber converted to carry a passenger. An Airco DH.4A flew the first scheduled daily international service, from Hounslow Heath to Le Bourget, on 25 August 1919.",
	},
	"dh16": {
		"name": "Airco DH.16", "era": "1920s", "role": "Four-seat airliner",
		"seats": 4, "min_pax": 4, "runway": 1, "weight": 2.0,
		"landing": 70, "takeoff": 45, "size": 1.05, "engines": 1,
		"body": Color(0.88, 0.85, 0.72), "wing": Color(0.7, 0.66, 0.5),
		"blurb": "A four-seat passenger biplane designed for airline work. KLM's first flight, from Croydon to Schiphol on 17 May 1920, used a leased DH.16.",
	},
	"goliath": {
		"name": "Farman F.60 Goliath", "era": "1920s", "role": "Bomber turned airliner",
		"seats": 12, "min_pax": 8, "runway": 2, "weight": 1.0,
		"landing": 150, "takeoff": 90, "size": 1.5, "engines": 2,
		"body": Color(0.62, 0.68, 0.74), "wing": Color(0.5, 0.56, 0.62),
		"blurb": "The Goliath started as a bomber and became one of the first airliners. In February 1919 one carried twelve passengers from France to England.",
	},
}

static func route_total() -> float:
	var s := 0.0
	for x in ROUTE_TIMES:
		s += float(x)
	return s

static func landing_frac() -> float:
	return float(ROUTE_TIMES[0]) / route_total()

static func takeoff_frac() -> float:
	var s := 0.0
	for i in 8:
		s += float(ROUTE_TIMES[i])
	return s / route_total()

static func eligible(pool: int, runway_level: int) -> Array:
	var out: Array = []
	for id in ALL:
		var p: Dictionary = ALL[id]
		if int(p["min_pax"]) <= pool and int(p["runway"]) <= runway_level:
			out.append(id)
	return out
