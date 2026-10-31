extends Node

var _reussites: int = 0
var _echecs: int = 0


func _ready() -> void:
	call_deferred("_executer_tests")


func _executer_tests() -> void:
	await _tester_chargement_et_phases()
	await _tester_parcours_victoire_et_redemarrage()
	await _tester_parcours_defaite_et_redemarrage()

	if _echecs == 0:
		print("Tous les tests des écrans de fin sont passés (%d assertions)." % _reussites)
		get_tree().quit(0)
	else:
		push_error("%d test(s) des écrans de fin en échec sur %d assertions." % [
			_echecs,
			_reussites + _echecs,
		])
		get_tree().quit(1)


func _verifier(condition: bool, description: String) -> void:
	if condition:
		_reussites += 1
		print("[OK] %s" % description)
	else:
		_echecs += 1
		push_error("[ÉCHEC] %s" % description)


func _charger_scene(chemin: String) -> PackedScene:
	var scene := load(chemin) as PackedScene
	_verifier(scene != null, "%s se charge" % chemin)
	return scene


func _tester_chargement_et_phases() -> void:
	var victoire_scene := _charger_scene("res://Scenes/Victory.tscn")
	var defaite_scene := _charger_scene("res://Scenes/GameOver.tscn")
	if victoire_scene == null or defaite_scene == null:
		return

	EtatPartie.reinitialiser()
	var victoire := victoire_scene.instantiate() as Control
	var defaite := defaite_scene.instantiate() as Control
	add_child(victoire)
	add_child(defaite)
	_verifier(
		victoire.get_node("CenterContainer/Panel/Marge/VBox/Titre").text
			== "Écran indisponible"
		and victoire.get_node("CenterContainer/Panel/Marge/VBox/NouvellePartie").disabled,
		"L'écran de victoire refuse de s'afficher hors de VICTOIRE_FINALE"
	)
	_verifier(
		defaite.get_node("CenterContainer/Panel/Marge/VBox/Titre").text
			== "Écran indisponible"
		and defaite.get_node("CenterContainer/Panel/Marge/VBox/NouvellePartie").disabled,
		"L'écran de défaite refuse de s'afficher hors de GAME_OVER"
	)
	victoire.queue_free()
	defaite.queue_free()
	await get_tree().process_frame


func _preparer_runner_persistant() -> void:
	var arbre := get_tree()
	if arbre.current_scene == self:
		arbre.root.remove_child(self)
		arbre.root.add_child(self)


func _demarrer_combat() -> Control:
	var scene := load("res://Scenes/Combat.tscn") as PackedScene
	if scene == null:
		_verifier(false, "La scène Combat se charge pour les tests de transition")
		return null
	var combat := scene.instantiate() as Control
	get_tree().root.add_child(combat)
	get_tree().current_scene = combat
	await get_tree().process_frame
	return combat


func _bouton_combat(combat: Control, nom: String) -> Button:
	return combat.get_node("CenterContainer/VBoxContainer/" + nom) as Button


func _etat_combat(combat: Control) -> CombatManager:
	return combat.get_node("CombatManager") as CombatManager


func _affecter_faces_neutres(combat: Control) -> void:
	EtatPartie.des_joueur[0] = De.depuis_faces_data([FaceData.new()])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])


func _tester_parcours_victoire_et_redemarrage() -> void:
	_preparer_runner_persistant()
	EtatPartie.etages_max = 10
	EtatPartie.boss_final_actif = true
	EtatPartie.reinitialiser()
	EtatPartie.phase = EtatPartie.Phase.COMBAT
	var combat_normal := await _demarrer_combat()
	if combat_normal == null:
		return
	var manager_normal := _etat_combat(combat_normal)
	manager_normal.pv_ennemi = 1
	EtatPartie.des_joueur[0] = De.depuis_faces_data([_face_attaque(2)])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])
	_bouton_combat(combat_normal, "BoutonLancer").emit_signal("pressed")
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.FORGE
		and get_tree().current_scene == combat_normal,
		"Une victoire non finale ne lance pas l'écran de fin"
	)

	EtatPartie.etages_max = 1
	EtatPartie.nouvelle_partie()
	await get_tree().process_frame
	var combat_final := get_tree().current_scene as Control
	if combat_final == null or combat_final.name != "Combat":
		_verifier(false, "La nouvelle partie démarre avant le test de victoire finale")
		return
	var manager_final := _etat_combat(combat_final)
	manager_final.pv_ennemi = 1
	EtatPartie.des_joueur[0] = De.depuis_faces_data([_face_attaque(2)])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])
	_bouton_combat(combat_final, "BoutonLancer").emit_signal("pressed")
	await get_tree().process_frame

	var ecran_victoire := get_tree().current_scene as Control
	_verifier(
		ecran_victoire != null
		and ecran_victoire.name == "Victory"
		and EtatPartie.phase == EtatPartie.Phase.VICTOIRE_FINALE,
		"La victoire finale ouvre l'écran de victoire"
	)
	if ecran_victoire == null or ecran_victoire.name != "Victory":
		return

	var vbox: Node = ecran_victoire.get_node("CenterContainer/Panel/Marge/VBox")
	_verifier(
		vbox.get_node("Titre").text == "Victoire !"
		and vbox.get_node("Message").text.contains("boss final"),
		"L'écran de victoire affiche son titre et les félicitations"
	)
	var bouton_titre: Button = vbox.get_node("RetourTitre")
	_verifier(
		bouton_titre.text == "Retour au titre"
		and not bouton_titre.disabled
		and EtatPartie.titre_disponible(),
		"Le retour au titre est activé car la scène existe"
	)
	EtatPartie.fixer_pv_joueur(7)
	EtatPartie.or_total = 24
	EtatPartie.eclats = 3
	bouton_titre.emit_signal("pressed")
	await get_tree().process_frame
	_verifier(
		get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path == "res://Scenes/Title.tscn"
		and EtatPartie.phase == EtatPartie.Phase.TITRE
		and EtatPartie.pv_joueur == 7
		and EtatPartie.or_total == 24
		and EtatPartie.eclats == 3,
		"Le retour depuis la victoire ouvre le titre sans réinitialiser l'état"
	)

	EtatPartie.phase = EtatPartie.Phase.VICTOIRE_FINALE
	var scene_victoire := load("res://Scenes/Victory.tscn") as PackedScene
	var victoire_rechargee := scene_victoire.instantiate() as Control
	get_tree().root.add_child(victoire_rechargee)
	get_tree().current_scene = victoire_rechargee
	await get_tree().process_frame
	var vbox_recharge: Node = victoire_rechargee.get_node("CenterContainer/Panel/Marge/VBox")
	EtatPartie.des_joueur[1].remplacer_face(0, De.Face.depuis_donnees(_face_attaque(9)))
	EtatPartie.stock["atk3"] = 0
	EtatPartie.fixer_pv_joueur(3)
	EtatPartie.or_total = 99
	EtatPartie.eclats = 8
	EtatPartie.etages_max = 10
	vbox_recharge.get_node("NouvellePartie").emit_signal("pressed")
	await get_tree().process_frame
	var combat_reinitialise := get_tree().current_scene as Control
	_verifier(
		combat_reinitialise != null
		and combat_reinitialise.name == "Combat"
		and _etat_initial(combat_reinitialise),
		"Nouvelle partie depuis la victoire restaure dés, ressources, PV, étage et stock"
	)


func _tester_parcours_defaite_et_redemarrage() -> void:
	var combat := get_tree().current_scene as Control
	if combat == null or combat.name != "Combat":
		_verifier(false, "Le combat est prêt pour le test de défaite")
		return
	var manager := _etat_combat(combat)
	manager.ennemi.degats_riposte = 20
	EtatPartie.fixer_pv_joueur(1)
	_affecter_faces_neutres(combat)
	_bouton_combat(combat, "BoutonLancer").emit_signal("pressed")
	await get_tree().process_frame

	var ecran_defaite := get_tree().current_scene as Control
	_verifier(
		ecran_defaite != null
		and ecran_defaite.name == "GameOver"
		and EtatPartie.phase == EtatPartie.Phase.GAME_OVER,
		"Une défaite ouvre l'écran Game Over uniquement en phase GAME_OVER"
	)
	if ecran_defaite == null or ecran_defaite.name != "GameOver":
		return

	var vbox: Node = ecran_defaite.get_node("CenterContainer/Panel/Marge/VBox")
	_verifier(
		vbox.get_node("Titre").text == "Partie terminée"
		and vbox.get_node("Message").text.contains("PV"),
		"L'écran de défaite affiche un titre et un message explicites"
	)
	var bouton_titre: Button = vbox.get_node("RetourTitre")
	_verifier(
		bouton_titre.text == "Retour au titre"
		and not bouton_titre.disabled
		and EtatPartie.titre_disponible(),
		"Le retour au titre est activé depuis l'écran de défaite"
	)
	EtatPartie.fixer_pv_joueur(2)
	EtatPartie.or_total = 31
	EtatPartie.eclats = 4
	bouton_titre.emit_signal("pressed")
	await get_tree().process_frame
	_verifier(
		get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path == "res://Scenes/Title.tscn"
		and EtatPartie.phase == EtatPartie.Phase.TITRE
		and EtatPartie.pv_joueur == 2
		and EtatPartie.or_total == 31
		and EtatPartie.eclats == 4,
		"Le retour depuis la défaite ouvre le titre sans réinitialiser l'état"
	)

	EtatPartie.phase = EtatPartie.Phase.GAME_OVER
	var scene_defaite := load("res://Scenes/GameOver.tscn") as PackedScene
	var defaite_rechargee := scene_defaite.instantiate() as Control
	get_tree().root.add_child(defaite_rechargee)
	get_tree().current_scene = defaite_rechargee
	await get_tree().process_frame
	var vbox_recharge: Node = defaite_rechargee.get_node("CenterContainer/Panel/Marge/VBox")
	EtatPartie.des_joueur[0].remplacer_face(0, De.Face.depuis_donnees(_face_attaque(8)))
	EtatPartie.stock["atk3"] = 0
	EtatPartie.fixer_pv_joueur(1)
	EtatPartie.or_total = 77
	EtatPartie.eclats = 6
	vbox_recharge.get_node("NouvellePartie").emit_signal("pressed")
	await get_tree().process_frame
	var combat_reinitialise := get_tree().current_scene as Control
	_verifier(
		combat_reinitialise != null
		and combat_reinitialise.name == "Combat"
		and _etat_initial(combat_reinitialise),
		"Nouvelle partie depuis la défaite efface les améliorations et restaure le stock"
	)


func _face_attaque(valeur: int) -> FaceData:
	var face := FaceData.new()
	face.attaque = valeur
	return face


func _etat_initial(combat: Control) -> bool:
	if (
		EtatPartie.phase != EtatPartie.Phase.COMBAT
		or EtatPartie.etage != 1
		or EtatPartie.pv_joueur != 15
		or EtatPartie.pv_max_joueur != 15
		or EtatPartie.or_total != 12
		or EtatPartie.eclats != 0
		or EtatPartie.des_joueur.size() != 2
		or EtatPartie.ennemi_actuel == null
		or EtatPartie.ennemi_actuel.est_boss
	):
		return false

	for de in EtatPartie.des_joueur:
		if de.faces.size() != 6:
			return false
		for index in de.faces.size():
			var donnees: FaceData = de.faces[index].donnees
			if donnees.special != FaceData.Special.AUCUN:
				return false
			match index:
				0, 1:
					if donnees.attaque != 2:
						return false
				2, 3:
					if donnees.defense != 2:
						return false
				4, 5:
					if donnees.or_gain != 1:
						return false

	var catalogue := EtatPartie.catalogue_forge()
	if catalogue == null or EtatPartie.stock.size() != catalogue.offres.size():
		return false
	for offre in catalogue.offres:
		if EtatPartie.stock_de(offre) != offre.stock_max:
			return false
	var manager := _etat_combat(combat)
	return (
		manager.etat == CombatManager.EtatCombat.TOUR_JOUEUR
		and manager.ennemi == EtatPartie.ennemi_actuel
		and manager.pv_ennemi == manager.ennemi.pv_max
		and manager.or_accumule == 0
		and manager.poison_ennemi == 0
	)
