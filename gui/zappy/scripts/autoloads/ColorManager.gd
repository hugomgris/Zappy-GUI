extends Node

const SNAP_STEPS := 10

signal ink_shimmer_changed(value: float)

func set_ink_shimmer(value: float) -> void:
	ink_shimmer_changed.emit(value)
