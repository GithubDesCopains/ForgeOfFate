class_name Face
extends Resource

## Face de dé sérialisable (.tres) : effets de base + un effet spécial optionnel.

enum Type { ATTAQUE, DEFENSE, OR, SOIN }
enum Special { AUCUN, DEGATS_DOUBLES_SI_BOUCLIER, OR_SI_PRECEDENT_OR, POISON, RELANCER }

@export var attaque: int = 0
@export var defense: int = 0
@export var or_gain: int = 0
@export var soin: int = 0
@export var special: Special = Special.AUCUN


func valeur_de(type_effet: Type) -> int:
	match type_effet:
		Type.ATTAQUE:
			return attaque
		Type.DEFENSE:
			return defense
		Type.OR:
			return or_gain
		Type.SOIN:
			return soin
	return 0


func a_or() -> bool:
	return or_gain > 0


func dupliquer() -> Face:
	return duplicate() as Face


static func simple(type_effet: Type, valeur: int) -> Face:
	var face := Face.new()
	match type_effet:
		Type.ATTAQUE:
			face.attaque = valeur
		Type.DEFENSE:
			face.defense = valeur
		Type.OR:
			face.or_gain = valeur
		Type.SOIN:
			face.soin = valeur
	return face


static func combinee(effets_voulus: Dictionary) -> Face:
	var face := Face.new()
	for type_effet in effets_voulus:
		var valeur: int = effets_voulus[type_effet]
		match type_effet:
			Type.ATTAQUE:
				face.attaque = valeur
			Type.DEFENSE:
				face.defense = valeur
			Type.OR:
				face.or_gain = valeur
			Type.SOIN:
				face.soin = valeur
	return face


static func nom_type(type_effet: Type) -> String:
	match type_effet:
		Type.ATTAQUE:
			return "Attaque"
		Type.DEFENSE:
			return "Défense"
		Type.OR:
			return "Or"
		Type.SOIN:
			return "Soin"
	return "?"


static func nom_special(special_effet: Special) -> String:
	match special_effet:
		Special.DEGATS_DOUBLES_SI_BOUCLIER:
			return "Dégâts x2 si bouclier"
		Special.OR_SI_PRECEDENT_OR:
			return "Or x2 si Or avant"
		Special.POISON:
			return "Poison"
		Special.RELANCER:
			return "Relancer"
	return ""


func _to_string() -> String:
	var morceaux: PackedStringArray = []
	for type_effet in [Type.ATTAQUE, Type.DEFENSE, Type.OR, Type.SOIN]:
		var valeur: int = valeur_de(type_effet)
		if valeur != 0:
			morceaux.append("%s +%d" % [nom_type(type_effet), valeur])
	if special != Special.AUCUN:
		morceaux.append(nom_special(special))
	if morceaux.is_empty():
		return "(face vide)"
	return ", ".join(morceaux)
