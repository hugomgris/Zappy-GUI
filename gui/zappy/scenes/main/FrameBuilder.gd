extends Control

const CELL_SIZE   = 135
const TOTAL_CELLS = 8
const GRID_START  = 1
const GRID_END    = 6        # inclusive, 6 cells = 810px

const COLOR_A      = Color(0.0, 0.485, 0.0, 1.0)
const COLOR_B      = Color(0.0, 0.0, 0.485, 1.0)
const BORDER_COLOR = Color(0.854, 0.854, 0.854, 1.0)
const BORDER_WIDTH = 8.0

enum cell_position { UNKNOWN = -1, TL_CORNER = 0, TR_CORNER = 1, BR_CORNER = 2, BL_CORNER = 3, TOP = 4, RIGHT = 5, BOTTOM = 6, LEFT = 7}

func _ready():
	_build_frame()

func _build_frame():
	queue_redraw()

func _draw():
	var fill_color: Color
	
	for row in range(TOTAL_CELLS):
		for col in range(TOTAL_CELLS):
			if _is_grid(row, col):
				continue
				
			if _must_skip(row, col):
				continue
				
			fill_color = COLOR_A if (row + col) % 2 == 0 else COLOR_B
			draw_rect(_build_rect(row, col, 1, 1, cell_position.UNKNOWN), fill_color, true)
	
	fill_color = COLOR_A
	draw_rect(_build_rect(TOTAL_CELLS - 1, 5, 3, 1, cell_position.BR_CORNER),
	fill_color, true)
	draw_rect(_build_rect(4, 0, 1, 3, cell_position.LEFT), fill_color, true)
	
	# draw lines
	_draw_border_lines()

func _is_grid(row: int, col: int) -> bool:
	return row >= GRID_START and row <= GRID_END \
	   and col >= GRID_START and col <= GRID_END
	
func _must_skip(row: int, col: int) -> bool:
	if row == TOTAL_CELLS - 1 and (col >= TOTAL_CELLS - 3 and col <= TOTAL_CELLS - 1):
		return true
		
	if col == 0 and (row >= TOTAL_CELLS - 4 and row <= TOTAL_CELLS - 2):
		return true
	
	return false

func _build_rect_outline(row: int, col: int, h_multiplier: int, v_multiplier: int) -> Rect2:
	var rect : Rect2 = Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE * h_multiplier + 4, CELL_SIZE * v_multiplier +4)
	return rect;

func _build_rect(row: int, col: int, h_multiplier: int, v_multiplier: int, c_position: cell_position) -> Rect2:
	var rect := Rect2()
	if c_position == cell_position.UNKNOWN:
		c_position = _get_cell_position(row, col)
	match (c_position):
		cell_position.TL_CORNER:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		cell_position.TOP:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		cell_position.TR_CORNER:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		cell_position.RIGHT:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		cell_position.BR_CORNER:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		cell_position.BOTTOM:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		cell_position.BL_CORNER:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		cell_position.LEFT:
			rect = Rect2((col * CELL_SIZE), (row * CELL_SIZE), (CELL_SIZE * h_multiplier), (CELL_SIZE * v_multiplier))
		_:
			rect = Rect2(0,0,0,0)
	return rect

	
func _get_cell_position(row, col) -> cell_position:
	if row == 0 and col == 0:
		return cell_position.TL_CORNER
	elif row == 0 and col == TOTAL_CELLS - 1:
		return cell_position.TR_CORNER
	elif row == TOTAL_CELLS - 1 and col == TOTAL_CELLS - 1:
		return cell_position.BR_CORNER
	elif row == TOTAL_CELLS - 1 and col == 0:
		return cell_position.BL_CORNER
	elif row == 0 and (col >= 1 and col <= TOTAL_CELLS - 2):
		return cell_position.TOP
	elif (row >= 1 and row <= TOTAL_CELLS - 2) and col == TOTAL_CELLS - 1:
		return cell_position.RIGHT
	elif row == TOTAL_CELLS - 1 and (col >= 1 and col <= TOTAL_CELLS - 2):
		return cell_position.BOTTOM
	
	return cell_position.LEFT
	
func _draw_border_lines() -> void:
	# Left margin
	var v1_1 := Vector2(BORDER_WIDTH / 2, 0)
	var v1_2 := Vector2(BORDER_WIDTH / 2, CELL_SIZE * TOTAL_CELLS)
	draw_line(v1_1, v1_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	#Left inner
	var v2_1 := Vector2(CELL_SIZE + BORDER_WIDTH / 2, 0)
	var v2_2 := Vector2(CELL_SIZE + BORDER_WIDTH / 2, CELL_SIZE * TOTAL_CELLS)
	draw_line(v2_1, v2_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	# Right margin
	var v3_1 := Vector2(CELL_SIZE * TOTAL_CELLS - BORDER_WIDTH / 2, 0)
	var v3_2 := Vector2(CELL_SIZE * TOTAL_CELLS - BORDER_WIDTH / 2, CELL_SIZE * TOTAL_CELLS)
	draw_line(v3_1, v3_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	# Right inner
	var v4_1 := Vector2((CELL_SIZE * (TOTAL_CELLS - 1)) - BORDER_WIDTH / 2, 0)
	var v4_2 := Vector2((CELL_SIZE * (TOTAL_CELLS - 1)) - BORDER_WIDTH / 2, CELL_SIZE * (TOTAL_CELLS - 1))
	draw_line(v4_1, v4_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	# Top Margin
	var h1_1 := Vector2(0, BORDER_WIDTH / 2)
	var h1_2 := Vector2(CELL_SIZE * TOTAL_CELLS, BORDER_WIDTH / 2)
	draw_line(h1_1, h1_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	# Top Inner
	var h2_1 := Vector2(0, CELL_SIZE + BORDER_WIDTH / 2)
	var h2_2 := Vector2(CELL_SIZE * TOTAL_CELLS, CELL_SIZE + BORDER_WIDTH / 2)
	draw_line(h2_1, h2_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	# Bottom Margin
	var h3_1 := Vector2(0, CELL_SIZE * TOTAL_CELLS - BORDER_WIDTH / 2)
	var h3_2 := Vector2(CELL_SIZE * TOTAL_CELLS, CELL_SIZE * TOTAL_CELLS - BORDER_WIDTH / 2)
	draw_line(h3_1, h3_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	# Bottom inner
	var h4_1 := Vector2(0, (CELL_SIZE * (TOTAL_CELLS - 1)) - BORDER_WIDTH / 2)
	var h4_2 := Vector2(CELL_SIZE * TOTAL_CELLS, (CELL_SIZE * (TOTAL_CELLS - 1)) - BORDER_WIDTH / 2)
	draw_line(h4_1, h4_2, BORDER_COLOR, BORDER_WIDTH, false)
	
	# Divisors
	for i in range(5):
		# top
		draw_line(Vector2(CELL_SIZE * (i + 2), 0), Vector2(CELL_SIZE * (i + 2), CELL_SIZE), BORDER_COLOR, BORDER_WIDTH, false)
		# bottom
		if (i < 4):
			draw_line(Vector2(CELL_SIZE * (i + 2), CELL_SIZE * (TOTAL_CELLS - 1)), Vector2(CELL_SIZE * (i + 2), CELL_SIZE * TOTAL_CELLS), BORDER_COLOR, BORDER_WIDTH, false)
		# left
		if (i < 3):
			draw_line(Vector2(0, CELL_SIZE * (i + 2)), Vector2(CELL_SIZE, CELL_SIZE * (i + 2)), BORDER_COLOR, BORDER_WIDTH, false)
		# right
		draw_line(Vector2(CELL_SIZE * (TOTAL_CELLS - 1), CELL_SIZE * (i + 2)), Vector2(CELL_SIZE * TOTAL_CELLS, CELL_SIZE * (i + 2)), BORDER_COLOR, BORDER_WIDTH, false)
		
