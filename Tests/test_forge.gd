extends Node

const ForgeRules = preload("res://Scripts/Forge.gd")

var _reussites: int = 0
var _echecs: int = 0


func _ready() -> void:
	call_deferred("_executer_tests")


func _executer_tests() -> void:
	_tester_des_persistants()
	_tester_selection_offres()
	_tester_achats()
	_tester_entree_forge()
	_tester_victoire_finale_et_configuration()
	await _tester_nouvelle_partie_apres_victoire_finale()
	await _tester_persistance_scene()

	if _echecs == 0:
		print("Tous les tests des fondations de la Forge sont passés (%d assertions)." % _reussites)
		get_tree().quit(0)
	else:
		push_error("%d test(s) Forge en échec sur %d assertions." % [_echecs, _reussites + _echecs])
		get_tree().quit(1)


func _verifier(condition: bool, description: String) -> void:
	if condition:
		_reussites += 1
		print("[OK] %s" % description)
	else:
		_echecs += 1
		push_error("[ÉCHEC] %s" % description)


func _catalogue() -> CatalogueForge:
	return EtatPartie.catalogue_forge()


func _offre(id: String) -> OffreForge:
	for offre in _catalogue().offres:
		if offre.id == id:
			return offre
	return null


func _preparer_achat(offre: OffreForge, montant_or: int, eclats: int) -> void:
	EtatPartie.reinitialiser()
	EtatPartie.phase = EtatPartie.Phase.FORGE
	EtatPartie.offre_forge = [offre]
	EtatPartie.stock[offre.id] = offre.stock_max
	EtatPartie.or_total = montant_or
	EtatPartie.eclats = eclats


func _face_test(
	attaque: int,
	defense: int,
	or_gain: int,
	soin: int,
	special: FaceData.Special
) -> FaceData:
	var face := FaceData.new()
	face.attaque = attaque
	face.defense = defense
	face.or_gain = or_gain
	face.soin = soin
	face.special = special
	return face


func _tester_des_persistants() -> void:
	EtatPartie.reinitialiser()
	_verifier(
		EtatPartie.des_joueur.size() == 2
		and EtatPartie.des_joueur[0].faces.size() == 6
		and EtatPartie.des_joueur[1].faces.size() == 6,
		"Une nouvelle partie crée deux dés de six faces"
	)
	_verifier(
		EtatPartie.des_joueur[0] != EtatPartie.des_joueur[1],
		"Les dés sont deux instances indépendantes"
	)

	var face_complete := _face_test(3, 2, 4, 5, FaceData.Special.POISON)
	var nouvelle_face := De.Face.depuis_donnees(face_complete)
	_verifier(
		EtatPartie.des_joueur[0].remplacer_face(0, nouvelle_face),
		"Le premier dé accepte le remplacement d'une face"
	)
	var donnees := EtatPartie.des_joueur[0].faces[0].donnees
	_verifier(
		donnees.attaque == 3
		and donnees.defense == 2
		and donnees.or_gain == 4
		and donnees.soin == 5
		and donnees.special == FaceData.Special.POISON,
		"La face améliorée conserve tous ses effets et son effet spécial"
	)
	_verifier(
		EtatPartie.des_joueur[1].faces[0].donnees.attaque == 2
		and EtatPartie.des_joueur[1].faces[0].donnees.defense == 0,
		"L'amélioration du premier dé ne modifie pas le second"
	)
	EtatPartie.des_joueur[1].remplacer_face(
		0,
		De.Face.depuis_donnees(_face_test(7, 0, 0, 0, FaceData.Special.AUCUN))
	)
	_verifier(
		EtatPartie.des_joueur[0].faces[0].donnees.attaque == 3
		and EtatPartie.des_joueur[1].faces[0].donnees.attaque == 7,
		"Le second dé peut ensuite être amélioré indépendamment"
	)


func _tester_selection_offres() -> void:
	EtatPartie.reinitialiser()
	var catalogue := _catalogue()
	_verifier(
		catalogue != null and catalogue.offres.size() == 17,
		"Le catalogue historique contient bien ses dix-sept offres"
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var selection := ForgeRules.tirer_offre(
		catalogue,
		1,
		rng,
		EtatPartie.stock,
		EtatPartie.TAILLE_OFFRE_FORGE
	)
	_verifier(selection.size() == 6, "La boutique sélectionne au maximum six offres")
	var etage_valide: bool = true
	for offre in selection:
		if offre.etage_min > 1:
			etage_valide = false
	_verifier(etage_valide, "Les offres sont filtrées selon l'étage minimum")

	var stock_epuise: Dictionary = {}
	for offre in catalogue.offres:
		stock_epuise[offre.id] = 0
	stock_epuise["atk3"] = 1
	rng.seed = 123
	var selection_stock := ForgeRules.tirer_offre(catalogue, 10, rng, stock_epuise, 6)
	_verifier(
		selection_stock.size() == 1 and selection_stock[0].id == "atk3",
		"Les offres épuisées sont exclues de la sélection"
	)

	var offre_avant := _offre("atk3")
	EtatPartie.stock[offre_avant.id] = 0
	EtatPartie.regenerer_offre()
	_verifier(
		EtatPartie.stock_de(offre_avant) == 0,
		"Le stock reste épuisé lors du renouvellement de la sélection"
	)


func _tester_achats() -> void:
	var offre_or := _offre("atk3")
	_preparer_achat(offre_or, 10, 0)
	_verifier(
		EtatPartie.acheter_offre(0, 0, offre_or)
		and EtatPartie.or_total == 6
		and EtatPartie.eclats == 0,
		"Un achat payé uniquement en or réussit"
	)

	var offre_eclats := OffreForge.new()
	offre_eclats.id = "test_eclats"
	offre_eclats.face = _face_test(0, 3, 0, 0, FaceData.Special.AUCUN)
	offre_eclats.cout_eclats = 2
	offre_eclats.stock_max = 1
	_preparer_achat(offre_eclats, 0, 3)
	_verifier(
		EtatPartie.acheter_offre(1, 0, offre_eclats)
		and EtatPartie.eclats == 1
		and EtatPartie.or_total == 0,
		"Un achat payé uniquement en éclats réussit et cible le second dé"
	)

	var offre_mixte := _offre("garde")
	_preparer_achat(offre_mixte, 10, 2)
	_verifier(
		EtatPartie.acheter_offre(0, 1, offre_mixte)
		and EtatPartie.or_total == 2
		and EtatPartie.eclats == 1,
		"Un achat au coût mixte dépense les deux ressources"
	)
	var face_remplacee := EtatPartie.des_joueur[0].faces[1].donnees
	_verifier(
		face_remplacee.attaque == offre_mixte.face.attaque
		and face_remplacee.special == offre_mixte.face.special,
		"L'achat remplace la face ciblée par la FaceData de l'offre"
	)
	_verifier(
		EtatPartie.des_joueur[1].faces[1].donnees.attaque == 2,
		"L'achat ne remplace pas une face de l'autre dé"
	)
	_verifier(
		EtatPartie.stock_de(offre_mixte) == offre_mixte.stock_max - 1
		and EtatPartie.offre_forge.has(offre_mixte),
		"Le stock baisse mais la liste d'offres n'est pas renouvelée après achat"
	)

	var offre_sans_fonds := _offre("atk5")
	_preparer_achat(offre_sans_fonds, 2, 0)
	var or_avant: int = EtatPartie.or_total
	var stock_avant: int = EtatPartie.stock_de(offre_sans_fonds)
	var face_avant := EtatPartie.des_joueur[0].faces[0].donnees.dupliquer()
	_verifier(
		not EtatPartie.acheter_offre(0, 0, offre_sans_fonds)
		and EtatPartie.or_total == or_avant
		and EtatPartie.stock_de(offre_sans_fonds) == stock_avant
		and EtatPartie.des_joueur[0].faces[0].donnees.attaque == face_avant.attaque,
		"Un achat trop cher échoue sans dépense partielle ni remplacement"
	)

	var offre_mixte_sans_eclats := _offre("garde")
	_preparer_achat(offre_mixte_sans_eclats, 20, 0)
	or_avant = EtatPartie.or_total
	_verifier(
		not EtatPartie.acheter_offre(0, 0, offre_mixte_sans_eclats)
		and EtatPartie.or_total == or_avant
		and EtatPartie.eclats == 0,
		"Un coût mixte insuffisamment financé ne débite pas l'or disponible"
	)

	var offre_epuisee := _offre("atk3")
	_preparer_achat(offre_epuisee, 10, 0)
	EtatPartie.stock[offre_epuisee.id] = 0
	or_avant = EtatPartie.or_total
	_verifier(
		not EtatPartie.acheter_offre(0, 0, offre_epuisee)
		and EtatPartie.or_total == or_avant,
		"Un achat sans stock est refusé sans dépenser"
	)

	_preparer_achat(offre_or, 10, 0)
	or_avant = EtatPartie.or_total
	_verifier(
		not EtatPartie.acheter_offre(2, 0, offre_or)
		and not EtatPartie.acheter_offre(0, 99, offre_or)
		and EtatPartie.or_total == or_avant,
		"Un dé ou une face invalide est refusé sans dépense"
	)


func _tester_entree_forge() -> void:
	EtatPartie.reinitialiser()
	EtatPartie.phase = EtatPartie.Phase.FORGE
	EtatPartie.fixer_pv_joueur(14)
	var etage_avant: int = EtatPartie.etage
	_verifier(EtatPartie.preparer_forge(), "L'entrée en Forge est acceptée après une victoire")
	var pv_apres: int = EtatPartie.pv_joueur
	var etage_apres: int = EtatPartie.etage
	_verifier(
		pv_apres == EtatPartie.pv_max_joueur
		and etage_apres == etage_avant + 1,
		"L'entrée applique le soin plafonné et avance l'étage selon l'historique"
	)
	_verifier(
		EtatPartie.ennemi_actuel.nom.contains("salle 2"),
		"La progression prépare l'ennemi historique de l'étage suivant"
	)
	EtatPartie.preparer_forge()
	_verifier(
		EtatPartie.pv_joueur == pv_apres and EtatPartie.etage == etage_apres,
		"Une même entrée n'applique ni soin ni progression deux fois"
	)
	_verifier(
		EtatPartie.offre_forge.size() <= EtatPartie.TAILLE_OFFRE_FORGE,
		"L'entrée en Forge prépare jusqu'à six offres"
	)
	var boss := EtatPartie.ennemi_pour_etage(EtatPartie.etages_max)
	_verifier(
		boss.est_boss
		and boss.nom == "☠ Seigneur des Dés"
		and boss.pv_max == 40
		and boss.recompense_eclats == 5,
		"La progression conserve les règles historiques du dernier étage"
	)


func _tester_victoire_finale_et_configuration() -> void:
	var etages_max_initial: int = EtatPartie.etages_max
	var boss_final_initial: bool = EtatPartie.boss_final_actif
	EtatPartie.etages_max = 10
	EtatPartie.boss_final_actif = true

	EtatPartie.reinitialiser()
	var ennemi_normal := EtatPartie.ennemi_pour_etage(1)
	EtatPartie.etage = 1
	EtatPartie.phase = EtatPartie.Phase.COMBAT
	EtatPartie.terminer_combat_victoire(0, 15, 0, 2, 1, ennemi_normal.est_boss)
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.FORGE,
		"Une victoire contre un ennemi normal permet d'entrer dans la Forge"
	)

	EtatPartie.reinitialiser()
	var boss_anticipe := Ennemi.new()
	boss_anticipe.est_boss = true
	EtatPartie.etage = 9
	EtatPartie.phase = EtatPartie.Phase.COMBAT
	EtatPartie.terminer_combat_victoire(0, 15, 0, 2, 1, boss_anticipe.est_boss)
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.FORGE,
		"La victoire contre un boss avant l'étage maximal poursuit la partie"
	)

	EtatPartie.reinitialiser()
	var boss_final := EtatPartie.ennemi_pour_etage(EtatPartie.etages_max)
	EtatPartie.etage = EtatPartie.etages_max
	EtatPartie.ennemi_actuel = boss_final
	EtatPartie.phase = EtatPartie.Phase.COMBAT
	var or_initial: int = EtatPartie.or_total
	var eclats_initiaux: int = EtatPartie.eclats
	EtatPartie.terminer_combat_victoire(
		3,
		15,
		0,
		boss_final.recompense_or,
		boss_final.recompense_eclats,
		boss_final.est_boss
	)
	var or_apres_victoire: int = EtatPartie.or_total
	var eclats_apres_victoire: int = EtatPartie.eclats
	EtatPartie.terminer_combat_victoire(
		3,
		15,
		0,
		boss_final.recompense_or,
		boss_final.recompense_eclats,
		boss_final.est_boss
	)
	_verifier(
		boss_final.est_boss
		and EtatPartie.phase == EtatPartie.Phase.VICTOIRE_FINALE,
		"La victoire contre le boss de l'étage maximal termine la partie"
	)
	_verifier(
		or_apres_victoire == or_initial + 3 + boss_final.recompense_or
		and eclats_apres_victoire == eclats_initiaux + boss_final.recompense_eclats
		and EtatPartie.or_total == or_apres_victoire
		and EtatPartie.eclats == eclats_apres_victoire,
		"Les récompenses du boss final sont attribuées une seule fois"
	)
	_verifier(
		not EtatPartie.preparer_forge()
		and not EtatPartie.commencer_combat()
		and EtatPartie.etage == 10,
		"La Forge, les nouveaux combats et l'étage 11 sont bloqués après la victoire finale"
	)

	EtatPartie.boss_final_actif = false
	EtatPartie.reinitialiser()
	var boss_non_terminal := EtatPartie.ennemi_pour_etage(10)
	EtatPartie.etage = 10
	EtatPartie.ennemi_actuel = boss_non_terminal
	EtatPartie.phase = EtatPartie.Phase.COMBAT
	EtatPartie.terminer_combat_victoire(
		0,
		15,
		0,
		0,
		0,
		boss_non_terminal.est_boss
	)
	var forge_accessible: bool = EtatPartie.preparer_forge()
	_verifier(
		forge_accessible
		and EtatPartie.phase == EtatPartie.Phase.FORGE
		and EtatPartie.etage == 11
		and not EtatPartie.ennemi_actuel.est_boss,
		"Sans boss final actif, la progression continue au-delà de l'étage 10"
	)

	EtatPartie.etages_max = 12
	EtatPartie.boss_final_actif = true
	var boss_configurable := EtatPartie.ennemi_pour_etage(EtatPartie.etages_max)
	_verifier(
		boss_configurable.est_boss
		and boss_configurable.nom == "☠ Seigneur des Dés",
		"Le boss final suit le nombre maximal d'étages configuré"
	)

	EtatPartie.etages_max = etages_max_initial
	EtatPartie.boss_final_actif = boss_final_initial
	EtatPartie.reinitialiser()
	_verifier(
		EtatPartie.phase == EtatPartie.Phase.TITRE
		and EtatPartie.etages_max == etages_max_initial
		and EtatPartie.boss_final_actif == boss_final_initial,
		"La réinitialisation remet la phase de jeu sans modifier la configuration"
	)


func _tester_nouvelle_partie_apres_victoire_finale() -> void:
	var arbre := get_tree()
	if arbre.current_scene == self:
		arbre.root.remove_child(self)
		arbre.root.add_child(self)

	EtatPartie.phase = EtatPartie.Phase.VICTOIRE_FINALE
	EtatPartie.etage = EtatPartie.etages_max
	EtatPartie.or_total = 99
	EtatPartie.eclats = 8
	EtatPartie.nouvelle_partie()
	await arbre.process_frame

	_verifier(
		EtatPartie.phase == EtatPartie.Phase.COMBAT
		and EtatPartie.etage == 1
		and EtatPartie.pv_joueur == EtatPartie.pv_max_joueur
		and EtatPartie.or_total == EtatPartie.OR_DE_DEPART
		and EtatPartie.eclats == EtatPartie.ECLATS_DE_DEPART
		and EtatPartie.des_joueur.size() == 2,
		"Le démarrage d'une nouvelle partie réinitialise le jeu après une victoire finale"
	)


func _tester_persistance_scene() -> void:
	EtatPartie.reinitialiser()
	var face := _face_test(9, 2, 3, 1, FaceData.Special.POISON)
	EtatPartie.des_joueur[1].remplacer_face(4, De.Face.depuis_donnees(face))
	var de_persistant := EtatPartie.des_joueur[1]

	var arbre := get_tree()
	if arbre.current_scene == self:
		arbre.root.remove_child(self)
		arbre.root.add_child(self)
	var scene_a := _creer_scene_test("ForgeA")
	var scene_b := _creer_scene_test("ForgeB")
	var instance_a := scene_a.instantiate()
	arbre.root.add_child(instance_a)
	arbre.current_scene = instance_a
	var erreur: Error = arbre.change_scene_to_packed(scene_b)
	await arbre.process_frame
	_verifier(
		erreur == OK
		and EtatPartie.des_joueur.size() == 2
		and EtatPartie.des_joueur[1] == de_persistant
		and EtatPartie.des_joueur[1].faces[4].donnees.attaque == 9
		and EtatPartie.des_joueur[1].faces[4].donnees.special == FaceData.Special.POISON,
		"Les deux dés et leurs améliorations persistent au changement de scène"
	)


func _creer_scene_test(nom: String) -> PackedScene:
	var racine := Node.new()
	racine.name = nom
	var scene := PackedScene.new()
	var erreur: Error = scene.pack(racine)
	racine.free()
	_verifier(erreur == OK, "La scène %s est créée en mémoire" % nom)
	return scene
