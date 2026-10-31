extends Node

var _echecs: int = 0


func _ready() -> void:
	call_deferred("_executer_tests")


func _executer_tests() -> void:
	_tester_pv_et_bouclier()
	_tester_ressources()
	_tester_recompenses_sans_doublon()
	await _tester_persistance_changement_scene()

	if _echecs == 0:
		print("Tous les tests de l'état global sont passés.")
		get_tree().quit(0)
	else:
		push_error("%d test(s) de l'état global en échec." % _echecs)
		get_tree().quit(1)


func _verifier(condition: bool, description: String) -> void:
	if condition:
		print("[OK] %s" % description)
	else:
		_echecs += 1
		push_error("[ÉCHEC] %s" % description)


func _tester_pv_et_bouclier() -> void:
	EtatPartie.reinitialiser()
	var combat := CombatManager.new()
	combat.demarrer_combat()
	_verifier(
		combat.pv_joueur == EtatPartie.pv_joueur and combat.pv_joueur == 15,
		"Le combat lit les PV persistants sans les réinitialiser"
	)

	EtatPartie.fixer_pv_joueur(10)
	combat.etat = CombatManager.EtatCombat.RIPOSTE_ENNEMI
	combat._riposte_ennemi()
	_verifier(EtatPartie.pv_joueur == 9, "La riposte réduit les PV selon les données du Gobelin")

	EtatPartie.soigner_joueur(4)
	_verifier(EtatPartie.pv_joueur == 13, "Le soin augmente les PV")
	EtatPartie.soigner_joueur(100)
	_verifier(
		EtatPartie.pv_joueur == EtatPartie.pv_max_joueur,
		"Le soin ne dépasse pas les PV maximum"
	)

	EtatPartie.ajouter_bouclier(3)
	var bouclier_absorbe: int = EtatPartie.absorber_bouclier(2)
	_verifier(
		bouclier_absorbe == 2 and EtatPartie.bouclier_joueur == 1,
		"Le bouclier s'ajoute puis absorbe les dégâts demandés"
	)
	combat.demarrer_combat()
	_verifier(
		EtatPartie.bouclier_joueur == 1,
		"Un démarrage répété du même combat ne remet pas le bouclier à zéro"
	)
	combat.bouclier_joueur = 3
	combat.etat = CombatManager.EtatCombat.RIPOSTE_ENNEMI
	combat._riposte_ennemi()
	_verifier(
		EtatPartie.bouclier_joueur == 2 and EtatPartie.pv_joueur == EtatPartie.pv_max_joueur,
		"Le combat consomme le bouclier global avant d'infliger des dégâts"
	)
	combat.free()


func _tester_ressources() -> void:
	EtatPartie.reinitialiser()
	var or_initial: int = EtatPartie.or_total
	EtatPartie.ajouter_or(5)
	_verifier(EtatPartie.or_total == or_initial + 5, "L'or gagné est ajouté une fois")
	_verifier(EtatPartie.depenser_or(3), "La dépense d'or valide réussit")
	_verifier(
		EtatPartie.or_total == or_initial + 2,
		"La dépense d'or met à jour le total"
	)
	_verifier(not EtatPartie.depenser_or(1000), "Une dépense supérieure au solde est refusée")
	_verifier(not EtatPartie.depenser_or(-1), "Une dépense d'or négative est refusée")

	EtatPartie.ajouter_eclats(4)
	_verifier(EtatPartie.eclats == 4, "Les éclats gagnés sont ajoutés")
	_verifier(EtatPartie.depenser_eclats(2), "La dépense d'éclats valide réussit")
	_verifier(EtatPartie.eclats == 2, "La dépense d'éclats met à jour le total")
	_verifier(
		not EtatPartie.depenser_eclats(3) and EtatPartie.eclats == 2,
		"Une dépense d'éclats supérieure au solde est refusée"
	)


func _tester_recompenses_sans_doublon() -> void:
	EtatPartie.reinitialiser()
	EtatPartie.commencer_combat()
	var or_avant: int = EtatPartie.or_total
	var combat := CombatManager.new()
	combat.ennemi = preload("res://Data/Ennemis/gobelin.tres").duplicate(true) as Ennemi
	combat.etat = CombatManager.EtatCombat.TOUR_JOUEUR
	combat.pv_ennemi = 0
	combat.or_accumule = 4
	combat._terminer_combat(true)
	var or_apres_victoire: int = EtatPartie.or_total
	combat._terminer_combat(true)

	_verifier(
		or_apres_victoire == or_avant + 4 + combat.ennemi.recompense_or,
		"La victoire transfère l'or de salle et la récompense de l'ennemi une seule fois"
	)
	_verifier(
		EtatPartie.or_total == or_apres_victoire
		and EtatPartie.eclats == combat.ennemi.recompense_eclats
		and EtatPartie.salles_gagnees == 1,
		"Un second appel ne double ni l'or, ni les éclats, ni la progression"
	)
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.FORGE,
		"La victoire fait passer l'état global à la phase Forge"
	)
	combat.free()

	EtatPartie.commencer_combat()
	EtatPartie.defaite()
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.GAME_OVER
		and not EtatPartie.commencer_combat(),
		"La défaite termine la partie et empêche un nouveau combat sans réinitialisation"
	)


func _tester_persistance_changement_scene() -> void:
	EtatPartie.reinitialiser()
	EtatPartie.fixer_pv_joueur(9)
	EtatPartie.ajouter_bouclier(2)
	EtatPartie.ajouter_or(7)
	EtatPartie.ajouter_eclats(3)

	var arbre: SceneTree = get_tree()
	if arbre.current_scene == self:
		arbre.root.remove_child(self)
		arbre.root.add_child(self)

	var scene_a := _creer_scene_test("SceneA")
	var scene_b := _creer_scene_test("SceneB")
	var instance_a := scene_a.instantiate()
	arbre.root.add_child(instance_a)
	arbre.current_scene = instance_a

	var erreur: Error = arbre.change_scene_to_packed(scene_b)
	_verifier(erreur == OK, "Le remplacement de scène de test est accepté")
	await arbre.process_frame
	_verifier(
		arbre.current_scene != instance_a
		and EtatPartie.pv_joueur == 9
		and EtatPartie.bouclier_joueur == 2
		and EtatPartie.or_total == EtatPartie.OR_DE_DEPART + 7
		and EtatPartie.eclats == 3,
		"PV, bouclier, or et éclats persistent après le changement de scène"
	)


func _creer_scene_test(nom: String) -> PackedScene:
	var racine := Node.new()
	racine.name = nom
	var scene := PackedScene.new()
	var erreur: Error = scene.pack(racine)
	racine.free()
	_verifier(erreur == OK, "La scène %s est créée en mémoire" % nom)
	return scene
