class_name VueDe
extends Control

## Dé 2D animé + lecture des faces pour 1 ou plusieurs dés.

@onready var _cube1: ColorRect = $DesRangee/Cube1
@onready var _label_face1: Label = $DesRangee/Cube1/LabelFace
@onready var _cube2: ColorRect = $DesRangee/Cube2
@onready var _label_face2: Label = $DesRangee/Cube2/LabelFace
@onready var _faces_box: VBoxContainer = $FacesBox

var _tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0
	rafraichir_toutes_faces([-1, -1])


func rafraichir_faces(index_actif: int = -1) -> void:
	rafraichir_toutes_faces([index_actif, -1])


func rafraichir_toutes_faces(indices_actifs: Array = [-1, -1]) -> void:
	if _faces_box == null:
		return
	for enfant in _faces_box.get_children():
		_faces_box.remove_child(enfant)
		enfant.queue_free()
	
	var des: Array[De] = EtatPartie.des_joueur
	if des.is_empty():
		return
		
	for de_idx in des.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		
		var nom_label := Label.new()
		nom_label.text = "Dé %d :" % (de_idx + 1)
		nom_label.custom_minimum_size = Vector2(40, 0)
		nom_label.add_theme_font_size_override("font_size", 12)
		nom_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.8))
		row.add_child(nom_label)
		
		var faces: Array[Face] = des[de_idx].faces
		var index_actif: int = indices_actifs[de_idx] if de_idx < indices_actifs.size() else -1
		
		for i in faces.size():
			var chip := PanelContainer.new()
			var label := Label.new()
			label.text = "%d:%s" % [i + 1, _resume(faces[i])]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var face := faces[i]
			var col_fond := _couleur_pour(face)
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(5)
			style.content_margin_left = 4.0
			style.content_margin_right = 4.0
			style.content_margin_top = 3.0
			style.content_margin_bottom = 3.0
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
			row.add_child(chip)
			
		_faces_box.add_child(row)


func animer_lancers(faces: Array[Face], indices: Array[int]) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	
	var cubes: Array[ColorRect] = [_cube1, _cube2]
	
	for c in cubes:
		c.pivot_offset = c.size / 2.0
		c.rotation_degrees = 0.0
		c.scale = Vector2.ONE
	
	_tween.parallel().tween_property(_cube1, "scale", Vector2(0.92, 0.92), 0.1)
	_tween.parallel().tween_property(_cube2, "scale", Vector2(0.92, 0.92), 0.1)
	
	for i in 6:
		_tween.tween_property(_cube1, "rotation_degrees", (i + 1) * 60.0, 0.07)
		_tween.parallel().tween_property(_cube2, "rotation_degrees", (i + 1) * -60.0, 0.07)
		_tween.tween_callback(func() -> void:
			_afficher_face_aleatoire_cube(_cube1, _label_face1, 0)
			_afficher_face_aleatoire_cube(_cube2, _label_face2, 1)
		)
		
	_tween.tween_callback(func() -> void:
		_cube1.rotation_degrees = 0.0
		_cube2.rotation_degrees = 0.0
		if faces.size() > 0:
			_afficher_cube(_cube1, _label_face1, faces[0])
		if faces.size() > 1:
			_afficher_cube(_cube2, _label_face2, faces[1])
		rafraichir_toutes_faces(indices)
	)
	
	_tween.tween_property(_cube1, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_cube2, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_cube1, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_cube2, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func animer_lancer(face: Face, index: int) -> void:
	animer_lancers([face], [index])


func _afficher_face_aleatoire_cube(cube: ColorRect, label: Label, de_idx: int) -> void:
	var des: Array[De] = EtatPartie.des_joueur
	if de_idx >= des.size():
		return
	var faces: Array[Face] = des[de_idx].faces
	if faces.is_empty():
		return
	var face: Face = faces[EtatPartie.rng.randi() % faces.size()]
	label.text = str(face)
	cube.color = _couleur_pour(face)


func _afficher_cube(cube: ColorRect, label: Label, face: Face) -> void:
	label.text = str(face)
	cube.color = _couleur_pour(face)


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
