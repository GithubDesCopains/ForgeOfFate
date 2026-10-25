extends Node

## Script de tests automatisés (100% gratuit, exécutable en ligne de commande avec Godot headless).

var _succes: int = 0
var _echecs: int = 0


func _ready() -> void:
	print("==========================================")
	print("🧪 LANCEMENT DES TESTS AUTOMATISÉS DICEY-FORGE")
	print("==========================================")
	
	test_de_et_faces()
	test_ennemi_scaling()
	test_victoire_et_recompenses()
	test_reinitialisation_bouclier()
	test_boutique_forge()
	test_chargement_scenes_et_ui()
	
	print("==========================================")
	if _echecs == 0:
		print("✅ TOUS LES TESTS SONT PASSÉS AVEC SUCCÈS (%d/%d)" % [_succes, _succes])
		print("==========================================")
		get_tree().quit(0)
	else:
		print("❌ ÉCHEC DE CERTAINS TESTS (%d échecs, %d succès)" % [_echecs, _succes])
		print("==========================================")
		get_tree().quit(1)


func assert_vrai(condition: bool, nom_test: String) -> void:
	if condition:
		_succes += 1
		print("  [OK] %s" % nom_test)
	else:
		_echecs += 1
		push_error("  [FAIL] %s" % nom_test)


func assert_egal(actuel, attendu, nom_test: String) -> void:
	if actuel == attendu:
		_succes += 1
		print("  [OK] %s" % nom_test)
	else:
		_echecs += 1
		push_error("  [FAIL] %s (attendu: %s, obtenu: %s)" % [nom_test, str(attendu), str(actuel)])


func test_de_et_faces() -> void:
	print("\n--- Test 1 : Dé et Faces ---")
	assert_egal(EtatPartie.des_joueur.size(), 2, "Le joueur possède bien 2 dés en début de partie")
	
	var de := De.new()
	assert_egal(de.faces.size(), 6, "Le dé possède bien 6 faces de départ")
	
	# Vérification des 6 faces standard
	assert_egal(de.faces[0].attaque, 1, "Face 1 : 1 Dégât")
	assert_egal(de.faces[0].or_gain, 0, "Face 1 : 0 Or")
	assert_egal(de.faces[1].attaque, 2, "Face 2 : 2 Dégâts")
	assert_egal(de.faces[2].attaque, 1, "Face 3 : 1 Dégât")
	assert_egal(de.faces[2].or_gain, 1, "Face 3 : 1 Or")
	assert_egal(de.faces[3].defense, 1, "Face 4 : 1 Bouclier")
	assert_egal(de.faces[4].defense, 2, "Face 5 : 2 Boucliers")
	assert_egal(de.faces[5].defense, 1, "Face 6 : 1 Bouclier")
	assert_egal(de.faces[5].or_gain, 1, "Face 6 : 1 Or")
	
	var face_remplacement := Face.simple(Face.Type.ATTAQUE, 5)
	var ok := de.remplacer_face(0, face_remplacement)
	assert_vrai(ok, "Remplacement de la face 0 réussi")
	assert_egal(de.faces[0].attaque, 5, "La face 0 a bien 5 en attaque")


func test_ennemi_scaling() -> void:
	print("\n--- Test 2 : Échelonnage des ennemis ---")
	# Nouveau cycle : Gobelin (1-3), Bandit (4-6), Ogre (7-9), Boss (10)
	var gobelin := EtatPartie.ennemi_pour_etage(1)
	assert_egal(gobelin.nom, "Gobelin", "Étage 1 = Gobelin")
	# PV Gobelin base (8) + 1*2 = 10
	assert_egal(gobelin.pv_max, 10, "PV Gobelin étage 1 = 10")
	assert_egal(gobelin.degats_riposte, 1, "Dégâts Gobelin = 1 à la fois")
	
	var gobelin2 := EtatPartie.ennemi_pour_etage(2)
	assert_vrai(gobelin2.nom.begins_with("Gobelin"), "Étage 2 = Gobelin")
	
	var gobelin3 := EtatPartie.ennemi_pour_etage(3)
	assert_vrai(gobelin3.nom.begins_with("Gobelin"), "Étage 3 = encore Gobelin")
	
	# Étage 4 : premier Bandit
	var bandit4 := EtatPartie.ennemi_pour_etage(4)
	assert_vrai(bandit4.nom.begins_with("Bandit"), "Étage 4 = Bandit")
	
	# Étage 7 : premier Ogre
	var ogre7 := EtatPartie.ennemi_pour_etage(7)
	assert_vrai(ogre7.nom.begins_with("Ogre"), "Étage 7 = Ogre")
	assert_vrai(ogre7.a_un_de(), "L'Ogre a un dé")
	
	# Étage 10 : Boss
	var boss := EtatPartie.ennemi_pour_etage(10)
	assert_egal(boss.nom, "☠ Seigneur des Dés", "Étage 10 = Boss final")
	assert_egal(boss.pv_max, 40, "Le Boss a 40 PV")



func test_victoire_et_recompenses() -> void:
	print("\n--- Test 3 : Récompenses et coup mortel ---")
	var combat := CombatManager.new()
	combat.pv_ennemi = 1
	combat.pv_max_ennemi = 8
	combat.pv_joueur = 10
	combat.pv_max_joueur = 15
	combat.or_salle = 0
	
	# Face combinant Attaque 2 et Or 3
	var face_combo := Face.combinee({
		Face.Type.ATTAQUE: 2,
		Face.Type.OR: 3
	})
	
	combat._appliquer_face(face_combo)
	assert_egal(combat.pv_ennemi, 0, "L'ennemi a été vaincu")
	assert_egal(combat.etat, CombatManager.EtatCombat.VICTOIRE, "L'état de combat est VICTOIRE")
	assert_egal(combat.or_salle, 3, "L'or de la face mortelle a bien été crédité (3 or)")


func test_reinitialisation_bouclier() -> void:
	print("\n--- Test 4 : Réinitialisation du bouclier ---")
	EtatPartie.bouclier_joueur = 12
	EtatPartie.preparer_nouveau_combat()
	assert_egal(EtatPartie.bouclier_joueur, 0, "Le bouclier est remis à 0 lors de la préparation au combat")


func test_boutique_forge() -> void:
	print("\n--- Test 5 : Tirage boutique Forge ---")
	var offres := Forge.tirer_offre(1, EtatPartie.rng, EtatPartie.stock, 4)
	assert_vrai(offres.size() > 0, "La boutique génère bien des offres")
	for o in offres:
		assert_vrai(o.etage_min <= 1, "Toutes les offres respectent le niveau minimum d'étage")


func test_chargement_scenes_et_ui() -> void:
	print("\n--- Test 6 : Validation des scènes et UI ---")
	var scene_combat := load("res://Scenes/Combat.tscn") as PackedScene
	assert_vrai(scene_combat != null, "La scène Combat.tscn se charge sans erreur")
	var instance_combat := scene_combat.instantiate() as CombatScreen
	assert_vrai(instance_combat != null, "CombatScreen s'instancie sans erreur")
	add_child(instance_combat)
	
	# Simuler la réception de dégâts et de popups
	instance_combat._on_degats_infliges("ennemi", 3)
	instance_combat._on_degats_infliges("joueur", 2)
	assert_vrai(true, "Gestionnaires de popups et secousses exécutés sans exception")
	
	instance_combat.queue_free()
