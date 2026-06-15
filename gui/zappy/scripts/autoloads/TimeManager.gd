extends Node

const TIME_STEPS := 10
const MIN_INTERVAL := 0.07  # fastest tick
const MAX_INTERVAL := 1.0   # slowest tick

signal time_value_changed(value: float)

func set_time_value(step: int) -> void:
	step = clamp(step, 0, TIME_STEPS)
	var t := float(step) / float(TIME_STEPS)
	var interval := MAX_INTERVAL * pow(MIN_INTERVAL / MAX_INTERVAL, t)
	time_value_changed.emit(interval)
