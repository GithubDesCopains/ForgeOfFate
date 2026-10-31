class_name Ennemi
extends Resource

## Fiche d'ennemi sérialisable : PV, riposte, récompenses et faces optionnelles.

@export var nom: String = "Ennemi"
@export var pv_max: int = 8
@export var degats_riposte: int = 2
@export var recompense_or: int = 2
@export var recompense_eclats: int = 1
@export var faces: Array[FaceData] = []

var est_boss: bool = false


func a_un_de() -> bool:
	return not faces.is_empty()


func lancer_riposte(rng: RandomNumberGenerator) -> Dictionary:
	var degats: int = degats_riposte
	var face: FaceData = null
	if a_un_de():
		face = faces[rng.randi() % faces.size()]
		if face.attaque > 0:
			degats = face.attaque
	return { "degats": degats, "face": face }
