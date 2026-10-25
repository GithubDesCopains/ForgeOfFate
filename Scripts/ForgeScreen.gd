class_name ForgeScreen
extends Control

@onready var _or_label: Label = $Marge/VBox/Ressources/OrLabel
@onready var _eclats_label: Label = $Marge/VBox/Ressources/EclatsLabel
@onready var _soin_label: Label = $Marge/VBox/SoinLabel
@onready var _de_list: VBoxContainer = $Marge/VBox/Scroll/Colonnes/DeBox/DeList
@onready var _boutique_list: VBoxContainer = $Marge/VBox/Scroll/Colonnes/BoutiqueBox/BoutiqueList
@onready var _message: Label = $Marge/VBox/Message
@onready var _bouton_annuler: Button = $Marge/VBox/Actions/BoutonAnnuler
@onready var _bouton_combat: Button = $Marge/VBox/Actions/BoutonCombat

var _index_face_a_remplacer: int = -1
var _lignes_de: Array[Control] = []


func _ready() -> void:
	_bouton_combat.pressed.connect(_on_bouton_combat_presse)
	_bouton_annuler.pressed.connect(_on_annuler)
	_bouton_annuler.disabled = true
	var nom_ennemi: String = EtatPartie.ennemi_actuel.nom if EtatPartie.ennemi_actuel else "?"
	_soin_label.text = "Soin : PV %d / %d (+%d). Prochain adversaire : %s." % [
		EtatPartie.pv_joueur, EtatPartie.pv_max_joueur, EtatPartie.SOIN_FORGE, nom_ennemi
	]
	if EtatPartie.offre_forge.is_empty():
		EtatPartie.regenerer_offre()
	_message.text = "Sélectionnez une face de votre dé, puis achetez pour la remplacer."
	_rafraichir()


func _rafraichir() -> void:
	_or_label.text = "Or : %d" % EtatPartie.or_total
	_eclats_label.text = "Éclats : %d" % EtatPartie.eclats
	_reconstruire_de()
	_reconstruire_boutique()
	_bouton_annuler.disabled = _index_face_a_remplacer < 0


func _reconstruire_de() -> void:
	for enfant in _de_list.get_children():
		enfant.queue_free()
	_lignes_de.clear()
	var faces: Array[Face] = EtatPartie.de_joueur.faces
	for i in faces.size():
		var ligne := PanelContainer.new()
		var wrap := HBoxContainer.new()
		ligne.add_child(wrap)
		var label := Label.new()
		label.text = "Face %d : %s" % [i + 1, str(faces[i])]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_child(label)
		var bouton := Button.new()
		bouton.text = "Choisir"
		bouton.pressed.connect(_on_remplacer_presse.bind(i))
		wrap.add_child(bouton)
		if i == _index_face_a_remplacer:
			ligne.modulate = Color(1.15, 0.95, 0.55, 1)
		_de_list.add_child(ligne)
		_lignes_de.append(ligne)


func _reconstruire_boutique() -> void:
	for enfant in _boutique_list.get_children():
		enfant.queue_free()
	for offre in EtatPartie.offre_forge:
		var ligne := HBoxContainer.new()
		var label := Label.new()
		var prix: String = _texte_prix(offre)
		var restant: int = EtatPartie.stock_de(offre)
		label.text = "%s   —   %s   (stock %d)" % [str(offre.face), prix, restant]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ligne.add_child(label)
		var bouton := Button.new()
		bouton.text = "Acheter"
		var peut: bool = (
			_index_face_a_remplacer >= 0
			and restant > 0
			and EtatPartie.peut_payer(offre.cout_or, offre.cout_eclats)
		)
		bouton.disabled = not peut
		bouton.pressed.connect(_on_acheter_presse.bind(offre))
		ligne.add_child(bouton)
		_boutique_list.add_child(ligne)


func _texte_prix(offre: OffreForge) -> String:
	if offre.cout_eclats > 0 and offre.cout_or > 0:
		return "%d or + %d éclat(s)" % [offre.cout_or, offre.cout_eclats]
	if offre.cout_eclats > 0:
		return "%d éclat(s)" % offre.cout_eclats
	return "%d or" % offre.cout_or


func _on_acheter_presse(offre: OffreForge) -> void:
	if _index_face_a_remplacer < 0:
		_message.text = "Sélectionnez d'abord la face de votre dé à remplacer."
		return
	if EtatPartie.stock_de(offre) <= 0:
		_message.text = "Rupture de stock."
		return
	if not EtatPartie.peut_payer(offre.cout_or, offre.cout_eclats):
		_message.text = "Ressources insuffisantes (%s)." % _texte_prix(offre)
		return
	EtatPartie.depenser_or(offre.cout_or)
	EtatPartie.depenser_eclats(offre.cout_eclats)
	EtatPartie.consommer_stock(offre)
	var index: int = _index_face_a_remplacer
	EtatPartie.de_joueur.remplacer_face(index, offre.face.dupliquer())
	_index_face_a_remplacer = -1
	_rafraichir()
	_message.text = "Face %d remplacée par « %s »." % [index + 1, str(offre.face)]


func _on_remplacer_presse(index: int) -> void:
	_index_face_a_remplacer = index
	_rafraichir()
	_message.text = "Face %d sélectionnée. Choisissez une offre, ou Annuler." % (index + 1)


func _on_annuler() -> void:
	_index_face_a_remplacer = -1
	_rafraichir()
	_message.text = "Sélection annulée. Choisissez une face de votre dé."


func _on_bouton_combat_presse() -> void:
	EtatPartie.aller_au_combat()
