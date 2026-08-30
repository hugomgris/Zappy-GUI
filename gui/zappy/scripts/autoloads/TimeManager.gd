extends Node

const TIME_STEPS := 10
const MIN_TIME_UNIT := 1
const MAX_TIME_UNIT := 100
const MIN_INTERVAL := 0.07  # fastest tick
const MAX_INTERVAL := 1.0   # slowest tick

signal time_value_changed(value: float)

func set_time_value(step: int) -> void:
	step = clamp(step, 0, TIME_STEPS)
	var t := float(step) / float(TIME_STEPS)
	var time_unit := int(round(lerp(float(MIN_TIME_UNIT), float(MAX_TIME_UNIT), t)))
	print("TIME STEP IS NOW ", step, " -> time_unit=", time_unit)
	time_value_changed.emit(time_unit)
