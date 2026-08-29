extends PopupPanel

# A bare, borderless zoom of a spell's full art -- no panel background and no
# Close button (clicking anywhere outside dismisses it, like any popup).

const FALLBACK_SIZE: Vector2i = Vector2i(660, 920)

@onready var icon_rect: TextureRect = $IconRect


func show_card(icon: Texture2D) -> void:
	icon_rect.texture = icon
	var tex: Vector2 = Vector2(icon.get_size()) if icon != null else Vector2.ZERO
	if tex.x <= 0.0 or tex.y <= 0.0:
		popup_centered(FALLBACK_SIZE)
		return
	# Show it as tall as it'll comfortably fit, keeping the art's aspect.
	var target_h: float = minf(950.0, get_tree().root.get_visible_rect().size.y * 0.9)
	var target_w: float = target_h * tex.x / tex.y
	popup_centered(Vector2i(roundi(target_w), roundi(target_h)))
