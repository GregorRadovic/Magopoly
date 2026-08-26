extends PopupPanel

const CARD_SIZE: Vector2i = Vector2i(400, 620)

@onready var icon_rect: TextureRect = $VBox/IconRect
@onready var close_button: Button = $VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)


func show_card(icon: Texture2D) -> void:
	icon_rect.texture = icon
	popup_centered(CARD_SIZE)
