class_name CombatManager
extends Node

enum EtatCombat { INACTIF, TOUR_JOUEUR, LANCER_EN_COURS, RIPOSTE_ENNEMI, VICTOIRE, DEFAITE }

signal combat_demarre
signal de_lance(face: De.Face)
signal des_lances(faces: Array[De.Face])
signal degats_infliges(cible: String, degats: int)
signal pv_joueur_change(pv_actuels: int, pv_max: int)
signal pv_ennemi_change(pv_actuels: int, pv_max: int)
signal bouclier_change(valeur: int)
signal or_gagne(montant: int, total: int)
signal combat_termine(victoire: bool)

const ENNEMI_DEFAUT: Ennemi = preload("res://Data/Ennemis/gobelin.tres")

var etat: EtatCombat = EtatCombat.INACTIF
var pv_joueur: int:
	get:
		return EtatPartie.pv_joueur
	set(valeur):
		EtatPartie.fixer_pv_joueur(valeur)
var pv_max_joueur: int:
	get:
		return EtatPartie.pv_max_joueur
var ennemi: Ennemi
var pv_ennemi: int = 0
var pv_max_ennemi: int = 0
var bouclier_joueur: int:
	get:
		return EtatPartie.bouclier_joueur
	set(valeur):
		EtatPartie.fixer_bouclier_joueur(valeur)
var or_accumule: int = 0
var poison_ennemi: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _derniere_face_avait_or: bool = false
var _face_en_application: bool = false


func _ready() -> void:
	rng.randomize()


func demarrer_combat() -> void:
	if etat != EtatCombat.INACTIF:
		return
	if ennemi == null:
		ennemi = EtatPartie.ennemi_actuel if EtatPartie.ennemi_actuel != null else ENNEMI_DEFAUT
	if ennemi.pv_max <= 0:
		push_error("L'ennemi doit avoir des PV maximum strictement positifs.")
		return
	if not EtatPartie.commencer_combat():
		return

	pv_max_ennemi = ennemi.pv_max
	pv_ennemi = pv_max_ennemi
	or_accumule = 0
	poison_ennemi = 0
	_derniere_face_avait_or = false
	etat = EtatCombat.TOUR_JOUEUR
	combat_demarre.emit()
	pv_joueur_change.emit(pv_joueur, pv_max_joueur)
	pv_ennemi_change.emit(pv_ennemi, pv_max_ennemi)
	bouclier_change.emit(bouclier_joueur)


func est_actif() -> bool:
	return (
		etat == EtatCombat.TOUR_JOUEUR
		or etat == EtatCombat.LANCER_EN_COURS
		or etat == EtatCombat.RIPOSTE_ENNEMI
	)


func peut_lancer() -> bool:
	return etat == EtatCombat.TOUR_JOUEUR


func lancer_de_joueur() -> void:
	if etat != EtatCombat.TOUR_JOUEUR:
		return
	if EtatPartie.des_joueur.is_empty():
		push_error("Impossible de lancer les dés : aucun dé joueur n'est disponible.")
		return

	var faces_obtenues: Array[De.Face] = []
	for de in EtatPartie.des_joueur:
		if de == null or de.faces.is_empty():
			push_error("Impossible de lancer un dé joueur sans faces.")
			return
		faces_obtenues.append(de.lancer(rng))

	etat = EtatCombat.LANCER_EN_COURS
	de_lance.emit(faces_obtenues[0])
	des_lances.emit(faces_obtenues)

	var relancer: bool = false
	for face in faces_obtenues:
		relancer = _appliquer_face(face) or relancer
	if pv_ennemi <= 0:
		_terminer_combat(true)
		return
	if relancer:
		etat = EtatCombat.TOUR_JOUEUR
		return

	etat = EtatCombat.RIPOSTE_ENNEMI
	_appliquer_poison()
	if pv_ennemi <= 0:
		_terminer_combat(true)
		return
	_riposte_ennemi()


func _appliquer_face(face: De.Face) -> bool:
	if _face_en_application:
		push_error("Une face ne peut pas être appliquée deux fois simultanément.")
		return false
	if face == null or face.donnees == null:
		push_error("La face lancée ne contient pas de données valides.")
		return false
	if not est_actif():
		return false

	_face_en_application = true
	var donnees: FaceData = face.donnees

	if donnees.defense > 0:
		EtatPartie.ajouter_bouclier(donnees.defense)
		bouclier_change.emit(bouclier_joueur)

	if donnees.soin > 0:
		EtatPartie.soigner_joueur(donnees.soin)
		pv_joueur_change.emit(pv_joueur, pv_max_joueur)

	var gain_or: int = donnees.or_gain
	if (
		donnees.special == FaceData.Special.OR_SI_PRECEDENT_OR
		and _derniere_face_avait_or
	):
		gain_or += donnees.or_gain if donnees.or_gain > 0 else 2
	if gain_or > 0:
		or_accumule += gain_or
		or_gagne.emit(gain_or, or_accumule)

	var attaque: int = donnees.attaque
	if (
		donnees.special == FaceData.Special.DEGATS_DOUBLES_SI_BOUCLIER
		and bouclier_joueur > 0
		and attaque > 0
	):
		attaque *= 2

	if donnees.special == FaceData.Special.POISON:
		poison_ennemi += 1

	_derniere_face_avait_or = donnees.a_or()
	if attaque > 0 and etat == EtatCombat.LANCER_EN_COURS:
		_infliger_degats_ennemi(attaque)

	_face_en_application = false
	return donnees.special == FaceData.Special.RELANCER


func _appliquer_poison() -> void:
	if poison_ennemi <= 0 or etat != EtatCombat.RIPOSTE_ENNEMI:
		return
	var degats_poison: int = poison_ennemi
	poison_ennemi = maxi(0, poison_ennemi - 1)
	_infliger_degats_ennemi(degats_poison)


func _infliger_degats_ennemi(degats: int) -> void:
	if degats <= 0 or pv_ennemi <= 0 or not est_actif():
		return
	pv_ennemi = maxi(0, pv_ennemi - degats)
	degats_infliges.emit("ennemi", degats)
	pv_ennemi_change.emit(pv_ennemi, pv_max_ennemi)


func _riposte_ennemi() -> void:
	if etat != EtatCombat.RIPOSTE_ENNEMI or ennemi == null:
		return

	var riposte: Dictionary = ennemi.lancer_riposte(rng)
	var degats: int = maxi(0, int(riposte.get("degats", 0)))
	var absorbe: int = EtatPartie.absorber_bouclier(degats)
	if absorbe > 0:
		bouclier_change.emit(bouclier_joueur)

	var degats_reels: int = degats - absorbe
	if degats_reels > 0:
		EtatPartie.perdre_pv(degats_reels)
		degats_infliges.emit("joueur", degats_reels)
		pv_joueur_change.emit(pv_joueur, pv_max_joueur)

	if pv_joueur <= 0:
		_terminer_combat(false)
	else:
		etat = EtatCombat.TOUR_JOUEUR


func _terminer_combat(victoire: bool) -> void:
	if not est_actif():
		return
	if victoire and pv_ennemi > 0:
		return
	if not victoire and pv_joueur > 0:
		return

	etat = EtatCombat.VICTOIRE if victoire else EtatCombat.DEFAITE
	if victoire:
		EtatPartie.terminer_combat_victoire(
			or_accumule,
			pv_joueur,
			bouclier_joueur,
			ennemi.recompense_or,
			ennemi.recompense_eclats,
			ennemi.est_boss
		)
	else:
		EtatPartie.defaite()
	combat_termine.emit(victoire)
