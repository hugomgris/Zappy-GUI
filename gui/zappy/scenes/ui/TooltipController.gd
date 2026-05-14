extends Panel

@export_multiline var tile_text_labels_1: String = ""

var labels: Dictionary = {}

func _ready() -> void:
	_get_labels()
	
func _get_labels() -> void:
	for i in range(get_child_count()):
		var child := get_child(i)
		if (child is RichTextLabel):
			labels[child.name] = child
			
	return

func populate(data: GameData.TileState) -> void:
	var label = labels["Position"] as RichTextLabel
	if not label:
		print("no label papa")
	
	label.text = tile_text_labels_1.replacen("*", "un saludo")
	
	return
