extends Control

# End-of-game popup: who won, what this player earned, and an experience bar
# that fills up by that amount -- rolling over (with a "Level up!") each time
# it crosses into a new level. Experience is in half-levels (see saves.gd).
# Also reused, without animating, by the Player Profile screen's level bar.

signal closed

const FILL_SECONDS_PER_LEVEL: float = 1.1

@onready var title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var result_label: Label = $Center/Panel/Margin/VBox/ResultLabel
@onready var level_label: Label = $Center/Panel/Margin/VBox/BarRow/LevelLabel
@onready var next_label: Label = $Center/Panel/Margin/VBox/BarRow/NextLabel
@onready var bar: ProgressBar = $Center/Panel/Margin/VBox/BarRow/Bar
@onready var level_up_label: Label = $Center/Panel/Margin/VBox/LevelUpLabel
@onready var unlock_label: Label = $Center/Panel/Margin/VBox/UnlockLabel
@onready var continue_button: Button = $Center/Panel/Margin/VBox/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(func() -> void:
		hide()
		closed.emit())


# title: e.g. "Player 1 wins!". won: true / false / null (shared hotseat).
func show_award(title: String, won: Variant, xp_before: int, xp_after: int) -> void:
	title_label.text = title
	var gained: int = xp_after - xp_before
	var amount: String = "+1 level" if gained == 2 else ("+½ level" if gained == 1 else "+%s levels" % (gained / 2.0))
	if won == true:
		result_label.text = "Victory!  %s" % amount
	elif won == false:
		result_label.text = "Good game!  %s" % amount
	else:
		result_label.text = "Game finished!  %s" % amount
	level_up_label.visible = false
	unlock_label.visible = false
	continue_button.disabled = true
	_set_level(Saves.level_of(xp_before))
	bar.value = Saves.level_progress(xp_before)
	show()
	await _animate(xp_before, xp_after)
	continue_button.disabled = false
	continue_button.grab_focus()


func _set_level(level: int) -> void:
	level_label.text = "Level %d" % level
	next_label.text = "Level %d" % (level + 1)


func _animate(xp_from: int, xp_to: int) -> void:
	await get_tree().create_timer(0.5).timeout
	var current: int = xp_from
	var start_level: int = Saves.level_of(xp_from)
	while current < xp_to:
		var level: int = Saves.level_of(current)
		var boundary: int = (level + 1) * 2
		var target: int = mini(xp_to, boundary)
		var end_value: float = 1.0 if target == boundary else Saves.level_progress(target)
		var tween := create_tween()
		tween.tween_property(bar, "value", end_value, FILL_SECONDS_PER_LEVEL * (end_value - bar.value)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
		current = target
		if target == boundary:
			# Reached a new level. Roll the bar over only if there's more
			# experience to show past it; otherwise leave it full.
			await get_tree().create_timer(0.25).timeout
			if current < xp_to:
				_set_level(level + 1)
				bar.value = 0.0
			level_up_label.text = "Level up!  You're now level %d." % (level + 1)
			level_up_label.visible = true
			await get_tree().process_frame  # let it lay out before reading its size
			var pop := create_tween()
			level_up_label.pivot_offset = level_up_label.size / 2.0
			level_up_label.scale = Vector2(0.6, 0.6)
			pop.tween_property(level_up_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var new_unlocks: Array[Dictionary] = Saves.unlocks_between(start_level, Saves.level_of(xp_to))
	if not new_unlocks.is_empty():
		var names: Array[String] = []
		for u in new_unlocks:
			names.append(str(u["name"]))
		unlock_label.text = "Unlocked: %s" % ", ".join(names)
		unlock_label.visible = true
