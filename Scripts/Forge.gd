class_name Forge
extends RefCounted


static func tirer_offre(
		catalogue: CatalogueForge,
		etage: int,
		rng: RandomNumberGenerator,
		stock: Dictionary,
		taille: int
) -> Array[OffreForge]:
	if catalogue == null or rng == null:
		push_error("La sélection d'offres nécessite un catalogue et un générateur valides.")
		return []

	var pool: Array[OffreForge] = []
	for offre in catalogue.offres:
		if offre.etage_min <= etage and int(stock.get(offre.id, 0)) > 0:
			pool.append(offre)

	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temporaire: OffreForge = pool[i]
		pool[i] = pool[j]
		pool[j] = temporaire

	var resultat: Array[OffreForge] = []
	for i in mini(maxi(0, taille), pool.size()):
		resultat.append(pool[i])
	return resultat


static func peut_acheter_offre(index_de: int, index_face: int, offre: OffreForge) -> bool:
	return EtatPartie.peut_acheter_offre(index_de, index_face, offre)


static func acheter_offre(index_de: int, index_face: int, offre: OffreForge) -> bool:
	return EtatPartie.acheter_offre(index_de, index_face, offre)
