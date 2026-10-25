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
		_faces_box.remove_child(enfant)
		enfant.queue_free()
	if EtatPartie.de_joueur == null:
		return
	var faces: Array[Face] = EtatPartie.de_joueur.faces
	for i in faces.size():
		var chip := PanelContainer.new()
		var label := Label.new()
		label.text = "%d:%s" % [i + 1, _resume(faces[i])]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var face := faces[i]
		var col_fond := _couleur_pour(face)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		style.bg_color = Color(col_fond.r * 0.35, col_fond.g * 0.35, col_fond.b * 0.35, 0.9)
		
		if i == index_actif:
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(1.0, 0.88, 0.4, 1.0)
			label.modulate = Color(1.0, 0.95, 0.6, 1.0)
		else:
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = Color(col_fond.r, col_fond.g, col_fond.b, 0.5)
			label.modulate = Color(0.85, 0.88, 0.95, 1.0)
			
		chip.add_theme_stylebox_override("panel", style)
		chip.add_child(label)
		_faces_box.add_child(chip)


func animer_lancer(face: Face, index: int) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_cube.pivot_offset = _cube.size / 2.0
	_cube.rotation_degrees = 0.0
	_cube.scale = Vector2.ONE
	
	_tween.parallel().tween_property(_cube, "scale", Vector2(0.92, 0.92), 0.1)
	for i in 6:
		_tween.tween_property(_cube, "rotation_degrees", (i + 1) * 60.0, 0.07)
		_tween.tween_callback(_afficher_face_aleatoire)
	_tween.tween_callback(func() -> void:
		_cube.rotation_degrees = 0.0
		_afficher(face, index)
	)
	_tween.tween_property(_cube, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_cube, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
