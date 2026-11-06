extends MeshInstance3D

const RADIUS := 0.502  # just above the globe's surface
const LINE_COLOR := Color(0.75, 0.88, 1.0, 1.0)

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://borders.json")
	var countries = JSON.parse_string(text)

	var verts := PackedVector3Array()
	for country in countries:
		for ring in country["rings"]:
			for i in range(ring.size() - 1):
				verts.append(_to_sphere(ring[i][0], ring[i][1]))
				verts.append(_to_sphere(ring[i + 1][0], ring[i + 1][1]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh = m

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = LINE_COLOR
	material_override = mat

func _to_sphere(lon_deg: float, lat_deg: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	return Vector3(
		cos(lat) * sin(lon),
		sin(lat),
		cos(lat) * cos(lon)
	) * RADIUS
