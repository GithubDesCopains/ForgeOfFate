class_name VueDe
extends Control

## Dé 2D animé + lecture des 6 faces.

@onready var _cube: ColorRect = $Cube
@onready var _label_face: Label = $Cube/LabelFace
@onready var _faces_box: HBoxContainer = $FacesBox

var _tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0
	rafraichir_faces(-1)


func rafraichir_faces(index_actif: int = -1) -> void:
	if _faces_box == null:
		return
	for enfant in _faces_box.get_children():
		enfant.queue_free()
	if EtatPartie.de_joueur == null:
		return
	var faces: Array[Face] = EtatPartie.de_joueur.faces
	for i in faces.size():
		var chip := Label.new()
		chip.text = " %d:%s " % [i + 1, _resume(faces[i])]
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i == index_actif:
			chip.modulate = Color(1.0, 0.85, 0.35, 1)
		else:
			chip.modulate = Color(0.75, 0.82, 0.95, 1)
		_faces_box.add_child(chip)


func animer_lancer(face: Face, index: int) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_cube.pivot_offset = _cube.size / 2.0
	for _i in 6:
		_tween.tween_property(_cube, "rotation_degrees", _cube.rotation_degrees + 60.0, 0.07)
		_tween.tween_callback(_afficher_face_aleatoire)
	_tween.tween_callback(_afficher.bind(face, index))
	_tween.tween_property(_cube, "rotation_degrees", 0.0, 0.12)


func _afficher_face_aleatoire() -> void:
	var faces: Array[Face] = EtatPartie.de_joueur.faces
	if faces.is_empty():
		return
	var face: Face = faces[EtatPartie.rng.randi() % faces.size()]
	_label_face.text = str(face)
	_cube.color = _couleur_pour(face)


func _afficher(face: Face, index: int) -> void:
	_label_face.text = str(face)
	_cube.color = _couleur_pour(face)
	rafraichir_faces(index)


func _resume(face: Face) -> String:
	var morceaux: PackedStringArray = []
	if face.attaque > 0:
		morceaux.append("A%d" % face.attaque)
	if face.defense > 0:
		morceaux.append("D%d" % face.defense)
	if face.or_gain > 0:
		morceaux.append("O%d" % face.or_gain)
	if face.soin > 0:
		morceaux.append("S%d" % face.soin)
	if face.special != Face.Special.AUCUN:
		morceaux.append("*")
	if morceaux.is_empty():
		return "?"
	return "+".join(morceaux)


func _couleur_pour(face: Face) -> Color:
	if face.attaque > 0 and face.or_gain > 0:
		return Color(0.55, 0.32, 0.18, 1)
	if face.attaque > 0:
		return Color(0.55, 0.18, 0.22, 1)
	if face.defense > 0:
		return Color(0.18, 0.32, 0.55, 1)
	if face.or_gain > 0:
		return Color(0.55, 0.45, 0.12, 1)
	if face.soin > 0:
		return Color(0.18, 0.48, 0.32, 1)
	return Color(0.28, 0.3, 0.38, 1)
