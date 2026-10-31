extends Control

@onready var _titre: Label = $CenterContainer/Panel/Marge/VBox/Titre
@onready var _message: Label = $CenterContainer/Panel/Marge/VBox/Message
@onready var _bouton_nouvelle_partie: Button = (
	$CenterContainer/Panel/Marge/VBox/NouvellePartie
)
@onready var _bouton_titre: Button = $CenterContainer/Panel/Marge/VBox/RetourTitre


func _ready() -> void:
	if EtatPartie.phase != EtatPartie.Phase.VICTOIRE_FINALE:
		_titre.text = "Écran indisponible"
		_message.text = "La victoire finale n'a pas été enregistrée."
		_bouton_nouvelle_partie.disabled = true
		_bouton_titre.disabled = true
		return

	_bouton_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	_configurer_bouton_titre()


func _configurer_bouton_titre() -> void:
	_bouton_titre.disabled = not EtatPartie.titre_disponible()
	if _bouton_titre.disabled:
		_bouton_titre.tooltip_text = "L'écran titre sera ajouté dans une mission ultérieure."
		return
	_bouton_titre.pressed.connect(_on_retour_titre)


func _on_nouvelle_partie() -> void:
	EtatPartie.nouvelle_partie()


func _on_retour_titre() -> void:
	if not EtatPartie.retour_titre():
		_bouton_titre.disabled = true
		_bouton_titre.tooltip_text = "L'écran titre n'est pas disponible."
