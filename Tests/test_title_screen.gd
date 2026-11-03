extends Node

var _reussites: int = 0
var _echecs: int = 0


func _ready() -> void:
	call_deferred("_executer_tests")


func _executer_tests() -> void:
	await _tester_scene_et_boutons()
	await _tester_nouvelle_partie()

	if _echecs == 0:
		print("Tous les tests du menu principal sont passés (%d assertions)." % _reussites)
		get_tree().quit(0)
	else:
		push_error("%d test(s) du menu en échec sur %d assertions." % [
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


func _preparer_runner_persistant() -> void:
	var arbre := get_tree()
	if arbre.current_scene == self:
		arbre.root.remove_child(self)
		arbre.root.add_child(self)


func _tester_scene_et_boutons() -> void:
	_verifier(
		ProjectSettings.get_setting("application/run/main_scene")
			== "res://Scenes/Title.tscn",
		"Le projet démarre sur la scène du menu principal"
	)
	var scene := load("res://Scenes/Title.tscn") as PackedScene
	_verifier(scene != null, "La scène du menu principal se charge")
	if scene == null:
		return

	var title := scene.instantiate() as Control
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await get_tree().process_frame

	var boutons := [
		title.get_node("MenuPanel/Marge/Menu/NouvellePartie"),
		title.get_node("MenuPanel/Marge/Menu/Continuer"),
		title.get_node("MenuPanel/Marge/Menu/Options"),
		title.get_node("MenuPanel/Marge/Menu/Quitter"),
	]
	_verifier(
		title.get_node("MenuPanel/Marge/Menu/Titre").text == "Forged by Fate",
		"Le titre du jeu est affiché"
	)
	_verifier(
		boutons.size() == 4
		and boutons[0] is Button
		and boutons[1] is Button
		and boutons[2] is Button
		and boutons[3] is Button,
		"Les quatre actions sont des boutons Godot distincts"
	)
	var bouton_principal := boutons[0] as Button
	var styles_communs: bool = (
		bouton_principal.get_theme_stylebox("normal") != null
		and bouton_principal.get_theme_stylebox("hover") != null
		and bouton_principal.get_theme_stylebox("pressed") != null
		and bouton_principal.get_theme_stylebox("disabled") != null
		and bouton_principal.get_theme_font("font") != null
	)
	_verifier(
		styles_communs,
		"Le thème commun fournit les états des boutons et la police du moteur"
	)
	_verifier(
		(title.get_node("MenuPanel/Marge/Menu/Continuer") as Button).disabled,
		"Continuer reste désactivé sans sauvegarde"
	)
	_verifier(
		(title.get_node("MenuPanel/Marge/Menu/Quitter") as Button).pressed.is_connected(
			Callable(title, "_on_quitter")
		),
		"Le bouton Quitter conserve sa connexion"
	)
	_verifier(
		not (title.get_node("AssetNotice") as Label).visible
		and (title.get_node("Illustration") as TextureRect).texture != null
		and (title.get_node("Illustration") as TextureRect).texture.resource_path
			== "res://assets/Images/Backgrounds/menu/fond_menu.jpg",
		"L'illustration importée est assignée au fond et son absence n'est plus signalée"
	)
	await _tester_adaptabilite(scene)
	(title.get_node("MenuPanel/Marge/Menu/Options") as Button).emit_signal("pressed")
	_verifier(
		(title.get_node("MenuPanel/Marge/Menu/Message") as Label).text.contains(
			"ajoutées dans une mission ultérieure"
		),
		"Options affiche un message explicatif"
	)


func _tester_adaptabilite(scene: PackedScene) -> void:
	for taille in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = taille
		add_child(viewport)
		var menu := scene.instantiate() as Control
		viewport.add_child(menu)
		await get_tree().process_frame
		await get_tree().process_frame

		var panneau := menu.get_node("MenuPanel") as Control
		var panneau_rect: Rect2 = panneau.get_global_rect()
		var illustration := menu.get_node("Illustration") as TextureRect
		var illustration_rect: Rect2 = illustration.get_global_rect()
		var panneau_visible: bool = (
			panneau_rect.position.x >= 0
			and panneau_rect.position.y >= 0
			and panneau_rect.end.x <= taille.x
			and panneau_rect.end.y <= taille.y
		)
		var commandes_dans_panneau: bool = true
		for nom in ["Titre", "NouvellePartie", "Continuer", "Options", "Quitter"]:
			var commande := menu.get_node("MenuPanel/Marge/Menu/" + nom) as Control
			var commande_rect: Rect2 = commande.get_global_rect()
			if not panneau_rect.encloses(commande_rect):
				commandes_dans_panneau = false

		_verifier(
			panneau_visible and commandes_dans_panneau,
			"Le titre et les boutons restent dans le panneau en %d x %d"
			% [taille.x, taille.y]
		)
		_verifier(
			illustration.texture != null
			and illustration.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED
			and is_equal_approx(illustration_rect.size.x, taille.x)
			and is_equal_approx(illustration_rect.size.y, taille.y),
			"Le fond couvre la fenêtre sans déformation en %d x %d" % [taille.x, taille.y]
		)
		viewport.queue_free()
		await get_tree().process_frame


func _tester_nouvelle_partie() -> void:
	_preparer_runner_persistant()
	EtatPartie.fixer_pv_joueur(3)
	EtatPartie.or_total = 88
	EtatPartie.eclats = 9
	EtatPartie.etage = 6
	EtatPartie.des_joueur[0].remplacer_face(
		0,
		De.Face.depuis_donnees(_face_attaque(12))
	)
	var catalogue := EtatPartie.catalogue_forge()
	if catalogue != null and not catalogue.offres.is_empty():
		EtatPartie.stock[catalogue.offres[0].id] = 0

	var nouvelle_partie: Button = (
		get_tree().current_scene.get_node("MenuPanel/Marge/Menu/NouvellePartie")
	)
	nouvelle_partie.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	var combat := get_tree().current_scene as Control
	_verifier(
		combat != null and combat.name == "Combat",
		"Nouvelle partie charge la scène Combat"
	)
	if combat == null or combat.name != "Combat":
		return

	_verifier(
		EtatPartie.phase == EtatPartie.Phase.COMBAT
		and EtatPartie.etage == 1
		and EtatPartie.pv_joueur == 15
		and EtatPartie.pv_max_joueur == 15
		and EtatPartie.or_total == 12
		and EtatPartie.eclats == 0
		and EtatPartie.bouclier_joueur == 0
		and EtatPartie.des_joueur.size() == 2
		and not EtatPartie.ennemi_actuel.est_boss,
		"Nouvelle partie réinitialise phase, étage, ressources, PV et ennemi"
	)

	var des_initiaux := true
	for de in EtatPartie.des_joueur:
		if de.faces.size() != 6:
			des_initiaux = false
			continue
		for index in de.faces.size():
			var donnees: FaceData = de.faces[index].donnees
			if donnees.special != FaceData.Special.AUCUN:
				des_initiaux = false
			match index:
				0, 1:
					if donnees.attaque != 2:
						des_initiaux = false
				2, 3:
					if donnees.defense != 2:
						des_initiaux = false
				4, 5:
					if donnees.or_gain != 1:
						des_initiaux = false
	_verifier(des_initiaux, "Les deux dés retrouvent leurs faces de départ")

	var stock_initial := catalogue != null
	if catalogue != null:
		if EtatPartie.stock.size() != catalogue.offres.size():
			stock_initial = false
		for offre in catalogue.offres:
			if EtatPartie.stock_de(offre) != offre.stock_max:
				stock_initial = false
	_verifier(stock_initial, "Le stock de Forge est restauré")


func _face_attaque(valeur: int) -> FaceData:
	var face := FaceData.new()
	face.attaque = valeur
	return face
