class_name ClipState
extends RefCounted

## Clip lifecycle for one drop. Landing ends the clip until a teleport starts another.

enum State { READY, AIRBORNE, LANDED }

const DROP_LABELS: PackedStringArray = [
	"DROP 1 CATWALK 6M",
	"DROP 2 ATRIUM 14M",
	"DROP 3 TOWER 24M",
	"DROP 4 CRANE 38M",
]

var state: State = State.READY
var hits: int = 0
var shots: int = 0
var active_drop: int = 1

# Stay READY through the spawn frames before the body has touched the platform.
# Leaving the floor only starts the clip after that first contact.
var _saw_floor: bool = false


func reset_clip(drop_index: int) -> void:
	active_drop = drop_index
	state = State.READY
	hits = 0
	shots = 0
	_saw_floor = false


func note_floor(on_floor: bool) -> void:
	if state == State.READY:
		if on_floor:
			_saw_floor = true
		elif _saw_floor:
			state = State.AIRBORNE
	elif state == State.AIRBORNE:
		if on_floor:
			state = State.LANDED


func can_fire() -> bool:
	return state != State.LANDED


func register_shot() -> bool:
	if not can_fire():
		return false
	shots += 1
	return true


func register_target_hit(already_hit: bool) -> bool:
	if state == State.LANDED or already_hit:
		return false
	hits += 1
	return true


func status_text() -> String:
	match state:
		State.READY:
			return "CLIP READY"
		State.AIRBORNE:
			return "IN THE AIR"
		State.LANDED:
			return "CLIP OVER"
	return ""


func drop_label() -> String:
	var index := clampi(active_drop - 1, 0, DROP_LABELS.size() - 1)
	return DROP_LABELS[index]
