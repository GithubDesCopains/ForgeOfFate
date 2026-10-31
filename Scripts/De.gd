class_name De
extends RefCounted

enum FaceType { ATTAQUE, DEFENSE, OR }

class Face:
	var type: FaceType = FaceType.ATTAQUE
	var valeur: int = 0
	var donnees: FaceData

	func _init(p_type: FaceType = FaceType.ATTAQUE, p_valeur: int = 0) -> void:
		type = p_type
		valeur = p_valeur
		donnees = FaceData.new()
		match type:
			FaceType.ATTAQUE:
				donnees.attaque = valeur
			FaceType.DEFENSE:
				donnees.defense = valeur
			FaceType.OR:
				donnees.or_gain = valeur

	static func depuis_donnees(face_data: FaceData) -> Face:
		assert(face_data != null, "Les données de face ne peuvent pas être nulles.")
		var face := Face.new()
		face.donnees = face_data.dupliquer()
		# type/valeur exposent l'effet principal, donnees conserve la face complète.
		if face_data.attaque > 0:
			face.type = FaceType.ATTAQUE
			face.valeur = face_data.attaque
		elif face_data.defense > 0:
			face.type = FaceType.DEFENSE
			face.valeur = face_data.defense
		elif face_data.or_gain > 0:
			face.type = FaceType.OR
			face.valeur = face_data.or_gain
		return face

	func comme_donnees() -> FaceData:
		return donnees.dupliquer()

	func dupliquer() -> Face:
		return Face.depuis_donnees(donnees)

var faces: Array[Face] = []

func _init(faces_personnalisees: Array[Face] = []) -> void:
	if faces_personnalisees.is_empty():
		faces = faces_de_depart()
	else:
		faces = faces_personnalisees.duplicate()


static func depuis_faces_data(faces_data: Array[FaceData]) -> De:
	assert(not faces_data.is_empty(), "La liste de faces du dé ne peut pas être vide.")
	var faces_runtime: Array[Face] = []
	for face_data in faces_data:
		faces_runtime.append(Face.depuis_donnees(face_data))
	return De.new(faces_runtime)


static func faces_de_depart() -> Array[Face]:
	return [
		Face.new(FaceType.ATTAQUE, 2),
		Face.new(FaceType.ATTAQUE, 2),
		Face.new(FaceType.DEFENSE, 2),
		Face.new(FaceType.DEFENSE, 2),
		Face.new(FaceType.OR, 1),
		Face.new(FaceType.OR, 1),
	]

func remplacer_face(index: int, face: Face) -> bool:
	if face == null or index < 0 or index >= faces.size():
		return false
	faces[index] = face.dupliquer()
	return true

func lancer(rng: RandomNumberGenerator = null) -> Face:
	assert(not faces.is_empty(), "Le dé doit posséder au moins une face.")
	var index: int = randi() % faces.size()
	if rng != null:
		index = rng.randi_range(0, faces.size() - 1)
	return faces[index]

static func nom_type(type_face: FaceType) -> String:
	match type_face:
		FaceType.ATTAQUE: return "Attaque"
		FaceType.DEFENSE: return "Défense"
		FaceType.OR: return "Or"
	return "?"
