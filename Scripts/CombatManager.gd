class_name CombatManager
extends Node

## Combat au tour par tour. L'or de salle n'est versé qu'à la victoire (EtatPartie).

enum EtatCombat { INACTIF, TOUR_JOUEUR, LANCER_EN_COURS, RIPOSTE_ENNEMI, VICTOIRE, DEFAITE }

signal combat_demarre
signal de_lance(face: Face, index: int)
signal riposte_annonce(nom_ennemi: String, degats: int, face: Face)
signal degats_infliges(cible: String, degats: int)
signal pv_joueur_change(pv_actuels: int, pv_max: int)
signal pv_ennemi_change(pv_actuels: int, pv_max: int)
signal bouclier_change(valeur: int)
signal or_salle_change(montant: int)
signal poison_change(valeur: int)
signal combat_termine(victoire: bool)
signal tour_joueur_pret

const DELAI_LANCER_SEC: float = 0.55
const DELAI_RIPOSTE_SEC: float = 0.75

var etat: EtatCombat = EtatCombat.INACTIF
var pv_joueur: int = 15
var pv_max_joueur: int = 15
var pv_ennemi: int = 8
var pv_max_ennemi: int = 8
var bouclier_joueur: int = 0
var or_salle: int = 0
var poison_ennemi: int = 0
var de_joueur: De = De.new()
var ennemi: Ennemi
var _derniere_etait_or: bool = false


func demarrer_combat() -> void:
	de_joueur = EtatPartie.de_joueur
	pv_joueur = EtatPartie.pv_joueur
	pv_max_joueur = EtatPartie.pv_max_joueur
	bouclier_joueur = EtatPartie.bouclier_joueur
	ennemi = EtatPartie.ennemi_actuel
	pv_max_ennemi = ennemi.pv_max
	pv_ennemi = ennemi.pv_max
	or_salle = 0
	poison_ennemi = 0
	_derniere_etait_or = false
	etat = EtatCombat.TOUR_JOUEUR
	combat_demarre.emit()
	pv_joueur_change.emit(pv_joueur, pv_max_joueur)
	pv_ennemi_change.emit(pv_ennemi, pv_max_ennemi)
	bouclier_change.emit(bouclier_joueur)
	or_salle_change.emit(or_salle)
	poison_change.emit(poison_ennemi)


func est_actif() -> bool:
	return etat == EtatCombat.TOUR_JOUEUR or etat == EtatCombat.LANCER_EN_COURS or etat == EtatCombat.RIPOSTE_ENNEMI


func peut_lancer() -> bool:
	return etat == EtatCombat.TOUR_JOUEUR


func lancer_de_joueur() -> void:
	if etat != EtatCombat.TOUR_JOUEUR:
		return
	etat = EtatCombat.LANCER_EN_COURS
	var face: Face = de_joueur.lancer(EtatPartie.rng)
	de_lance.emit(face, de_joueur.dernier_index)
	await get_tree().create_timer(DELAI_LANCER_SEC).timeout
	if not is_inside_tree() or etat != EtatCombat.LANCER_EN_COURS:
		return
	var relancer: bool = _appliquer_face(face)
	if etat == EtatCombat.VICTOIRE:
		return
	if relancer:
		etat = EtatCombat.TOUR_JOUEUR
		tour_joueur_pret.emit()
		return
	etat = EtatCombat.RIPOSTE_ENNEMI
	_appliquer_poison()
	if etat == EtatCombat.VICTOIRE:
		return
	var riposte: Dictionary = ennemi.lancer_riposte(EtatPartie.rng)
	var degats: int = int(riposte["degats"])
	var face_ennemi: Face = riposte.get("face") as Face
	riposte_annonce.emit(ennemi.nom, degats, face_ennemi)
	await get_tree().create_timer(DELAI_RIPOSTE_SEC).timeout
	if not is_inside_tree() or etat != EtatCombat.RIPOSTE_ENNEMI:
		return
	_infliger_degats_joueur(degats)


func _appliquer_face(face: Face) -> bool:
	if face.defense > 0:
		bouclier_joueur += face.defense
		bouclier_change.emit(bouclier_joueur)
	if face.soin > 0:
		pv_joueur = mini(pv_max_joueur, pv_joueur + face.soin)
		pv_joueur_change.emit(pv_joueur, pv_max_joueur)
	var gain_or: int = face.or_gain
	if face.special == Face.Special.OR_SI_PRECEDENT_OR and _derniere_etait_or:
		gain_or += face.or_gain if face.or_gain > 0 else 2
	if gain_or > 0:
		or_salle += gain_or
		or_salle_change.emit(or_salle)
	var attaque: int = face.attaque
	if face.special == Face.Special.DEGATS_DOUBLES_SI_BOUCLIER and bouclier_joueur > 0 and attaque > 0:
		attaque *= 2
	if attaque > 0:
		_infliger_degats_ennemi(attaque)
		if etat == EtatCombat.VICTOIRE:
			_derniere_etait_or = face.a_or()
			return false
	if face.special == Face.Special.POISON:
		poison_ennemi += 1
		poison_change.emit(poison_ennemi)
	_derniere_etait_or = face.a_or()
	return face.special == Face.Special.RELANCER


func _appliquer_poison() -> void:
	if poison_ennemi <= 0:
		return
	_infliger_degats_ennemi(poison_ennemi)
	poison_ennemi = maxi(0, poison_ennemi - 1)
	poison_change.emit(poison_ennemi)


func _infliger_degats_ennemi(degats: int) -> void:
	pv_ennemi = maxi(0, pv_ennemi - degats)
	degats_infliges.emit("ennemi", degats)
	pv_ennemi_change.emit(pv_ennemi, pv_max_ennemi)
	if pv_ennemi <= 0:
		_terminer_combat(true)


func _infliger_degats_joueur(degats: int) -> void:
	var absorbe: int = mini(bouclier_joueur, degats)
	if absorbe > 0:
		bouclier_joueur -= absorbe
		bouclier_change.emit(bouclier_joueur)
	var degats_reels: int = degats - absorbe
	if degats_reels > 0:
		pv_joueur = maxi(0, pv_joueur - degats_reels)
		degats_infliges.emit("joueur", degats_reels)
		pv_joueur_change.emit(pv_joueur, pv_max_joueur)
	if pv_joueur <= 0:
		_terminer_combat(false)
	else:
		etat = EtatCombat.TOUR_JOUEUR
		tour_joueur_pret.emit()


func _terminer_combat(victoire: bool) -> void:
	etat = EtatCombat.VICTOIRE if victoire else EtatCombat.DEFAITE
	if victoire:
		EtatPartie.terminer_combat_victoire(or_salle, pv_joueur, bouclier_joueur)
	else:
		EtatPartie.defaite()
	combat_termine.emit(victoire)
