class_name GameState
extends Node

signal state_changed(state: State)

enum State { PLAYING, VICTORY, DEFEAT }
var state: State = State.PLAYING

func _ready() -> void:
	add_to_group("game_state")

func set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)

func is_playing() -> bool:
	return state == State.PLAYING
