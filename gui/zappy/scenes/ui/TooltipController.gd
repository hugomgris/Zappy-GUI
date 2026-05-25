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
	var position_label: RichTextLabel = labels["Position"]
	if not position_label:
		push_warning("TooltipController: Failed to find requested label for 'position_label'")
		return
	
	var pos_string = str(data.pos)
	var fed_text = "Position: " + pos_string
	position_label.text = tile_text_labels_1.replacen("*", fed_text)
	
	
	return
