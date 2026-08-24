extends Node

const SNAP_STEPS := 10
const MASTER_BUS := 0

var volume: int = 100 : set = set_volume

func set_volume(value: int) -> void:
	volume = clampi(value, 0, 100)
	# 0 volume → silence (−80 dB floor), 100 → 0 dB
	if volume == 0:
		AudioServer.set_bus_mute(MASTER_BUS, true)
	else:
		AudioServer.set_bus_mute(MASTER_BUS, false)
		AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(volume / 100.0))
