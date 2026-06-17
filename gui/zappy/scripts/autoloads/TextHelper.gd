extends Node

# Text format helpers
func bold(string: String) -> String:
	var bold_text: String = "[b]" + string + "[/b]"
	return bold_text

func color(string: String, color: String) -> String:
	var colored_text = "[color=" + color + "]" + string + "[/color]"
	return colored_text

func size(string: String, font_size: int) -> String:
	var scaled_text = "[font_size={%d}]" % font_size + string + "[/font_size]"
	return scaled_text
	
func center(string: String) -> String:
	var centered_text = "[center]%s[/center]" % string
	return centered_text
