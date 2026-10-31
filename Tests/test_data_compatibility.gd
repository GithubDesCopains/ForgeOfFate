extends SceneTree

var _echecs: int = 0


func _initialize() -> void:
	_tester_conversion_faces()
	_tester_ennemis()
	if _echecs == 0:
		print("Tous les tests de compatibilité des données sont passés.")
		quit(0)
	else:
		push_error("%d test(s) de compatibilité en échec." % _echecs)
		quit(1)


func _verifier(condition: bool, description: String) -> void:
	if condition:
		print("[OK] %s" % description)
	else:
		_echecs += 1
		push_error("[ÉCHEC] %s" % description)


func _tester_conversion_faces() -> void:
	var de_depart := De.new()
	_verifier(
		de_depart.faces.size() == 6
		and de_depart.faces[0].type == De.FaceType.ATTAQUE
		and de_depart.faces[0].valeur == 2,
		"Le dé de départ conserve ses six faces et son attaque initiale"
	)

	var attaque := load("res://Data/Faces/attaque_3.tres") as FaceData
	var poison := load("res://Data/Faces/poison.tres") as FaceData
	var soin := load("res://Data/Faces/soin_3.tres") as FaceData

	_verifier(attaque != null and attaque.attaque == 3, "La ressource d'attaque se charge")
	_verifier(
		poison != null and poison.attaque == 1 and poison.special == FaceData.Special.POISON,
		"La ressource de poison conserve son attaque et son effet spécial"
	)
	_verifier(soin != null and soin.soin == 3, "La ressource de soin se charge")
	if attaque == null or poison == null or soin == null:
		return

	var faces_data: Array[FaceData] = [attaque, poison, soin]
	var de := De.depuis_faces_data(faces_data)
	_verifier(de.faces.size() == faces_data.size(), "Le dé conserve le nombre de faces sérialisées")
	_verifier(
		de.faces[0].type == De.FaceType.ATTAQUE and de.faces[0].valeur == 3,
		"Une attaque est convertie en face runtime compatible avec le combat"
	)
	_verifier(
		de.faces[1].donnees.special == FaceData.Special.POISON
		and de.faces[1].donnees.attaque == 1,
		"La face runtime conserve les données complètes de la face poison"
	)
	_verifier(
		de.faces[2].valeur == 0 and de.faces[2].donnees.soin == 3,
		"Un soin est conservé même si le combat actuel ne sait pas l'appliquer"
	)
	_verifier(
		de.faces[0].comme_donnees().attaque == attaque.attaque,
		"La conversion inverse restitue les données de face"
	)
	var defense := FaceData.simple(FaceData.Type.DEFENSE, 2)
	var or_face := FaceData.simple(FaceData.Type.OR, 4)
	var de_defense := De.depuis_faces_data([defense])
	var de_or := De.depuis_faces_data([or_face])
	_verifier(
		de_defense.faces[0].type == De.FaceType.DEFENSE and de_defense.faces[0].valeur == 2,
		"Une défense est convertie avec le bon type et la bonne valeur"
	)
	_verifier(
		de_or.faces[0].type == De.FaceType.OR and de_or.faces[0].valeur == 4,
		"Un gain d'or est converti avec le bon type et la bonne valeur"
	)
	_verifier(
		de.lancer(RandomNumberGenerator.new()) in de.faces,
		"Le dé converti peut être lancé"
	)

	var face_combinee := FaceData.combinee({
		FaceData.Type.ATTAQUE: 2,
		FaceData.Type.OR: 3,
	})
	var face_runtime := De.Face.depuis_donnees(face_combinee)
	_verifier(
		face_runtime.type == De.FaceType.ATTAQUE
		and face_runtime.valeur == 2
		and face_runtime.donnees.or_gain == 3,
		"Une face combinée garde tous ses effets et projette l'attaque pour l'ancien combat"
	)
	face_combinee.or_gain = 0
	_verifier(
		face_runtime.donnees.or_gain == 3,
		"Le dé conserve une copie indépendante des données sérialisées"
	)


func _tester_ennemis() -> void:
	var gobelin := load("res://Data/Ennemis/gobelin.tres") as Ennemi
	var bandit := load("res://Data/Ennemis/bandit.tres") as Ennemi
	var ogre := load("res://Data/Ennemis/ogre.tres") as Ennemi
	_verifier(gobelin != null and not gobelin.a_un_de(), "Le gobelin sans faces utilise sa riposte fixe")
	_verifier(bandit != null and bandit.a_un_de(), "Le bandit charge ses faces depuis sa ressource")
	_verifier(ogre != null and ogre.a_un_de(), "L'ogre charge ses faces depuis sa ressource")
	if gobelin == null or bandit == null or ogre == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var riposte_gobelin: Dictionary = gobelin.lancer_riposte(rng)
	_verifier(
		riposte_gobelin["degats"] == gobelin.degats_riposte
		and riposte_gobelin["face"] == null,
		"La riposte du gobelin respecte ses dégâts fixes"
	)

	for ennemi in [bandit, ogre]:
		var riposte: Dictionary = ennemi.lancer_riposte(rng)
		var face: FaceData = riposte["face"]
		_verifier(
			face in ennemi.faces and riposte["degats"] == face.attaque,
			"La riposte de %s utilise l'attaque de la face tirée" % ennemi.nom
		)
