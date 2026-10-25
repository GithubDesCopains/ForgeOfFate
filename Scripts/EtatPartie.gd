extends Node

## Autoload : état de run, phase, RNG, boutique. Survives aux changements de scène.

signal or_change(total: int)
signal eclats_change(total: int)
signal run_terminee

enum Phase { TITRE, COMBAT, FORGE, GAME_OVER }

const SCENE_TITRE: String = "res://Scenes/Title.tscn"
const SCENE_COMBAT: String = "res://Scenes/Combat.tscn"
const SCENE_FORGE: String = "res://Scenes/Forge.tscn"
const CATALOGUE_PATH: String = "res://Data/Forge/catalogue.tres"
const ENNEMI_GOBELIN: String = "res://Data/Ennemis/gobelin.tres"
const ENNEMI_BANDIT: String = "res://Data/Ennemis/bandit.tres"
const ENNEMI_OGRE: String = "res://Data/Ennemis/ogre.tres"

const PV_MAX_JOUEUR: int = 15
const OR_DE_DEPART: int = 0
const ECLATS_DE_DEPART: int = 0
const SOIN_FORGE: int = 3
const TAILLE_OFFRE: int = 6

var phase: Phase = Phase.TITRE
var des_joueur: Array[De] = [De.new(), De.new()]
var de_joueur: De = des_joueur[0]
var or_total: int = OR_DE_DEPART
var eclats: int = ECLATS_DE_DEPART
var pv_joueur: int = PV_MAX_JOUEUR
var pv_max_joueur: int = PV_MAX_JOUEUR
var bouclier_joueur: int = 0
var etage: int = 1
var ennemi_actuel: Ennemi
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stock: Dictionary = {}
var offre_forge: Array[OffreForge] = []
var salles_gagnees: int = 0


func _ready() -> void:
	reinitialiser()


func nouvelle_partie() -> void:
	reinitialiser()
	phase = Phase.COMBAT
	get_tree().change_scene_to_file(SCENE_COMBAT)


func reinitialiser() -> void:
	phase = Phase.TITRE
	rng.randomize()
	des_joueur = [De.new(), De.new()]
	de_joueur = des_joueur[0]
	or_total = OR_DE_DEPART
	eclats = ECLATS_DE_DEPART
	pv_joueur = PV_MAX_JOUEUR
	pv_max_joueur = PV_MAX_JOUEUR
	bouclier_joueur = 0
	etage = 1
	salles_gagnees = 0
	ennemi_actuel = ennemi_pour_etage(1)
	_reinitialiser_stock()
	offre_forge.clear()
	or_change.emit(or_total)
	eclats_change.emit(eclats)


func ajouter_or(montant: int) -> void:
	if montant > 0:
		or_total += montant
		or_change.emit(or_total)


func depenser_or(montant: int) -> bool:
	if montant > or_total:
		return false
	or_total -= montant
	or_change.emit(or_total)
	return true


func ajouter_eclats(montant: int) -> void:
	if montant > 0:
		eclats += montant
		eclats_change.emit(eclats)


func depenser_eclats(montant: int) -> bool:
	if montant > eclats:
		return false
	eclats -= montant
	eclats_change.emit(eclats)
	return true


func peut_payer(cout_or: int, cout_eclats: int) -> bool:
	return or_total >= cout_or and eclats >= cout_eclats


func terminer_combat_victoire(or_salle: int, pv: int, bouclier: int) -> void:
	pv_joueur = pv
	bouclier_joueur = bouclier
	var bonus_or: int = ennemi_actuel.recompense_or if ennemi_actuel else 0
	var bonus_eclats: int = ennemi_actuel.recompense_eclats if ennemi_actuel else 0
	ajouter_or(or_salle + bonus_or)
	ajouter_eclats(bonus_eclats)
	salles_gagnees += 1
	phase = Phase.FORGE


func aller_a_forge() -> void:
	phase = Phase.FORGE
	etage += 1
	ennemi_actuel = ennemi_pour_etage(etage)
	pv_joueur = mini(pv_max_joueur, pv_joueur + SOIN_FORGE)
	regenerer_offre()
	get_tree().change_scene_to_file(SCENE_FORGE)


func preparer_nouveau_combat() -> void:
	phase = Phase.COMBAT
	offre_forge.clear()
	bouclier_joueur = 0


func aller_au_combat() -> void:
	preparer_nouveau_combat()
	get_tree().change_scene_to_file(SCENE_COMBAT)


func defaite() -> void:
	phase = Phase.GAME_OVER
	run_terminee.emit()


func retour_titre() -> void:
	reinitialiser()
	phase = Phase.TITRE
	get_tree().change_scene_to_file(SCENE_TITRE)


func catalogue() -> Array[OffreForge]:
	var cat := load(CATALOGUE_PATH) as CatalogueForge
	if cat == null:
		return []
	return cat.offres


func stock_de(offre: OffreForge) -> int:
	return int(stock.get(offre.id, 0))


func consommer_stock(offre: OffreForge) -> bool:
	var restant: int = stock_de(offre)
	if restant <= 0:
		return false
	stock[offre.id] = restant - 1
	return true


func regenerer_offre() -> void:
	offre_forge = Forge.tirer_offre(etage, rng, stock, TAILLE_OFFRE)


func ennemi_pour_etage(n: int) -> Ennemi:
	var chemins: PackedStringArray = [ENNEMI_GOBELIN, ENNEMI_BANDIT, ENNEMI_OGRE]
	var idx: int = mini(n - 1, chemins.size() - 1)
	var src := load(chemins[idx]) as Ennemi
	var copie: Ennemi = src.duplicate(true) as Ennemi
	var extra: int = maxi(0, n - 1 - idx)
	copie.pv_max += extra * 4
	copie.degats_riposte += extra
	if extra > 0 and copie.a_un_de():
		var nouvelles_faces: Array[Face] = []
		for f in copie.faces:
			var f_copie: Face = f.dupliquer()
			if f_copie.attaque > 0:
				f_copie.attaque += extra
			nouvelles_faces.append(f_copie)
		copie.faces = nouvelles_faces
	if extra > 0:
		copie.nom = "%s (salle %d)" % [src.nom, n]
	return copie


func _reinitialiser_stock() -> void:
	stock.clear()
	for offre in catalogue():
		stock[offre.id] = offre.stock_max
