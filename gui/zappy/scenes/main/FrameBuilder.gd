extends Control

const CELL_SIZE   = 135
const TOTAL_CELLS = 8
const GRID_START  = 1
const GRID_END    = 6        # inclusive, 6 cells = 810px

const COLOR_A      = Color(0.0, 0.485, 0.0, 1.0)
const COLOR_B      = Color(0.0, 0.0, 0.485, 1.0)
const BORDER_COLOR = Color(0.0, 0.0, 0.0, 1.0)
const BORDER_WIDTH = 5.0

func _ready():
	_build_frame()

func _build_frame():
	queue_redraw()

func _draw():
	# Pass 1: filled cells
	for row in range(TOTAL_CELLS):
		for col in range(TOTAL_CELLS):
			if _is_grid(row, col):
				continue
			var color = COLOR_A if (row + col) % 2 == 0 else COLOR_B
			draw_rect(
			Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE),
			color, true  # filled = true
			)

	# Pass 2: lines on top
	for row in range(TOTAL_CELLS):
		for col in range(TOTAL_CELLS):
			if _is_grid(row, col):
				continue
			var x = col * CELL_SIZE
			var y = row * CELL_SIZE
			draw_line(Vector2(x, y),              Vector2(x + CELL_SIZE, y),              BORDER_COLOR, BORDER_WIDTH)
			draw_line(Vector2(x, y + CELL_SIZE),  Vector2(x + CELL_SIZE, y + CELL_SIZE),  BORDER_COLOR, BORDER_WIDTH)
			draw_line(Vector2(x, y),              Vector2(x, y + CELL_SIZE),              BORDER_COLOR, BORDER_WIDTH)
			draw_line(Vector2(x + CELL_SIZE, y),  Vector2(x + CELL_SIZE, y + CELL_SIZE),  BORDER_COLOR, BORDER_WIDTH)

func _is_grid(row: int, col: int) -> bool:
	return row >= GRID_START and row <= GRID_END \
	   and col >= GRID_START and col <= GRID_END
