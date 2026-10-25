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
	var de := De.new()
	assert_egal(de.faces.size(), 6, "Le dé possède bien 6 faces de départ")
	
	var face_remplacement := Face.simple(Face.Type.ATTAQUE, 5)
	var ok := de.remplacer_face(0, face_remplacement)
	assert_vrai(ok, "Remplacement de la face 0 réussi")
	assert_egal(de.faces[0].attaque, 5, "La face 0 a bien 5 en attaque")


func test_ennemi_scaling() -> void:
	print("\n--- Test 2 : Échelonnage des ennemis ---")
	var gobelin := EtatPartie.ennemi_pour_etage(1)
	assert_egal(gobelin.nom, "Gobelin", "Étage 1 = Gobelin")
	assert_egal(gobelin.pv_max, 8, "PV Gobelin = 8")
	
	var bandit := EtatPartie.ennemi_pour_etage(2)
	assert_egal(bandit.nom, "Bandit", "Étage 2 = Bandit")
	
	var ogre_normal := EtatPartie.ennemi_pour_etage(3)
	assert_egal(ogre_normal.nom, "Ogre", "Étage 3 = Ogre")
	assert_egal(ogre_normal.pv_max, 18, "PV Ogre = 18")
	
	# Étage 4 : extra = 1, les faces de l'ogre doivent avoir +1 attaque
	var ogre_salle_4 := EtatPartie.ennemi_pour_etage(4)
	assert_egal(ogre_salle_4.nom, "Ogre (salle 4)", "Nom échelonné étage 4")
	assert_egal(ogre_salle_4.pv_max, 22, "PV Ogre salle 4 = 18 + 4 = 22")
	assert_vrai(ogre_salle_4.a_un_de(), "L'Ogre a un dé")
	assert_egal(ogre_salle_4.faces[0].attaque, ogre_normal.faces[0].attaque + 1, "La face 0 de l'Ogre a bien +1 attaque")


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
