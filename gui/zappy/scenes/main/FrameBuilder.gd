extends Control

const CELL_SIZE   = 135
const TOTAL_CELLS = 8
const GRID_START  = 1
const GRID_END    = 6        # inclusive, 6 cells = 810px

const COLOR_A      = Color(0.0, 0.485, 0.0, 1.0)
const COLOR_B      = Color(0.0, 0.0, 0.485, 1.0)
const BORDER_COLOR = Color(0.856, 0.856, 0.856, 1.0)
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
			draw_rect(
			_build_rect_outline(row, col, 1, 1),
			BORDER_COLOR, true)
			draw_rect(_build_rect(row, col, 1, 1, cell_position.UNKNOWN),
			fill_color, true)
	
	fill_color = COLOR_A
	draw_rect(
	_build_rect_outline(TOTAL_CELLS - 1, 5, 3, 1),
	BORDER_COLOR, true)
	draw_rect(_build_rect(TOTAL_CELLS - 1, 5, 3, 1, cell_position.BR_CORNER),
	fill_color, true)
	
	draw_rect(
	_build_rect_outline(4, 0, 1, 3),
	BORDER_COLOR, true)
	draw_rect(_build_rect(4, 0, 1, 3, cell_position.LEFT),
	fill_color, true)

	# Pass 2: lines on top
	#for row in range(TOTAL_CELLS):
		#for col in range(TOTAL_CELLS):
			#if _is_grid(row, col):
				#continue
			#var x = col * CELL_SIZE
			#var y = row * CELL_SIZE
			#draw_line(Vector2(x, y),              Vector2(x + CELL_SIZE, y),              BORDER_COLOR, BORDER_WIDTH)
			#draw_line(Vector2(x, y + CELL_SIZE),  Vector2(x + CELL_SIZE, y + CELL_SIZE),  BORDER_COLOR, BORDER_WIDTH)
			#draw_line(Vector2(x, y),              Vector2(x, y + CELL_SIZE),              BORDER_COLOR, BORDER_WIDTH)
			#draw_line(Vector2(x + CELL_SIZE, y),  Vector2(x + CELL_SIZE, y + CELL_SIZE),  BORDER_COLOR, BORDER_WIDTH)

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
			rect = Rect2((col * CELL_SIZE) + BORDER_WIDTH, (row * CELL_SIZE) + BORDER_WIDTH, (CELL_SIZE * h_multiplier) - (BORDER_WIDTH * 1.5), (CELL_SIZE * v_multiplier) - (BORDER_WIDTH * 1.5))
		cell_position.TOP:
			rect = Rect2((col * CELL_SIZE) + (BORDER_WIDTH / 2), (row * CELL_SIZE) + BORDER_WIDTH, (CELL_SIZE * h_multiplier) - BORDER_WIDTH, (CELL_SIZE * v_multiplier) - (BORDER_WIDTH * 1.5))
		cell_position.TR_CORNER:
			rect = Rect2((col * CELL_SIZE) + (BORDER_WIDTH / 2), (row * CELL_SIZE) + BORDER_WIDTH, (CELL_SIZE * h_multiplier) - (BORDER_WIDTH * 1.5), (CELL_SIZE * v_multiplier) - (BORDER_WIDTH * 1.5))
		cell_position.RIGHT:
			rect = Rect2((col * CELL_SIZE) + (BORDER_WIDTH / 2), (row * CELL_SIZE) + (BORDER_WIDTH / 2), (CELL_SIZE * h_multiplier) - (BORDER_WIDTH * 1.5), (CELL_SIZE * v_multiplier) - BORDER_WIDTH)
		cell_position.BR_CORNER:
			rect = Rect2((col * CELL_SIZE) + (BORDER_WIDTH / 2), (row * CELL_SIZE) + (BORDER_WIDTH / 2), (CELL_SIZE * h_multiplier) - (BORDER_WIDTH * 1.5), (CELL_SIZE * v_multiplier) - (BORDER_WIDTH * 1.5))
		cell_position.BOTTOM:
			rect = Rect2((col * CELL_SIZE) + (BORDER_WIDTH / 2), (row * CELL_SIZE) + (BORDER_WIDTH / 2), (CELL_SIZE * h_multiplier) - BORDER_WIDTH, (CELL_SIZE * v_multiplier) - (BORDER_WIDTH * 1.5))
		cell_position.BL_CORNER:
			rect = Rect2((col * CELL_SIZE) + BORDER_WIDTH, (row * CELL_SIZE) + (BORDER_WIDTH / 2), (CELL_SIZE * h_multiplier) - (BORDER_WIDTH * 1.5), (CELL_SIZE * v_multiplier) - (BORDER_WIDTH * 1.5))
		cell_position.LEFT:
			rect = Rect2((col * CELL_SIZE) + BORDER_WIDTH, (row * CELL_SIZE) + (BORDER_WIDTH / 2), (CELL_SIZE * h_multiplier) - (BORDER_WIDTH * 1.5), (CELL_SIZE * v_multiplier) - BORDER_WIDTH)
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
	
