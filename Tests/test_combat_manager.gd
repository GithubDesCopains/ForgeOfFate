extends Node

var _echecs: int = 0


func _ready() -> void:
	call_deferred("_executer_tests")


func _executer_tests() -> void:
	_tester_effets_de_base()
	_tester_effets_combines_et_speciaux()
	_tester_lancer_des_deux_des()
	_tester_mort_ennemi_premier_de_et_or_deuxieme()
	_tester_mort_ennemi_premier_de_et_soin_deuxieme()
	_tester_mort_ennemi_premier_de_et_defense_deuxieme()
	_tester_attaque_et_or_deuxieme_apres_mort_ennemi()
	_tester_riposte_apres_resolution_de_deux_non_lethaux()
	_tester_recompenses_une_seule_fois_apres_deux_des()
	_tester_ripostes()
	_tester_victoire_defaite_et_gardes()
	_tester_victoire_finale()

	if _echecs == 0:
		print("Tous les tests du moteur de combat sont passés.")
		get_tree().quit(0)
	else:
		push_error("%d test(s) du moteur de combat en échec." % _echecs)
		get_tree().quit(1)


func _verifier(condition: bool, description: String) -> void:
	if condition:
		print("[OK] %s" % description)
	else:
		_echecs += 1
		push_error("[ÉCHEC] %s" % description)


func _creer_ennemi(
		pv: int = 20,
		degats: int = 0,
		recompense_or: int = 0,
		recompense_eclats: int = 0
) -> Ennemi:
	var ennemi := Ennemi.new()
	ennemi.nom = "Ennemi de test"
	ennemi.pv_max = pv
	ennemi.degats_riposte = degats
	ennemi.recompense_or = recompense_or
	ennemi.recompense_eclats = recompense_eclats
	return ennemi


func _creer_face(
		attaque: int = 0,
		defense: int = 0,
		or_gain: int = 0,
		soin: int = 0,
		special: FaceData.Special = FaceData.Special.AUCUN
) -> FaceData:
	var face := FaceData.new()
	face.attaque = attaque
	face.defense = defense
	face.or_gain = or_gain
	face.soin = soin
	face.special = special
	return face


func _demarrer(
		ennemi: Ennemi,
		faces: Array[FaceData]
) -> CombatManager:
	EtatPartie.reinitialiser()
	EtatPartie.des_joueur[0] = De.depuis_faces_data(faces)
	var face_neutre := FaceData.new()
	EtatPartie.des_joueur[1] = De.depuis_faces_data([face_neutre])
	var combat := CombatManager.new()
	combat.ennemi = ennemi
	add_child(combat)
	combat.rng.seed = 12345
	combat.demarrer_combat()
	_verifier(
		combat.etat == CombatManager.EtatCombat.TOUR_JOUEUR,
		"Le combat de test démarre"
	)
	return combat


func _tester_effets_de_base() -> void:
	var attaque := _demarrer(_creer_ennemi(), [_creer_face(3)])
	attaque.lancer_de_joueur()
	_verifier(attaque.pv_ennemi == 17, "Une face d'attaque inflige ses dégâts")
	attaque.queue_free()

	var defense := _demarrer(_creer_ennemi(), [_creer_face(0, 4)])
	defense.lancer_de_joueur()
	_verifier(EtatPartie.bouclier_joueur == 4, "Une face de défense ajoute le bouclier")
	defense.queue_free()

	var or_avant: int = EtatPartie.OR_DE_DEPART
	var or_face := _demarrer(_creer_ennemi(), [_creer_face(0, 0, 3)])
	or_face.lancer_de_joueur()
	_verifier(
		or_face.or_accumule == 3 and EtatPartie.or_total == or_avant,
		"L'or de salle est accumulé sans être versé prématurément"
	)
	or_face.queue_free()

	var soin := _demarrer(_creer_ennemi(), [_creer_face(0, 0, 0, 4)])
	EtatPartie.fixer_pv_joueur(8)
	soin.lancer_de_joueur()
	_verifier(EtatPartie.pv_joueur == 12, "Une face de soin soigne les PV persistants")
	soin.queue_free()


func _tester_effets_combines_et_speciaux() -> void:
	var combinee := _demarrer(
		_creer_ennemi(),
		[_creer_face(2, 3, 2, 4)]
	)
	EtatPartie.fixer_pv_joueur(10)
	combinee.lancer_de_joueur()
	_verifier(
		combinee.pv_ennemi == 18
		and EtatPartie.bouclier_joueur == 3
		and combinee.or_accumule == 2
		and EtatPartie.pv_joueur == 14,
		"Une face combinée applique attaque, défense, or et soin au même lancer"
	)
	combinee.queue_free()

	var double := _demarrer(
		_creer_ennemi(),
		[_creer_face(2, 0, 0, 0, FaceData.Special.DEGATS_DOUBLES_SI_BOUCLIER)]
	)
	EtatPartie.ajouter_bouclier(1)
	double.lancer_de_joueur()
	_verifier(
		double.pv_ennemi == 16,
		"Le spécial de dégâts doubles utilise le bouclier existant"
	)
	double.queue_free()

	var 	chaine := _demarrer(
		_creer_ennemi(),
		[_creer_face(0, 0, 1)]
	)
	EtatPartie.des_joueur[1] = De.depuis_faces_data([
		_creer_face(0, 0, 2, 0, FaceData.Special.OR_SI_PRECEDENT_OR)
	])
	chaine.lancer_de_joueur()
	_verifier(
		chaine.or_accumule == 5,
		"Les effets des deux dés s'appliquent dans l'ordre et le spécial de chaîne fonctionne"
	)
	chaine.queue_free()

	var poison := _demarrer(
		_creer_ennemi(),
		[_creer_face(1, 0, 0, 0, FaceData.Special.POISON)]
	)
	poison.lancer_de_joueur()
	_verifier(
		poison.pv_ennemi == 18 and poison.poison_ennemi == 0,
		"Le poison inflige ses dégâts lors de la riposte puis perd une charge"
	)
	poison.queue_free()

	var relance := _demarrer(
		_creer_ennemi(20, 4),
		[_creer_face(0, 0, 1, 0, FaceData.Special.RELANCER)]
	)
	relance.lancer_de_joueur()
	_verifier(
		relance.etat == CombatManager.EtatCombat.TOUR_JOUEUR
		and EtatPartie.pv_joueur == EtatPartie.pv_max_joueur
		and relance.or_accumule == 1,
		"Le spécial Relancer applique l'or et saute la riposte"
	)
	relance.queue_free()


func _tester_lancer_des_deux_des() -> void:
	var combat := _demarrer(
		_creer_ennemi(),
		[_creer_face(2, 1, 0, 1)]
	)
	EtatPartie.des_joueur[1] = De.depuis_faces_data([
		_creer_face(3, 2, 0, 0)
	])
	combat.lancer_de_joueur()
	_verifier(
		combat.pv_ennemi == 15
		and EtatPartie.bouclier_joueur == 3
		and EtatPartie.pv_joueur == EtatPartie.pv_max_joueur
		and EtatPartie.des_joueur.size() == 2,
		"Les deux dés persistants sont lancés et leurs effets sont appliqués"
	)
	combat.queue_free()


func _definir_faces_second_de(combat: CombatManager, faces: Array[FaceData]) -> void:
	EtatPartie.des_joueur[1] = De.depuis_faces_data(faces)


func _tester_mort_ennemi_premier_de_et_or_deuxieme() -> void:
	var ennemi := _creer_ennemi(3, 5, 4, 2)
	var combat := _demarrer(ennemi, [_creer_face(5)])
	_definir_faces_second_de(combat, [_creer_face(0, 0, 3)])
	var victoires: Array[bool] = []
	combat.combat_termine.connect(func(victoire: bool) -> void: victoires.append(victoire))

	combat.lancer_de_joueur()

	_verifier(
		combat.pv_ennemi == 0 and combat.etat == CombatManager.EtatCombat.VICTOIRE,
		"Test A : le premier dé élimine l'ennemi et le combat gagne"
	)
	_verifier(
		combat.or_accumule == 3 and EtatPartie.or_total == EtatPartie.OR_DE_DEPART + 7,
		"Test A : l'or du second dé et la récompense d'ennemi sont crédités"
	)
	_verifier(
		victoires == [true] and EtatPartie.pv_joueur == EtatPartie.PV_MAX_JOUEUR,
		"Test A : une seule victoire est signalée et l'ennemi ne riposte pas"
	)
	combat.queue_free()


func _tester_mort_ennemi_premier_de_et_soin_deuxieme() -> void:
	var combat := _demarrer(_creer_ennemi(3, 5), [_creer_face(5)])
	_definir_faces_second_de(combat, [_creer_face(0, 0, 0, 4)])
	EtatPartie.fixer_pv_joueur(8)
	var pv_a_la_victoire: Array[int] = []
	combat.combat_termine.connect(
		func(_victoire: bool) -> void: pv_a_la_victoire.append(EtatPartie.pv_joueur)
	)

	combat.lancer_de_joueur()

	_verifier(
		EtatPartie.pv_joueur == 12,
		"Test B : le soin du second dé est appliqué après le coup mortel"
	)
	_verifier(
		pv_a_la_victoire == [12] and combat.etat == CombatManager.EtatCombat.VICTOIRE,
		"Test B : la victoire est signalée après le soin du second dé"
	)
	combat.queue_free()


func _tester_mort_ennemi_premier_de_et_defense_deuxieme() -> void:
	var combat := _demarrer(_creer_ennemi(3, 5), [_creer_face(5)])
	_definir_faces_second_de(combat, [_creer_face(0, 4)])
	var degats_joueur: Array[int] = []
	combat.degats_infliges.connect(
		func(cible: String, degats: int) -> void:
			if cible == "joueur":
				degats_joueur.append(degats)
	)

	combat.lancer_de_joueur()

	_verifier(
		EtatPartie.bouclier_joueur == 4,
		"Test C : le bouclier du second dé est appliqué"
	)
	_verifier(
		degats_joueur.is_empty() and EtatPartie.pv_joueur == EtatPartie.PV_MAX_JOUEUR,
		"Test C : l'ennemi éliminé ne riposte pas"
	)
	combat.queue_free()


func _tester_attaque_et_or_deuxieme_apres_mort_ennemi() -> void:
	var combat := _demarrer(_creer_ennemi(3, 0), [_creer_face(5)])
	_definir_faces_second_de(combat, [_creer_face(7, 0, 2)])
	var attaques_ennemi: Array[int] = []
	combat.degats_infliges.connect(
		func(cible: String, degats: int) -> void:
			if cible == "ennemi":
				attaques_ennemi.append(degats)
	)

	combat.lancer_de_joueur()

	_verifier(
		attaques_ennemi == [5] and combat.pv_ennemi == 0,
		"Test D : les dégâts du second dé sont ignorés après la mort de l'ennemi"
	)
	_verifier(
		combat.or_accumule == 2 and EtatPartie.or_total == EtatPartie.OR_DE_DEPART + 2,
		"Test D : l'or combiné à l'attaque du second dé est attribué"
	)
	combat.queue_free()


func _tester_riposte_apres_resolution_de_deux_non_lethaux() -> void:
	var combat := _demarrer(_creer_ennemi(20, 4), [_creer_face(2)])
	_definir_faces_second_de(combat, [_creer_face(3)])
	var degats: Array[String] = []
	combat.degats_infliges.connect(
		func(cible: String, montant: int) -> void:
			degats.append("%s:%d" % [cible, montant])
	)

	combat.lancer_de_joueur()

	_verifier(
		combat.pv_ennemi == 15 and degats.size() == 3
		and degats[0] == "ennemi:2" and degats[1] == "ennemi:3",
		"Test E : les attaques des deux dés sont résolues dans l'ordre"
	)
	_verifier(
		degats[2] == "joueur:4"
		and EtatPartie.pv_joueur == EtatPartie.PV_MAX_JOUEUR - 4,
		"Test E : l'ennemi vivant riposte après les deux dés"
	)
	combat.queue_free()


func _tester_recompenses_une_seule_fois_apres_deux_des() -> void:
	var ennemi := _creer_ennemi(1, 0, 6, 3)
	var combat := _demarrer(ennemi, [_creer_face(2, 0, 1)])
	_definir_faces_second_de(combat, [_creer_face(0, 0, 2)])
	var victoires: Array[bool] = []
	combat.combat_termine.connect(func(victoire: bool) -> void: victoires.append(victoire))

	combat.lancer_de_joueur()
	var or_apres_victoire: int = EtatPartie.or_total
	var eclats_apres_victoire: int = EtatPartie.eclats
	var salles_apres_victoire: int = EtatPartie.salles_gagnees
	combat._terminer_combat(true)
	combat.lancer_de_joueur()

	_verifier(
		or_apres_victoire == EtatPartie.OR_DE_DEPART + 9
		and eclats_apres_victoire == 3
		and salles_apres_victoire == 1,
		"Test F : les récompenses comprennent l'or des deux dés et une récompense d'ennemi"
	)
	_verifier(
		EtatPartie.or_total == or_apres_victoire
		and EtatPartie.eclats == eclats_apres_victoire
		and EtatPartie.salles_gagnees == salles_apres_victoire
		and victoires == [true],
		"Test F : un appel de victoire répété ne crédite rien une seconde fois"
	)
	combat.queue_free()


func _tester_ripostes() -> void:
	var ennemi := load("res://Data/Ennemis/bandit.tres") as Ennemi
	var combat := _demarrer(ennemi, [_creer_face(1)])
	combat.etat = CombatManager.EtatCombat.RIPOSTE_ENNEMI
	var rng_attendu := RandomNumberGenerator.new()
	rng_attendu.seed = 9876
	var riposte_attendue: Dictionary = ennemi.lancer_riposte(rng_attendu)
	combat.rng.seed = 9876
	combat._riposte_ennemi()
	_verifier(
		EtatPartie.pv_joueur == EtatPartie.PV_MAX_JOUEUR - int(riposte_attendue["degats"]),
		"La riposte utilise les dégâts d'une face du Bandit"
	)
	combat.queue_free()

	var bouclier := _demarrer(
		_creer_ennemi(20, 5),
		[_creer_face()]
	)
	EtatPartie.ajouter_bouclier(3)
	bouclier.etat = CombatManager.EtatCombat.RIPOSTE_ENNEMI
	bouclier._riposte_ennemi()
	_verifier(
		EtatPartie.bouclier_joueur == 0 and EtatPartie.pv_joueur == 13,
		"Le bouclier absorbe trois dégâts sur la riposte de cinq"
	)
	bouclier.queue_free()


func _tester_victoire_defaite_et_gardes() -> void:
	var or_avant: int = EtatPartie.OR_DE_DEPART
	var ennemi_ressource := load("res://Data/Ennemis/gobelin.tres") as Ennemi
	var ennemi_victoire := ennemi_ressource.duplicate(true) as Ennemi
	ennemi_victoire.pv_max = 1
	var victoire := _demarrer(
		ennemi_victoire,
		[_creer_face(1, 0, 3)]
	)
	var fins: Array[bool] = []
	victoire.combat_termine.connect(func(gagne: bool) -> void: fins.append(gagne))
	victoire.lancer_de_joueur()
	var or_apres: int = EtatPartie.or_total
	var eclats_apres: int = EtatPartie.eclats
	victoire._terminer_combat(true)
	victoire.lancer_de_joueur()
	_verifier(
		victoire.etat == CombatManager.EtatCombat.VICTOIRE
		and or_apres == or_avant + 3 + victoire.ennemi.recompense_or
		and eclats_apres == victoire.ennemi.recompense_eclats,
		"La victoire verse l'or de salle et les récompenses définies dans l'ennemi"
	)
	_verifier(
		fins.size() == 1
		and EtatPartie.or_total == or_apres
		and EtatPartie.eclats == eclats_apres,
		"Une fin de combat répétée ne double pas effets ni récompenses"
	)
	victoire.queue_free()

	var defaite := _demarrer(
		_creer_ennemi(20, 20),
		[_creer_face(0, 0, 1)]
	)
	EtatPartie.fixer_pv_joueur(1)
	defaite.lancer_de_joueur()
	var or_apres_defaite: int = EtatPartie.or_total
	defaite.lancer_de_joueur()
	_verifier(
		defaite.etat == CombatManager.EtatCombat.DEFAITE
		and EtatPartie.phase == EtatPartie.Phase.GAME_OVER
		and EtatPartie.pv_joueur == 0,
		"La riposte peut terminer la partie sans rendre les PV négatifs"
	)
	_verifier(
		EtatPartie.or_total == or_apres_defaite
		and defaite.or_accumule == 1
		and not defaite.peut_lancer(),
		"La défaite bloque les actions et ne verse pas l'or de salle"
	)
	defaite.queue_free()

	var double_application := _demarrer(
		_creer_ennemi(),
		[_creer_face(0, 0, 2)]
	)
	double_application.or_gagne.connect(
		func(_montant: int, _total: int) -> void:
			double_application.lancer_de_joueur()
	)
	double_application.lancer_de_joueur()
	_verifier(
		double_application.or_accumule == 2,
		"Un signal réentrant ne permet pas d'appliquer deux fois une face"
	)
	double_application.queue_free()


func _tester_victoire_finale() -> void:
	var boss := _creer_ennemi(1, 0, 4, 2)
	boss.est_boss = true
	var combat := _demarrer(boss, [_creer_face(2)])
	EtatPartie.etage = EtatPartie.etages_max
	var or_initial: int = EtatPartie.or_total
	var eclats_initiaux: int = EtatPartie.eclats

	combat.lancer_de_joueur()
	var or_apres_victoire: int = EtatPartie.or_total
	var eclats_apres_victoire: int = EtatPartie.eclats
	combat.lancer_de_joueur()
	EtatPartie.terminer_combat_victoire(0, 15, 0, 4, 2, true)

	_verifier(
		EtatPartie.phase == EtatPartie.Phase.VICTOIRE_FINALE
		and combat.etat == CombatManager.EtatCombat.VICTOIRE,
		"Le moteur enregistre la victoire finale contre le boss de l'étage maximal"
	)
	_verifier(
		or_apres_victoire == or_initial + 4
		and eclats_apres_victoire == eclats_initiaux + 2
		and EtatPartie.or_total == or_apres_victoire
		and EtatPartie.eclats == eclats_apres_victoire,
		"Le moteur ne crédite les récompenses finales qu'une seule fois"
	)
	_verifier(
		not combat.peut_lancer()
		and not EtatPartie.commencer_combat()
		and not EtatPartie.preparer_forge()
		and EtatPartie.etage == EtatPartie.etages_max,
		"La victoire finale bloque les lancers, la Forge et toute progression"
	)
	combat.queue_free()
