class_name Forge
extends RefCounted

## Règles de boutique : filtre d'étage, stock, offre rotative.


static func tirer_offre(
		etage: int,
		rng: RandomNumberGenerator,
		stock: Dictionary,
		taille: int
) -> Array[OffreForge]:
	var pool: Array[OffreForge] = []
	for offre in EtatPartie.catalogue():
		if offre.etage_min <= etage and int(stock.get(offre.id, 0)) > 0:
			pool.append(offre)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: OffreForge = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var n: int = mini(taille, pool.size())
	var resultat: Array[OffreForge] = []
	for k in n:
		resultat.append(pool[k])
	return resultat
