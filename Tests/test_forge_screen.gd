extends Node

var _reussites: int = 0
var _echecs: int = 0


func _ready() -> void:
	call_deferred("_executer_tests")


func _executer_tests() -> void:
	_tester_affichage_selection_et_achat()
	await _tester_navigation_et_persistance()

	if _echecs == 0:
		print("Tous les tests de l'interface Forge sont passés (%d assertions)." % _reussites)
		get_tree().quit(0)
	else:
		push_error("%d test(s) interface Forge en échec sur %d assertions." % [
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


func _creer_ecran_forge() -> Control:
	var scene := load("res://Scenes/Forge.tscn") as PackedScene
	_verifier(scene != null, "Forge.tscn se charge")
	if scene == null:
		return null
	var ecran := scene.instantiate() as Control
	_verifier(ecran != null, "ForgeScreen s'instancie")
	if ecran != null:
		add_child(ecran)
	return ecran


func _offre(id: String) -> OffreForge:
	for offre in EtatPartie.catalogue_forge().offres:
		if offre.id == id:
			return offre
	return null


func _boutique(ecran: Control) -> VBoxContainer:
	return ecran.get_node("Marge/VBox/Scroll/Colonnes/BoutiqueBox/BoutiqueList") as VBoxContainer


func _des(ecran: Control) -> VBoxContainer:
	return ecran.get_node("Marge/VBox/Scroll/Colonnes/DeBox/DeList") as VBoxContainer


func _bouton_achat(ecran: Control, id: String) -> Button:
	return _boutique(ecran).get_node("Offre_" + id + "/Acheter_" + id) as Button


func _tester_affichage_selection_et_achat() -> void:
	EtatPartie.reinitialiser()
	EtatPartie.phase = EtatPartie.Phase.FORGE
	EtatPartie.preparer_forge()
	EtatPartie.fixer_pv_joueur(11)
	EtatPartie.or_total = 10
	EtatPartie.eclats = 2
	var offre_or := _offre("atk3")
	var offre_eclats := _offre("garde")
	EtatPartie.offre_forge = [offre_or, offre_eclats]
	EtatPartie.stock[offre_or.id] = 2
	EtatPartie.stock[offre_eclats.id] = 1
	var ecran := _creer_ecran_forge()
	if ecran == null:
		return

	var vbox: VBoxContainer = ecran.get_node("Marge/VBox") as VBoxContainer
	_verifier(
		(vbox.get_node("Ressources/OrLabel") as Label).text == "Or : 10"
		and (vbox.get_node("Ressources/EclatsLabel") as Label).text == "Éclats : 2"
		and (vbox.get_node("SoinLabel") as Label).text == "PV : 11 / 15",
		"L'or, les éclats et les PV sont affichés depuis EtatPartie"
	)
	_verifier(
		_des(ecran).get_node("SelectionDes").get_child_count() == 2
		and _des(ecran).get_child_count() == 13,
		"Les deux dés et leurs six faces sont affichés"
	)
	_verifier(
		_boutique(ecran).get_child_count() == 2
		and _boutique(ecran).get_node("Offre_atk3").get_child(0).get_child(0).text.contains("Attaque +3")
		and _boutique(ecran).get_node("Offre_garde").get_child(0).get_child(1).text.contains("Stock : 1"),
		"Les offres montrent les effets, les prix et les stocks"
	)

	var faces_second_de_avant: FaceData = EtatPartie.des_joueur[1].faces[2].donnees.dupliquer()
	ecran.call("_on_selectionner_de", 1)
	ecran.call("_on_selectionner_face", 2)
	_verifier(
		ecran.get("_index_de_selectionne") == 1
		and ecran.get("_index_face_selectionnee") == 2
		and EtatPartie.des_joueur[1].faces[2].donnees.attaque == faces_second_de_avant.attaque,
		"La sélection du second dé et de sa face ne modifie pas les données"
	)
	_verifier(
		_bouton_achat(ecran, "atk3").disabled == false,
		"Une offre avec stock et ressources suffisants est indiquée disponible"
	)

	var offre_count_avant: int = EtatPartie.offre_forge.size()
	_bouton_achat(ecran, "atk3").emit_signal("pressed")
	_verifier(
		EtatPartie.or_total == 6
		and EtatPartie.stock_de(offre_or) == 1
		and EtatPartie.offre_forge.size() == offre_count_avant,
		"L'achat actualise les ressources et le stock sans renouveler les offres"
	)
	_verifier(
		EtatPartie.des_joueur[1].faces[2].donnees.attaque == 3
		and (vbox.get_node("Ressources/OrLabel") as Label).text == "Or : 6"
		and (vbox.get_node("Ressources/EclatsLabel") as Label).text == "Éclats : 2",
		"L'achat remplace la face sélectionnée et actualise l'affichage"
	)
	_verifier(
		_boutique(ecran).get_node("Offre_atk3").get_child(0).get_child(1).text.contains("Stock : 1")
		and (vbox.get_node("Message") as Label).text.contains("remplacée"),
		"Le stock affiché est actualisé et le succès est confirmé"
	)

	var or_avant: int = EtatPartie.or_total
	var eclats_avant: int = EtatPartie.eclats
	var stock_avant: int = EtatPartie.stock_de(offre_eclats)
	ecran.call("_on_selectionner_face", 1)
	ecran.call("_on_acheter_presse", offre_eclats)
	_verifier(
		EtatPartie.or_total == or_avant
		and EtatPartie.eclats == eclats_avant
		and EtatPartie.stock_de(offre_eclats) == stock_avant
		and (vbox.get_node("Message") as Label).text.contains("Achat refusé"),
		"Un achat refusé affiche un message et ne change aucune donnée"
	)
	ecran.queue_free()
	await get_tree().process_frame


func _tester_navigation_et_persistance() -> void:
	var arbre := get_tree()
	if arbre.current_scene == self:
		arbre.root.remove_child(self)
		arbre.root.add_child(self)

	EtatPartie.reinitialiser()
	EtatPartie.phase = EtatPartie.Phase.FORGE
	EtatPartie.preparer_forge()
	var face_persistante := FaceData.new()
	face_persistante.attaque = 9
	face_persistante.defense = 2
	face_persistante.special = FaceData.Special.POISON
	EtatPartie.des_joueur[1].remplacer_face(4, De.Face.depuis_donnees(face_persistante))
	EtatPartie.stock["atk3"] = 1
	EtatPartie.or_total = 27
	EtatPartie.eclats = 4
	var second_de := EtatPartie.des_joueur[1]

	var scene := load("res://Scenes/Forge.tscn") as PackedScene
	var forge := scene.instantiate() as Control
	arbre.root.add_child(forge)
	arbre.current_scene = forge
	var connexions: Array = (
		(forge.get_node("Marge/VBox/Actions/BoutonCombat") as Button)
		.get_signal_connection_list("pressed")
	)
	_verifier(
		not connexions.is_empty(),
		"Le bouton de retour au combat est relié à la navigation existante"
	)
	(forge.get_node("Marge/VBox/Actions/BoutonCombat") as Button).emit_signal("pressed")
	await arbre.process_frame
	_verifier(
		arbre.current_scene != forge
		and EtatPartie.phase == EtatPartie.Phase.COMBAT
		and EtatPartie.des_joueur[1] == second_de
		and EtatPartie.des_joueur[1].faces[4].donnees.attaque == 9
		and EtatPartie.des_joueur[1].faces[4].donnees.special == FaceData.Special.POISON
		and EtatPartie.stock_de(_offre("atk3")) == 1
		and EtatPartie.or_total == 27
		and EtatPartie.eclats == 4,
		"Le retour au combat conserve dés, améliorations, stock et ressources"
	)
