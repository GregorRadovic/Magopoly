extends Control

# Every spell card in the game, opened from the Start Menu's "Compendium"
# button. Cards are listed in SpellData.SPELLS order; right-click one to see
# it full size (the same spell_card popup used in-game). Back / Escape
# returns to the Start Menu.

const MINI_CARD_SCENE: PackedScene = preload("res://scenes/mini_spell_card.tscn")
# Matches the card art's aspect (mini_spell_card.tscn is 70 x 98).
const CARD_SIZE: Vector2 = Vector2(200, 280)

@onready var card_container: HFlowContainer = $Margin/VBox/CardScroll/CardContainer
@onready var count_label: Label = $Margin/VBox/Header/CountLabel
@onready var back_button: Button = $Margin/VBox/Header/BackButton
@onready var spell_card: PopupPanel = $SpellCard


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	var count: int = 0
	for spell_name in SpellData.SPELLS:
		var icon_path: String = str(SpellData.SPELLS[spell_name].get("icon", ""))
		if icon_path == "" or not ResourceLoader.exists(icon_path):
			continue
		var icon: Texture2D = load(icon_path)
		var mini: Control = MINI_CARD_SCENE.instantiate()
		mini.custom_minimum_size = CARD_SIZE
		mini.tooltip_text = spell_name
		card_container.add_child(mini)
		# setup() after add_child so the mini's @onready refs are ready.
		mini.setup(count, icon)
		mini.card_right_clicked.connect(func(_i: int) -> void: spell_card.show_card(icon))
		count += 1
	count_label.text = "%d cards  ·  Right-click a card to zoom in" % count


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not spell_card.visible:
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
