class_name CombatScreen
extends Control

@onready var _salle: Label = $Marge/VBox/Entete/Salle
@onready var _or_bourse: Label = $Marge/VBox/Entete/OrBourse
@onready var _eclats: Label = $Marge/VBox/Entete/Eclats
@onready var _ennemi_nom: Label = $Marge/VBox/Colonnes/EnnemiBox/EnnemiInner/EnnemiNom
@onready var _ennemi_pv: Label = $Marge/VBox/Colonnes/EnnemiBox/EnnemiInner/EnnemiPV
@onready var _poison: Label = $Marge/VBox/Colonnes/EnnemiBox/EnnemiInner/Poison
@onready var _vue_de: VueDe = $Marge/VBox/Colonnes/CentreBox/VueDe
@onready var _resultat_de: Label = $Marge/VBox/Colonnes/CentreBox/ResultatDe
@onready var _riposte: Label = $Marge/VBox/Colonnes/CentreBox/Riposte
@onready var _joueur_pv: Label = $Marge/VBox/Colonnes/JoueurBox/JoueurInner/JoueurPV
@onready var _bouclier: Label = $Marge/VBox/Colonnes/JoueurBox/JoueurInner/Bouclier
@onready var _or_salle: Label = $Marge/VBox/Colonnes/JoueurBox/JoueurInner/OrSalle
@onready var _ennemi_box: PanelContainer = $Marge/VBox/Colonnes/EnnemiBox
@onready var _joueur_box: PanelContainer = $Marge/VBox/Colonnes/JoueurBox
@onready var _ennemi_pv_bar: ProgressBar = $Marge/VBox/Colonnes/EnnemiBox/EnnemiInner/EnnemiPVBar
@onready var _joueur_pv_bar: ProgressBar = $Marge/VBox/Colonnes/JoueurBox/JoueurInner/JoueurPVBar
@onready var _bouton_lancer: Button = $Marge/VBox/BoutonLancer
@onready var _bouton_forge: Button = $Marge/VBox/BoutonForge
@onready var _bouton_titre: Button = $Marge/VBox/BoutonTitre
@onready var _message_fin: Label = $Marge/VBox/MessageFin
@onready var _combat: CombatManager = $CombatManager

var _dernier_pv_joueur: int = -1
var _dernier_bouclier: int = -1
var _dernier_or_salle: int = -1


func _ready() -> void:
	_combat.de_lance.connect(_on_de_lance)
	_combat.riposte_annonce.connect(_on_riposte_annonce)
	_combat.degats_infliges.connect(_on_degats_infliges)
	_combat.pv_joueur_change.connect(_on_pv_joueur_change)
	_combat.pv_ennemi_change.connect(_on_pv_ennemi_change)
	_combat.bouclier_change.connect(_on_bouclier_change)
	_combat.or_salle_change.connect(_on_or_salle_change)
	_combat.poison_change.connect(_on_poison_change)
	_combat.combat_termine.connect(_on_combat_termine)
	_combat.tour_joueur_pret.connect(_maj_bouton_lancer)
	EtatPartie.or_change.connect(_on_or_bourse_change)
	EtatPartie.eclats_change.connect(_on_eclats_change)

	_bouton_lancer.pressed.connect(_on_bouton_lancer)
	_bouton_forge.pressed.connect(_on_bouton_forge_presse)
	_bouton_titre.pressed.connect(_on_bouton_titre_presse)

	_bouton_forge.visible = false
	_bouton_titre.visible = false
	_poison.visible = false
	_riposte.text = ""
	_rafraichir_entete()
	if EtatPartie.ennemi_actuel:
		_ennemi_nom.text = EtatPartie.ennemi_actuel.nom
	_vue_de.rafraichir_faces(-1)
	_combat.demarrer_combat()
	_maj_bouton_lancer()


func _rafraichir_entete() -> void:
	_salle.text = "Salle %d" % EtatPartie.etage
	_or_bourse.text = "Bourse : %d or" % EtatPartie.or_total
	_eclats.text = "Éclats : %d" % EtatPartie.eclats


func _on_or_bourse_change(_total: int) -> void:
	_or_bourse.text = "Bourse : %d or" % EtatPartie.or_total


func _on_eclats_change(_total: int) -> void:
	_eclats.text = "Éclats : %d" % EtatPartie.eclats


func _on_bouton_lancer() -> void:
	if not _combat.peut_lancer():
		return
	_bouton_lancer.disabled = true
	_riposte.text = ""
	_combat.lancer_de_joueur()


func _maj_bouton_lancer() -> void:
	_bouton_lancer.disabled = not _combat.peut_lancer()


func _on_de_lance(face: Face, index: int) -> void:
	_resultat_de.text = "Face : %s" % str(face)
	if face.special == Face.Special.RELANCER:
		_riposte.text = "Relance : pas de riposte ce tour."
	_vue_de.animer_lancer(face, index)


func _on_riposte_annonce(nom_ennemi: String, degats: int, face: Face) -> void:
	if face != null:
		_riposte.text = "%s lance %s  →  %d dégâts" % [nom_ennemi, str(face), degats]
	else:
		_riposte.text = "%s riposte : %d dégâts" % [nom_ennemi, degats]


func _on_degats_infliges(cible: String, degats: int) -> void:
	if degats <= 0:
		return
	if cible == "ennemi":
		var pos_centre: Vector2 = _ennemi_box.global_position + _ennemi_box.size / 2.0
		_creer_popup("-%d" % degats, Color(1.0, 0.35, 0.35, 1.0), pos_centre)
		_secouer_et_flasher(_ennemi_box, Color(1.8, 0.4, 0.4, 1.0))
	elif cible == "joueur":
		var pos_centre: Vector2 = _joueur_box.global_position + _joueur_box.size / 2.0
		_creer_popup("-%d" % degats, Color(1.0, 0.35, 0.35, 1.0), pos_centre)
		_secouer_et_flasher(_joueur_box, Color(1.8, 0.4, 0.4, 1.0))


func _on_pv_joueur_change(pv_actuels: int, pv_max: int) -> void:
	_joueur_pv.text = "PV : %d / %d" % [pv_actuels, pv_max]
	_joueur_pv_bar.max_value = pv_max
	var tw := create_tween()
	tw.tween_property(_joueur_pv_bar, "value", float(pv_actuels), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _dernier_pv_joueur >= 0 and pv_actuels > _dernier_pv_joueur:
		var soin: int = pv_actuels - _dernier_pv_joueur
		var pos_centre: Vector2 = _joueur_box.global_position + _joueur_box.size / 2.0
		_creer_popup("+%d PV" % soin, Color(0.35, 1.0, 0.45, 1.0), pos_centre)
		_secouer_et_flasher(_joueur_box, Color(0.4, 1.8, 0.5, 1.0))
	_dernier_pv_joueur = pv_actuels


func _on_pv_ennemi_change(pv_actuels: int, pv_max: int) -> void:
	_ennemi_pv.text = "PV : %d / %d" % [pv_actuels, pv_max]
	_ennemi_pv_bar.max_value = pv_max
	var tw := create_tween()
	tw.tween_property(_ennemi_pv_bar, "value", float(pv_actuels), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_bouclier_change(valeur: int) -> void:
	_bouclier.text = "Bouclier : %d" % valeur
	if _dernier_bouclier >= 0 and valeur > _dernier_bouclier:
		var gain: int = valeur - _dernier_bouclier
		var pos_centre: Vector2 = _joueur_box.global_position + _joueur_box.size / 2.0
		_creer_popup("+%d 🛡" % gain, Color(0.4, 0.75, 1.0, 1.0), pos_centre)
	_dernier_bouclier = valeur


func _on_or_salle_change(montant: int) -> void:
	_or_salle.text = "Or de salle : %d" % montant
	if _dernier_or_salle >= 0 and montant > _dernier_or_salle:
		var gain: int = montant - _dernier_or_salle
		var pos_centre: Vector2 = _joueur_box.global_position + _joueur_box.size / 2.0
		_creer_popup("+%d 🪙" % gain, Color(1.0, 0.85, 0.3, 1.0), pos_centre)
	_dernier_or_salle = montant


func _creer_popup(texte: String, couleur: Color, position_globale: Vector2) -> void:
	var label := Label.new()
	label.text = texte
	label.theme_override_colors/font_color = couleur
	label.theme_override_font_sizes/font_size = 24
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.top_level = true
	label.position = position_globale + Vector2(-40, -20)
	label.z_index = 100
	add_child(label)
	
	var tw := create_tween()
	tw.parallel().tween_property(label, "position:y", label.position.y - 45.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "scale", Vector2(1.25, 1.25), 0.15)
	tw.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.3)
	tw.tween_callback(label.queue_free)


func _secouer_et_flasher(cible_noeud: Control, couleur_flash: Color) -> void:
	var tw := create_tween()
	cible_noeud.modulate = couleur_flash
	tw.tween_property(cible_noeud, "modulate", Color.WHITE, 0.22)
	
	var pos_initiale: float = cible_noeud.position.x
	tw.parallel().tween_property(cible_noeud, "position:x", pos_initiale - 8.0, 0.04)
	tw.tween_property(cible_noeud, "position:x", pos_initiale + 8.0, 0.04)
	tw.tween_property(cible_noeud, "position:x", pos_initiale - 4.0, 0.04)
	tw.tween_property(cible_noeud, "position:x", pos_initiale, 0.04)


func _on_poison_change(valeur: int) -> void:
	_poison.visible = valeur > 0
	_poison.text = "Poison : %d" % valeur


func _on_combat_termine(victoire: bool) -> void:
	_bouton_lancer.disabled = true
	if victoire:
		_message_fin.text = "Victoire ! L'or de salle rejoint la bourse.\nSoin à la forge : +%d PV." % EtatPartie.SOIN_FORGE
		_bouton_forge.visible = true
		_rafraichir_entete()
	else:
		_message_fin.text = "Défaite… Run terminée (salles gagnées : %d)." % EtatPartie.salles_gagnees
		_bouton_titre.visible = true


func _on_bouton_forge_presse() -> void:
	EtatPartie.aller_a_forge()


func _on_bouton_titre_presse() -> void:
	EtatPartie.retour_titre()
