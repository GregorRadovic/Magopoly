extends Node2D
class_name BoardSpace

@export var index: int = 0:
	set(value):
		index = value
		_update_label()

@export var label_text: String = "":
	set(value):
		label_text = value
		_update_label()

@onready var label: Label = $IndexLabel


func _ready() -> void:
	_update_label()


func _update_label() -> void:
	if label:
		label.text = label_text if label_text != "" else str(index)
