extends Node

signal or_change(total: int)
signal eclats_change(total: int)
signal pv_joueur_change(pv_actuels: int, pv_max: int)
signal bouclier_change(valeur: int)

enum Phase { TITRE, COMBAT, FORGE, GAME_OVER, VICTOIRE_FINALE }

const SCENE_TITRE: String = "res://Scenes/Title.tscn"
const SCENE_COMBAT: String = "res://Scenes/Combat.tscn"
const SCENE_FORGE: String = "res://Scenes/Forge.tscn"
const CATALOGUE_FORGE: String = "res://Data/Forge/catalogue.tres"
const ForgeRules = preload("res://Scripts/Forge.gd")
const CHEMINS_ENNEMIS: PackedStringArray = [
	"res://Data/Ennemis/gobelin.tres",
	"res://Data/Ennemis/bandit.tres",
	"res://Data/Ennemis/ogre.tres",
]

const PV_MAX_JOUEUR: int = 15
const OR_DE_DEPART: int = 12
const ECLATS_DE_DEPART: int = 0
const SOIN_FORGE: int = 5
const TAILLE_OFFRE_FORGE: int = 6
var etages_max: int = 10
var boss_final_actif: bool = true

var phase: Phase = Phase.TITRE
var des_joueur: Array[De] = []
var or_total: int = OR_DE_DEPART
var eclats: int = ECLATS_DE_DEPART
var pv_joueur: int = PV_MAX_JOUEUR
var pv_max_joueur: int = PV_MAX_JOUEUR
var bouclier_joueur: int = 0
var etage: int = 1
var salles_gagnees: int = 0
var ennemi_actuel: Ennemi
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stock: Dictionary = {}
var offre_forge: Array[OffreForge] = []

var de_joueur: De:
	get:
		return des_joueur[0] if not des_joueur.is_empty() else null

var _forge_preparee: bool = false


func _ready() -> void:
	reinitialiser()


func reinitialiser() -> void:
	phase = Phase.TITRE
	rng.randomize()
	des_joueur = [De.new(), De.new()]
	or_total = OR_DE_DEPART
	eclats = ECLATS_DE_DEPART
	pv_joueur = PV_MAX_JOUEUR
	pv_max_joueur = PV_MAX_JOUEUR
	bouclier_joueur = 0
	etage = 1
	salles_gagnees = 0
	ennemi_actuel = ennemi_pour_etage(etage)
	offre_forge.clear()
	_forge_preparee = false
	_reinitialiser_stock()
	or_change.emit(or_total)
	eclats_change.emit(eclats)
	pv_joueur_change.emit(pv_joueur, pv_max_joueur)
	bouclier_change.emit(bouclier_joueur)


func nouvelle_partie() -> void:
	reinitialiser()
	phase = Phase.COMBAT
	get_tree().change_scene_to_file(SCENE_COMBAT)


func ajouter_or(montant: int) -> void:
	if montant > 0:
		or_total += montant
		or_change.emit(or_total)


func depenser_or(montant: int) -> bool:
	if montant <= 0 or montant > or_total:
		return false
	or_total -= montant
	or_change.emit(or_total)
	return true


func ajouter_eclats(montant: int) -> void:
	if montant > 0:
		eclats += montant
		eclats_change.emit(eclats)


func depenser_eclats(montant: int) -> bool:
	if montant <= 0 or montant > eclats:
		return false
	eclats -= montant
	eclats_change.emit(eclats)
	return true


func catalogue_forge() -> CatalogueForge:
	var catalogue := load(CATALOGUE_FORGE) as CatalogueForge
	if catalogue == null:
		push_error("Impossible de charger le catalogue de la Forge.")
	return catalogue


func stock_de(offre: OffreForge) -> int:
	if offre == null:
		return 0
	return int(stock.get(offre.id, 0))


func peut_acheter_offre(index_de: int, index_face: int, offre: OffreForge) -> bool:
	if phase != Phase.FORGE or offre == null or offre.face == null:
		return false
	if index_de < 0 or index_de >= des_joueur.size():
		return false
	if not offre_forge.has(offre):
		return false
	if offre.cout_or < 0 or offre.cout_eclats < 0:
		return false
	if offre.cout_or == 0 and offre.cout_eclats == 0:
		return false
	if stock_de(offre) <= 0:
		return false
	if offre.cout_or > or_total or offre.cout_eclats > eclats:
		return false

	var de_cible: De = des_joueur[index_de]
	return (
		de_cible != null
		and index_face >= 0
		and index_face < de_cible.faces.size()
	)


func regenerer_offre() -> void:
	var catalogue := catalogue_forge()
	if catalogue == null:
		offre_forge.clear()
		return
	offre_forge = ForgeRules.tirer_offre(
		catalogue,
		etage,
		rng,
		stock,
		TAILLE_OFFRE_FORGE
	)


func acheter_offre(index_de: int, index_face: int, offre: OffreForge) -> bool:
	if not peut_acheter_offre(index_de, index_face, offre):
		return false
	var de_cible: De = des_joueur[index_de]
	var face_nouvelle: De.Face = De.Face.depuis_donnees(offre.face)
	if not de_cible.remplacer_face(index_face, face_nouvelle):
		return false

	or_total -= offre.cout_or
	eclats -= offre.cout_eclats
	stock[offre.id] = stock_de(offre) - 1
	if offre.cout_or > 0:
		or_change.emit(or_total)
	if offre.cout_eclats > 0:
		eclats_change.emit(eclats)
	return true


func preparer_forge() -> bool:
	if phase != Phase.FORGE:
		return false
	if _forge_preparee:
		return true

	etage += 1
	ennemi_actuel = ennemi_pour_etage(etage)
	soigner_joueur(SOIN_FORGE)
	regenerer_offre()
	_forge_preparee = true
	return true


func fixer_pv_joueur(valeur: int) -> void:
	pv_joueur = clampi(valeur, 0, pv_max_joueur)
	pv_joueur_change.emit(pv_joueur, pv_max_joueur)


func perdre_pv(montant: int) -> int:
	if montant <= 0:
		return 0
	var pv_perdus: int = mini(montant, pv_joueur)
	fixer_pv_joueur(pv_joueur - pv_perdus)
	return pv_perdus


func soigner_joueur(montant: int) -> int:
	if montant <= 0:
		return 0
	var pv_soignes: int = mini(montant, pv_max_joueur - pv_joueur)
	fixer_pv_joueur(pv_joueur + pv_soignes)
	return pv_soignes


func fixer_bouclier_joueur(valeur: int) -> void:
	bouclier_joueur = maxi(0, valeur)
	bouclier_change.emit(bouclier_joueur)


func ajouter_bouclier(montant: int) -> void:
	if montant > 0:
		fixer_bouclier_joueur(bouclier_joueur + montant)


func absorber_bouclier(montant: int) -> int:
	if montant <= 0:
		return 0
	var absorbe: int = mini(montant, bouclier_joueur)
	fixer_bouclier_joueur(bouclier_joueur - absorbe)
	return absorbe


func commencer_combat() -> bool:
	if phase == Phase.GAME_OVER or phase == Phase.VICTOIRE_FINALE:
		return false
	if phase == Phase.COMBAT:
		return true
	phase = Phase.COMBAT
	fixer_bouclier_joueur(0)
	return true


func terminer_combat_victoire(
		or_salle: int,
		pv: int,
		bouclier: int,
		recompense_or: int = 0,
		recompense_eclats: int = 0,
		ennemi_est_boss: bool = false
) -> bool:
	if phase != Phase.COMBAT:
		return false
	fixer_pv_joueur(pv)
	fixer_bouclier_joueur(bouclier)
	ajouter_or(maxi(0, or_salle) + maxi(0, recompense_or))
	ajouter_eclats(recompense_eclats)
	salles_gagnees += 1
	if boss_final_actif and ennemi_est_boss and etage >= etages_max:
		phase = Phase.VICTOIRE_FINALE
	else:
		phase = Phase.FORGE
	return true


func aller_a_forge() -> void:
	if not preparer_forge():
		return
	get_tree().change_scene_to_file(SCENE_FORGE)


func aller_au_combat() -> void:
	if phase != Phase.FORGE:
		return
	if not commencer_combat():
		return
	offre_forge.clear()
	_forge_preparee = false
	get_tree().change_scene_to_file(SCENE_COMBAT)


func defaite() -> void:
	if phase != Phase.COMBAT:
		return
	phase = Phase.GAME_OVER


func titre_disponible() -> bool:
	if not ResourceLoader.exists(SCENE_TITRE):
		return false
	return load(SCENE_TITRE) is PackedScene


func retour_titre() -> bool:
	if not titre_disponible():
		return false
	var erreur: Error = get_tree().change_scene_to_file(SCENE_TITRE)
	if erreur != OK:
		push_error("Impossible d'ouvrir la scène titre : %s" % error_string(erreur))
		return false
	phase = Phase.TITRE
	return true


func ennemi_pour_etage(numero_etage: int) -> Ennemi:
	if numero_etage < 1:
		push_error("Le numéro d'étage doit être supérieur ou égal à 1.")
		return null
	var index_base: int = clampi((numero_etage - 1) / 3, 0, CHEMINS_ENNEMIS.size() - 1)
	var ennemi_source := load(CHEMINS_ENNEMIS[index_base]) as Ennemi
	if ennemi_source == null:
		push_error("Impossible de charger l'ennemi de l'étage %d." % numero_etage)
		return null

	var copie := ennemi_source.duplicate(true) as Ennemi
	var rang: int = (numero_etage - 1) % 3
	copie.pv_max += numero_etage * 2
	copie.degats_riposte = maxi(1, 1 + (numero_etage / 3))

	copie.est_boss = numero_etage == etages_max
	if copie.est_boss:
		copie.pv_max = 40
		copie.degats_riposte = 4
		copie.nom = "☠ Seigneur des Dés"
		copie.recompense_or = 15
		copie.recompense_eclats = 5
		return copie

	if rang > 0 and copie.a_un_de():
		var faces_ameliorees: Array[FaceData] = []
		for face in copie.faces:
			var face_copie := face.dupliquer()
			if face_copie.attaque > 0:
				face_copie.attaque += rang
			faces_ameliorees.append(face_copie)
		copie.faces = faces_ameliorees
	if numero_etage > 1:
		copie.nom = "%s (salle %d)" % [ennemi_source.nom, numero_etage]
	return copie


func _reinitialiser_stock() -> void:
	stock.clear()
	var catalogue := catalogue_forge()
	if catalogue == null:
		return
	for offre in catalogue.offres:
		stock[offre.id] = offre.stock_max
