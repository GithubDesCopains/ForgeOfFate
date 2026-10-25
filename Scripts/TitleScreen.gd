class_name TitleScreen
extends Control

@onready var _bouton: Button = $Marge/VBox/BoutonNouvelle


func _ready() -> void:
	_bouton.pressed.connect(_on_nouvelle)


func _on_nouvelle() -> void:
	EtatPartie.nouvelle_partie()
