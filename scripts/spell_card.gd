extends PopupPanel

# A near-bare zoom of a spell's full art -- no panel background, no Close
# button (clicking anywhere outside dismisses it, like any popup). When the
# zoomed card is one the local player owns, a "Reveal / Hide…" button is shown
# over the bottom of the art (see main.gd's _on_spell_right_clicked).

signal reveal_pressed(owner_id: int, hand_index: int)

const FALLBACK_SIZE: Vector2i = Vector2i(660, 920)

@onready var icon_rect: TextureRect = $Root/IconRect
@onready var reveal_button: Button = $Root/RevealButton

var _owner_id: int = -1
var _hand_index: int = -1


func _ready() -> void:
	reveal_button.pressed.connect(_on_reveal_pressed)


# owner_id >= 0 (paired with hand_index) shows the reveal button; the
# picker-driven zoom path (card_picker) leaves them -1 for a plain image.
func show_card(icon: Texture2D, owner_id: int = -1, hand_index: int = -1) -> void:
	icon_rect.texture = icon
	_owner_id = owner_id
	_hand_index = hand_index
	reveal_button.visible = owner_id >= 0
	var tex: Vector2 = Vector2(icon.get_size()) if icon != null else Vector2.ZERO
	if tex.x <= 0.0 or tex.y <= 0.0:
		popup_centered(FALLBACK_SIZE)
		return
	# Show it as tall as it'll comfortably fit, keeping the art's aspect.
	var target_h: float = minf(950.0, get_tree().root.get_visible_rect().size.y * 0.9)
	var target_w: float = target_h * tex.x / tex.y
	popup_centered(Vector2i(roundi(target_w), roundi(target_h)))


func _on_reveal_pressed() -> void:
	var oid: int = _owner_id
	var hi: int = _hand_index
	hide()
	reveal_pressed.emit(oid, hi)
