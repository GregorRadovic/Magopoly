extends PopupPanel

# A near-bare zoom of a spell's full art -- no panel background, no Close
# button (clicking anywhere outside dismisses it, like any popup).

const FALLBACK_SIZE: Vector2i = Vector2i(660, 920)

# Tallest the zoom may be.
var max_height: float = 950.0
# Tutorial: the y the card must stay above (the top of the tutorial's text
# box; 0 = no limit). The card then fits -- and is centred -- in the space
# above it, whatever the screen resolution. Set by main.gd.
var keep_above: float = 0.0
const KEEP_ABOVE_GAP: float = 14.0

@onready var icon_rect: TextureRect = $Root/IconRect


func show_card(icon: Texture2D) -> void:
	icon_rect.texture = icon
	var tex: Vector2 = Vector2(icon.get_size()) if icon != null else Vector2.ZERO
	if tex.x <= 0.0 or tex.y <= 0.0:
		popup_centered(FALLBACK_SIZE)
		return
	# Show it as tall as it'll comfortably fit, keeping the art's aspect.
	var vp: Vector2 = get_tree().root.get_visible_rect().size
	var target_h: float = minf(max_height, vp.y * 0.9)
	if keep_above > 0.0:
		target_h = minf(target_h, keep_above - 2.0 * KEEP_ABOVE_GAP)
	var target_w: float = target_h * tex.x / tex.y
	if keep_above > 0.0:
		var top: float = (keep_above - target_h) * 0.5
		popup(Rect2i(Vector2i(roundi((vp.x - target_w) * 0.5), roundi(top)), Vector2i(roundi(target_w), roundi(target_h))))
		return
	popup_centered(Vector2i(roundi(target_w), roundi(target_h)))
