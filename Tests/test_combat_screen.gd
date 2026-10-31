extends Node

var _echecs: int = 0


func _ready() -> void:
	call_deferred("_executer_tests")


func _executer_tests() -> void:
	await _tester_interface_victoire()
	await _tester_interface_defaite()
	await _tester_interface_victoire_finale()

	if _echecs == 0:
		print("Tous les tests de l'interface de combat sont passés.")
		get_tree().quit(0)
	else:
		push_error("%d test(s) de l'interface de combat en échec." % _echecs)
		get_tree().quit(1)


func _verifier(condition: bool, description: String) -> void:
	if condition:
		print("[OK] %s" % description)
	else:
		_echecs += 1
		push_error("[ÉCHEC] %s" % description)


func _creer_ecran() -> Control:
	var scene := load("res://Scenes/Combat.tscn") as PackedScene
	_verifier(scene != null, "La scène Combat se charge")
	if scene == null:
		return null
	var ecran := scene.instantiate() as Control
	_verifier(ecran != null, "L'interface de combat s'instancie")
	if ecran != null:
		get_tree().root.add_child(ecran)
		get_tree().current_scene = ecran
	_verifier(
		ecran != null
		and _manager(ecran).etat == CombatManager.EtatCombat.TOUR_JOUEUR,
		"La scène démarre le combat une seule fois"
	)
	return ecran


func _manager(ecran: Control) -> CombatManager:
	return ecran.get_node("CombatManager") as CombatManager


func _label(ecran: Control, nom: String) -> Label:
	return ecran.get_node("CenterContainer/VBoxContainer/" + nom) as Label


func _bouton(ecran: Control, nom: String) -> Button:
	return ecran.get_node("CenterContainer/VBoxContainer/" + nom) as Button


func _creer_face(
	attaque: int = 0,
	defense: int = 0,
	or_gain: int = 0,
	soin: int = 0
) -> FaceData:
	var face := FaceData.new()
	face.attaque = attaque
	face.defense = defense
	face.or_gain = or_gain
	face.soin = soin
	return face


func _tester_connexions(ecran: Control) -> void:
	ecran.call("_connecter_signaux")
	var manager := _manager(ecran)
	_verifier(
		manager.get_signal_connection_list("des_lances").size() == 1
		and manager.get_signal_connection_list("degats_infliges").size() == 1
		and manager.get_signal_connection_list("pv_joueur_change").size() == 1
		and manager.get_signal_connection_list("pv_ennemi_change").size() == 1
		and manager.get_signal_connection_list("bouclier_change").size() == 1
		and manager.get_signal_connection_list("or_gagne").size() == 1
		and manager.get_signal_connection_list("combat_termine").size() == 1,
		"Chaque signal du moteur est connecté une seule fois"
	)


func _tester_interface_victoire() -> void:
	EtatPartie.reinitialiser()
	var or_initial: int = EtatPartie.or_total
	var eclats_initiaux: int = EtatPartie.eclats
	var ecran := _creer_ecran()
	if ecran == null:
		return

	var manager := _manager(ecran)
	_tester_connexions(ecran)
	var demarrages_supplementaires: Array[bool] = []
	manager.combat_demarre.connect(
		func() -> void: demarrages_supplementaires.append(true)
	)
	ecran.call("_initialiser_combat")
	ecran.call("_initialiser_combat")
	_verifier(
		manager.etat == CombatManager.EtatCombat.TOUR_JOUEUR
		and demarrages_supplementaires.is_empty(),
		"L'initialisation répétée ne redémarre pas le combat"
	)
	_verifier(
		EtatPartie.or_total == or_initial and EtatPartie.eclats == eclats_initiaux,
		"L'initialisation de l'interface ne crédite aucune ressource"
	)
	_verifier(
		_bouton(ecran, "BoutonForge").disabled,
		"Le bouton Forge est désactivé pendant le combat"
	)

	var ennemi := manager.ennemi.duplicate(true) as Ennemi
	ennemi.degats_riposte = 0
	ennemi.recompense_or = 4
	ennemi.recompense_eclats = 3
	manager.ennemi = ennemi
	EtatPartie.fixer_pv_joueur(10)
	EtatPartie.des_joueur[0] = De.depuis_faces_data([_creer_face(2, 1, 2, 2)])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])
	_bouton(ecran, "BoutonLancer").emit_signal("pressed")

	_verifier(
		_label(ecran, "EnnemiPV").text == "PV ennemi : 8 / 10",
		"Les PV de l'ennemi sont actualisés"
	)
	_verifier(
		_label(ecran, "JoueurPV").text == "PV joueur : 12 / 15",
		"Les PV du joueur reflètent le soin de la face"
	)
	_verifier(
		_label(ecran, "Bouclier").text == "Bouclier : 1",
		"Le bouclier est affiché depuis le moteur"
	)
	_verifier(
		_label(ecran, "ResultatDe").text.contains("Dé 1")
		and _label(ecran, "ResultatDe").text.contains("Dé 2")
		and _label(ecran, "ResultatDe").text.contains("Attaque +2")
		and _label(ecran, "ResultatDe").text.contains("Défense +1")
		and _label(ecran, "ResultatDe").text.contains("Or +2")
		and _label(ecran, "ResultatDe").text.contains("Soin +2"),
		"Le résultat affiche tous les effets combinés de la face"
	)
	_verifier(
		_label(ecran, "OrSalle").text.contains("cumul : 2")
		and EtatPartie.or_total == or_initial,
		"Le gain d'or de salle s'affiche sans être versé prématurément"
	)

	ennemi.degats_riposte = 4
	EtatPartie.des_joueur[0] = De.depuis_faces_data([_creer_face(1)])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])
	_bouton(ecran, "BoutonLancer").emit_signal("pressed")
	_verifier(
		_label(ecran, "MessageCombat").text == "Riposte ennemie : 3 dégâts reçus.",
		"L'interface affiche les dégâts réels après absorption du bouclier"
	)
	_verifier(
		_label(ecran, "JoueurPV").text == "PV joueur : 9 / 15"
		and _label(ecran, "Bouclier").text == "Bouclier : 0",
		"Les PV et le bouclier sont actualisés après la riposte"
	)

	manager.pv_ennemi = 1
	EtatPartie.des_joueur[0] = De.depuis_faces_data([_creer_face(1, 0, 1)])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])
	_bouton(ecran, "BoutonLancer").emit_signal("pressed")
	_verifier(
		manager.etat == CombatManager.EtatCombat.VICTOIRE
		and _bouton(ecran, "BoutonLancer").disabled,
		"Une victoire affiche la fin du combat et bloque les lancers"
	)
	_verifier(
		_label(ecran, "MessageCombat").text.contains("Victoire !")
		and _label(ecran, "MessageCombat").text.contains("+4 or")
		and _label(ecran, "MessageCombat").text.contains("+3 éclats"),
		"Les récompenses définies par l'ennemi sont affichées"
	)
	_verifier(
		ResourceLoader.exists("res://Scripts/ForgeScreen.gd")
		and not _bouton(ecran, "BoutonForge").disabled,
		"La Forge devient accessible après une victoire"
	)
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.FORGE
		and EtatPartie.or_total == or_initial + 2 + 1 + ennemi.recompense_or
		and EtatPartie.eclats == eclats_initiaux + ennemi.recompense_eclats,
		"Les récompenses de victoire sont créditées une seule fois par le moteur"
	)

	get_tree().current_scene = self
	ecran.queue_free()
	await get_tree().process_frame


func _tester_interface_defaite() -> void:
	EtatPartie.reinitialiser()
	var ecran := _creer_ecran()
	if ecran == null:
		return
	var manager := _manager(ecran)
	var ennemi := manager.ennemi.duplicate(true) as Ennemi
	ennemi.degats_riposte = 20
	manager.ennemi = ennemi
	EtatPartie.fixer_pv_joueur(1)
	EtatPartie.des_joueur[0] = De.depuis_faces_data([_creer_face()])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])
	_bouton(ecran, "BoutonLancer").emit_signal("pressed")

	_verifier(
		manager.etat == CombatManager.EtatCombat.DEFAITE
		and _bouton(ecran, "BoutonLancer").disabled
		and _bouton(ecran, "BoutonForge").disabled,
		"La défaite bloque le lancer et ne permet pas l'accès à la Forge"
	)
	await get_tree().process_frame
	_verifier(
		get_tree().current_scene.name == "GameOver"
		and EtatPartie.phase == EtatPartie.Phase.GAME_OVER,
		"La défaite quitte le combat pour l'écran Game Over"
	)
	await get_tree().process_frame


func _tester_interface_victoire_finale() -> void:
	var etages_max_initial: int = EtatPartie.etages_max
	var boss_final_initial: bool = EtatPartie.boss_final_actif
	EtatPartie.etages_max = 1
	EtatPartie.boss_final_actif = true
	EtatPartie.reinitialiser()
	EtatPartie.ennemi_actuel.pv_max = 1
	EtatPartie.des_joueur[0] = De.depuis_faces_data([_creer_face(2)])
	EtatPartie.des_joueur[1] = De.depuis_faces_data([FaceData.new()])

	var ecran := _creer_ecran()
	if ecran == null:
		return
	var manager := _manager(ecran)
	_bouton(ecran, "BoutonLancer").emit_signal("pressed")
	await get_tree().process_frame
	var victoire := get_tree().current_scene as Control
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.VICTOIRE_FINALE
		and victoire != null
		and victoire.name == "Victory",
		"L'interface ouvre l'écran de victoire après la victoire finale"
	)
	_verifier(
		not EtatPartie.commencer_combat()
		and EtatPartie.etage == 1
		and not EtatPartie.preparer_forge(),
		"La fin bloque les lancers et toute progression supplémentaire"
	)

	EtatPartie.etages_max = etages_max_initial
	EtatPartie.boss_final_actif = boss_final_initial
	EtatPartie.reinitialiser()
	get_tree().current_scene = self
	await get_tree().process_frame
