extends Control

const TITRE_JEU: String = "Forged by Fate"

@export var illustration_fond: Texture2D

@onready var _illustration: TextureRect = $Illustration
@onready var _titre: Label = $MenuPanel/Marge/Menu/Titre
@onready var _message: Label = $MenuPanel/Marge/Menu/Message
@onready var _continuer: Button = $MenuPanel/Marge/Menu/Continuer
@onready var _options: Button = $MenuPanel/Marge/Menu/Options
@onready var _nouvelle_partie: Button = $MenuPanel/Marge/Menu/NouvellePartie
@onready var _quitter: Button = $MenuPanel/Marge/Menu/Quitter
@onready var _asset_notice: Label = $AssetNotice


func _ready() -> void:
	_titre.text = TITRE_JEU
	_illustration.texture = illustration_fond
	_asset_notice.visible = illustration_fond == null
	_continuer.disabled = true
	_options.pressed.connect(_on_options)
	_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	_quitter.pressed.connect(_on_quitter)


func _on_options() -> void:
	_message.text = "Les options seront ajoutées dans une mission ultérieure."


func _on_nouvelle_partie() -> void:
	EtatPartie.nouvelle_partie()


func _on_quitter() -> void:
	get_tree().quit()
