class_name ForgeScreen
extends Control

const ForgeRules = preload("res://Scripts/Forge.gd")

@onready var _or_label: Label = $Marge/VBox/Ressources/OrLabel
@onready var _eclats_label: Label = $Marge/VBox/Ressources/EclatsLabel
@onready var _soin_label: Label = $Marge/VBox/SoinLabel
@onready var _de_titre: Label = $Marge/VBox/Scroll/Colonnes/DeBox/DeTitre
@onready var _de_list: VBoxContainer = $Marge/VBox/Scroll/Colonnes/DeBox/DeList
@onready var _boutique_list: VBoxContainer = $Marge/VBox/Scroll/Colonnes/BoutiqueBox/BoutiqueList
@onready var _message: Label = $Marge/VBox/Message
@onready var _bouton_annuler: Button = $Marge/VBox/Actions/BoutonAnnuler
@onready var _bouton_combat: Button = $Marge/VBox/Actions/BoutonCombat

var _index_de_selectionne: int = -1
var _index_face_selectionnee: int = -1


func _ready() -> void:
	_connecter_signaux()
	_bouton_annuler.disabled = true
	_bouton_combat.pressed.connect(_on_bouton_combat_presse)
	_bouton_annuler.pressed.connect(_on_annuler)

	if EtatPartie.phase != EtatPartie.Phase.FORGE:
		_message.text = "La Forge est accessible après une victoire."
		_actualiser()
		return

	EtatPartie.preparer_forge()
	_index_de_selectionne = -1
	_index_face_selectionnee = -1
	_message.text = "Sélectionnez un dé, puis une face à remplacer."
	_actualiser()


func _connecter_signaux() -> void:
	if not EtatPartie.or_change.is_connected(_on_or_change):
		EtatPartie.or_change.connect(_on_or_change)
	if not EtatPartie.eclats_change.is_connected(_on_eclats_change):
		EtatPartie.eclats_change.connect(_on_eclats_change)
	if not EtatPartie.pv_joueur_change.is_connected(_on_pv_change):
		EtatPartie.pv_joueur_change.connect(_on_pv_change)


func _actualiser() -> void:
	_or_label.text = "Or : %d" % EtatPartie.or_total
	_eclats_label.text = "Éclats : %d" % EtatPartie.eclats
	_soin_label.text = "PV : %d / %d" % [
		EtatPartie.pv_joueur,
		EtatPartie.pv_max_joueur,
	]
	_reconstruire_des()
	_reconstruire_offres()
	_bouton_annuler.disabled = _index_face_selectionnee < 0
	_bouton_combat.disabled = EtatPartie.phase != EtatPartie.Phase.FORGE


func _reconstruire_des() -> void:
	_effacer_enfants(_de_list)
	_de_titre.text = "Dés du joueur (%d)" % EtatPartie.des_joueur.size()

	var onglets := HBoxContainer.new()
	onglets.name = "SelectionDes"
	for index_de in EtatPartie.des_joueur.size():
		var bouton := Button.new()
		bouton.name = "De%d" % (index_de + 1)
		bouton.text = "Dé %d%s" % [
			index_de + 1,
			" ✓" if index_de == _index_de_selectionne else "",
		]
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bouton.pressed.connect(_on_selectionner_de.bind(index_de))
		onglets.add_child(bouton)
	_de_list.add_child(onglets)

	for index_face in EtatPartie.des_joueur.size():
		var de: De = EtatPartie.des_joueur[index_face]
		if de == null:
			continue
		for index in de.faces.size():
			var ligne := HBoxContainer.new()
			ligne.name = "De%dFace%d" % [index_face + 1, index + 1]
			var label := Label.new()
			label.text = "Face %d : %s" % [index + 1, de.faces[index].donnees]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ligne.add_child(label)

			var bouton := Button.new()
			var est_selectionnee: bool = (
				index_face == _index_de_selectionne
				and index == _index_face_selectionnee
			)
			bouton.text = "Sélectionnée" if est_selectionnee else "Choisir"
			bouton.disabled = index_face != _index_de_selectionne
			bouton.pressed.connect(_on_selectionner_face.bind(index))
			ligne.add_child(bouton)
			if est_selectionnee:
				ligne.modulate = Color(1.15, 0.95, 0.55, 1)
			_de_list.add_child(ligne)


func _reconstruire_offres() -> void:
	_effacer_enfants(_boutique_list)
	for offre in EtatPartie.offre_forge:
		if offre == null:
			continue
		var ligne := HBoxContainer.new()
		ligne.name = "Offre_" + offre.id

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var description := Label.new()
		description.text = "%s — %s" % [offre.id, offre.face]
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(description)

		var stock_restant: int = EtatPartie.stock_de(offre)
		var prix: String = _texte_prix(offre)
		var etat_achat: String = _texte_etat_achat(offre, stock_restant)
		var informations := Label.new()
		informations.text = "%s | Stock : %d | %s" % [prix, stock_restant, etat_achat]
		informations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(informations)
		ligne.add_child(details)

		var bouton := Button.new()
		bouton.name = "Acheter_" + offre.id
		bouton.text = "Acheter"
		bouton.disabled = not ForgeRules.peut_acheter_offre(
			_index_de_selectionne,
			_index_face_selectionnee,
			offre
		)
		bouton.pressed.connect(_on_acheter_presse.bind(offre))
		ligne.add_child(bouton)
		_boutique_list.add_child(ligne)


func _texte_prix(offre: OffreForge) -> String:
	var couts: PackedStringArray = []
	if offre.cout_or > 0:
		couts.append("%d or" % offre.cout_or)
	if offre.cout_eclats > 0:
		couts.append("%d éclat(s)" % offre.cout_eclats)
	if couts.is_empty():
		return "Gratuit"
	return " + ".join(couts)


func _texte_etat_achat(offre: OffreForge, stock_restant: int) -> String:
	if _index_de_selectionne < 0 or _index_face_selectionnee < 0:
		return "Choisissez un dé et une face"
	if stock_restant <= 0:
		return "Épuisée"
	if not ForgeRules.peut_acheter_offre(
			_index_de_selectionne,
			_index_face_selectionnee,
			offre
	):
		return "Ressources insuffisantes ou offre invalide"
	return "Disponible"


func _effacer_enfants(parent: Node) -> void:
	for enfant in parent.get_children():
		parent.remove_child(enfant)
		enfant.queue_free()


func _on_selectionner_de(index_de: int) -> void:
	if index_de < 0 or index_de >= EtatPartie.des_joueur.size():
		return
	_index_de_selectionne = index_de
	_index_face_selectionnee = -1
	_message.text = "Dé %d sélectionné. Choisissez une face à remplacer." % (index_de + 1)
	_actualiser()


func _on_selectionner_face(index_face: int) -> void:
	if _index_de_selectionne < 0 or _index_de_selectionne >= EtatPartie.des_joueur.size():
		return
	var de: De = EtatPartie.des_joueur[_index_de_selectionne]
	if index_face < 0 or index_face >= de.faces.size():
		return
	_index_face_selectionnee = index_face
	_message.text = "Face %d du dé %d sélectionnée." % [
		index_face + 1,
		_index_de_selectionne + 1,
	]
	_actualiser()


func _on_acheter_presse(offre: OffreForge) -> void:
	if not ForgeRules.acheter_offre(
			_index_de_selectionne,
			_index_face_selectionnee,
			offre
	):
		_message.text = "Achat refusé : vérifiez la sélection, le stock et vos ressources."
		_actualiser()
		return

	_message.text = "Face remplacée par « %s »." % offre.face
	_actualiser()


func _on_annuler() -> void:
	_index_de_selectionne = -1
	_index_face_selectionnee = -1
	_message.text = "Sélection annulée."
	_actualiser()


func _on_bouton_combat_presse() -> void:
	if EtatPartie.phase != EtatPartie.Phase.FORGE:
		_message.text = "Impossible de démarrer un combat depuis cette phase."
		return
	EtatPartie.aller_au_combat()


func _on_or_change(total: int) -> void:
	_or_label.text = "Or : %d" % total
	_reconstruire_offres()


func _on_eclats_change(total: int) -> void:
	_eclats_label.text = "Éclats : %d" % total
	_reconstruire_offres()


func _on_pv_change(pv_actuels: int, pv_max: int) -> void:
	_soin_label.text = "PV : %d / %d" % [pv_actuels, pv_max]
