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
@onready var _bouton_lancer: Button = $Marge/VBox/BoutonLancer
@onready var _bouton_forge: Button = $Marge/VBox/BoutonForge
@onready var _bouton_titre: Button = $Marge/VBox/BoutonTitre
@onready var _message_fin: Label = $Marge/VBox/MessageFin
@onready var _combat: CombatManager = $CombatManager


func _ready() -> void:
	_combat.de_lance.connect(_on_de_lance)
	_combat.riposte_annonce.connect(_on_riposte_annonce)
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


func _on_pv_joueur_change(pv_actuels: int, pv_max: int) -> void:
	_joueur_pv.text = "PV : %d / %d" % [pv_actuels, pv_max]


func _on_pv_ennemi_change(pv_actuels: int, pv_max: int) -> void:
	_ennemi_pv.text = "PV : %d / %d" % [pv_actuels, pv_max]


func _on_bouclier_change(valeur: int) -> void:
	_bouclier.text = "Bouclier : %d" % valeur


func _on_or_salle_change(montant: int) -> void:
	_or_salle.text = "Or de salle : %d" % montant


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
