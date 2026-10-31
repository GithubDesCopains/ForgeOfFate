class_name CombatScreen
extends Control

const SCENE_FORGE: String = "res://Scenes/Forge.tscn"
const SCRIPT_FORGE: String = "res://Scripts/ForgeScreen.gd"

@onready var combat_manager: CombatManager = $CombatManager
@onready var label_pv_joueur: Label = $CenterContainer/VBoxContainer/JoueurPV
@onready var label_pv_ennemi: Label = $CenterContainer/VBoxContainer/EnnemiPV
@onready var label_bouclier: Label = $CenterContainer/VBoxContainer/Bouclier
@onready var label_resultat: Label = $CenterContainer/VBoxContainer/ResultatDe
@onready var label_or: Label = $CenterContainer/VBoxContainer/OrSalle
@onready var label_message: Label = $CenterContainer/VBoxContainer/MessageCombat
@onready var bouton_lancer: Button = $CenterContainer/VBoxContainer/BoutonLancer
@onready var bouton_forge: Button = $CenterContainer/VBoxContainer/BoutonForge

var _combat_initialise: bool = false
var _forge_disponible: bool = false


func _ready() -> void:
	_forge_disponible = (
		ResourceLoader.exists(SCENE_FORGE)
		and ResourceLoader.exists(SCRIPT_FORGE)
	)
	_connecter_signaux()
	_initialiser_combat()


func _connecter_signaux() -> void:
	if not combat_manager.combat_demarre.is_connected(_on_combat_demarre):
		combat_manager.combat_demarre.connect(_on_combat_demarre)
	if not combat_manager.des_lances.is_connected(_on_des_lances):
		combat_manager.des_lances.connect(_on_des_lances)
	if not combat_manager.degats_infliges.is_connected(_on_degats_infliges):
		combat_manager.degats_infliges.connect(_on_degats_infliges)
	if not combat_manager.pv_joueur_change.is_connected(_on_pv_joueur_change):
		combat_manager.pv_joueur_change.connect(_on_pv_joueur_change)
	if not combat_manager.pv_ennemi_change.is_connected(_on_pv_ennemi_change):
		combat_manager.pv_ennemi_change.connect(_on_pv_ennemi_change)
	if not combat_manager.bouclier_change.is_connected(_on_bouclier_change):
		combat_manager.bouclier_change.connect(_on_bouclier_change)
	if not combat_manager.or_gagne.is_connected(_on_or_gagne):
		combat_manager.or_gagne.connect(_on_or_gagne)
	if not combat_manager.combat_termine.is_connected(_on_combat_termine):
		combat_manager.combat_termine.connect(_on_combat_termine)
	if not bouton_lancer.pressed.is_connected(_on_bouton_lancer_pressed):
		bouton_lancer.pressed.connect(_on_bouton_lancer_pressed)
	if not bouton_forge.pressed.is_connected(_on_bouton_forge_pressed):
		bouton_forge.pressed.connect(_on_bouton_forge_pressed)


func _initialiser_combat() -> void:
	if _combat_initialise:
		return
	_combat_initialise = true
	combat_manager.demarrer_combat()

	if combat_manager.etat == CombatManager.EtatCombat.INACTIF:
		label_message.text = "Le combat n'a pas pu démarrer."


func _on_combat_demarre() -> void:
	label_message.text = "Combat commencé."
	_actualiser_actions()


func _on_bouton_lancer_pressed() -> void:
	if not combat_manager.peut_lancer():
		return
	bouton_lancer.disabled = true
	combat_manager.lancer_de_joueur()
	_actualiser_actions()


func _on_des_lances(faces: Array[De.Face]) -> void:
	var resultats: PackedStringArray = []
	for i in faces.size():
		var face: De.Face = faces[i]
		if face == null or face.donnees == null:
			resultats.append("Dé %d : face invalide" % (i + 1))
		else:
			resultats.append("Dé %d : %s" % [i + 1, face.donnees])
	label_resultat.text = "Résultats : %s" % " | ".join(resultats)


func _on_degats_infliges(cible: String, degats: int) -> void:
	if cible == "joueur":
		label_message.text = "Riposte ennemie : %d dégâts reçus." % degats
	elif cible == "ennemi":
		label_message.text = "Vous infligez %d dégâts." % degats


func _on_pv_joueur_change(pv_actuels: int, pv_max: int) -> void:
	label_pv_joueur.text = "PV joueur : %d / %d" % [pv_actuels, pv_max]


func _on_pv_ennemi_change(pv_actuels: int, pv_max: int) -> void:
	label_pv_ennemi.text = "PV ennemi : %d / %d" % [pv_actuels, pv_max]


func _on_bouclier_change(valeur: int) -> void:
	label_bouclier.text = "Bouclier : %d" % valeur


func _on_or_gagne(montant: int, total: int) -> void:
	label_or.text = "Or gagné dans la salle : +%d (cumul : %d)" % [montant, total]


func _on_combat_termine(victoire: bool) -> void:
	bouton_lancer.disabled = true
	if victoire:
		if EtatPartie.phase == EtatPartie.Phase.VICTOIRE_FINALE:
			_ouvrir_ecran_fin("res://Scenes/Victory.tscn")
		else:
			label_message.text = (
				"Victoire ! Récompenses : +%d or et +%d éclats. "
				+ "Totaux : %d or, %d éclats."
			) % [
				combat_manager.ennemi.recompense_or,
				combat_manager.ennemi.recompense_eclats,
				EtatPartie.or_total,
				EtatPartie.eclats,
			]
			bouton_forge.disabled = not _forge_disponible
			if not _forge_disponible:
				label_message.text += " Forge indisponible : Scripts/ForgeScreen.gd est absent."
	else:
		if EtatPartie.phase == EtatPartie.Phase.GAME_OVER:
			_ouvrir_ecran_fin("res://Scenes/GameOver.tscn")
		else:
			label_message.text = "La défaite n'a pas été enregistrée dans l'état de la partie."
		bouton_forge.disabled = true
	_actualiser_actions()


func _ouvrir_ecran_fin(chemin: String) -> void:
	var erreur: Error = get_tree().change_scene_to_file(chemin)
	if erreur != OK:
		push_error("Impossible d'ouvrir l'écran de fin %s : %s" % [
			chemin,
			error_string(erreur),
		])
		label_message.text = "La partie est terminée, mais l'écran de fin n'a pas pu s'ouvrir."


func _on_bouton_forge_pressed() -> void:
	if (
		combat_manager.etat != CombatManager.EtatCombat.VICTOIRE
		or EtatPartie.phase != EtatPartie.Phase.FORGE
	):
		return
	if not _forge_disponible:
		bouton_forge.disabled = true
		label_message.text = "Forge indisponible : Scripts/ForgeScreen.gd est absent."
		return
	EtatPartie.aller_a_forge()


func _actualiser_actions() -> void:
	bouton_lancer.disabled = not combat_manager.peut_lancer()
	bouton_forge.disabled = (
		combat_manager.etat != CombatManager.EtatCombat.VICTOIRE
		or EtatPartie.phase != EtatPartie.Phase.FORGE
		or not _forge_disponible
	)
