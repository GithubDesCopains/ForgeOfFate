class_name De
extends RefCounted

## Dé de dice-crafting : 6 faces, remplacement (ajouter une face = relique rare).

const NB_FACES_MAX: int = 6

var faces: Array[Face] = []
var dernier_index: int = -1


func _init(faces_personnalisees: Array[Face] = []) -> void:
	if faces_personnalisees.is_empty():
		faces = faces_de_depart()
	else:
		faces = faces_personnalisees.duplicate()


static func faces_de_depart() -> Array[Face]:
	return [
		Face.simple(Face.Type.ATTAQUE, 3),
		Face.simple(Face.Type.ATTAQUE, 2),
		Face.simple(Face.Type.DEFENSE, 2),
		Face.simple(Face.Type.DEFENSE, 2),
		Face.simple(Face.Type.OR, 2),
		Face.simple(Face.Type.OR, 1),
	]


func lancer(rng: RandomNumberGenerator = null) -> Face:
	assert(not faces.is_empty(), "Le dé doit posséder au moins une face.")
	if rng == null:
		dernier_index = randi() % faces.size()
	else:
		dernier_index = rng.randi() % faces.size()
	return faces[dernier_index]


func peut_ajouter_face() -> bool:
	return faces.size() < NB_FACES_MAX


func ajouter_face(face: Face) -> bool:
	if not peut_ajouter_face():
		return false
	faces.append(face)
	return true


func remplacer_face(index: int, face: Face) -> bool:
	if index < 0 or index >= faces.size():
		return false
	faces[index] = face
	return true


func dupliquer() -> De:
	var copies: Array[Face] = []
	for f in faces:
		copies.append(f.dupliquer())
	return De.new(copies)
