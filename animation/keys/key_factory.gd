# KeyFactory -- Creates, validates, and inserts keyframes into tracks
# ANM-005: Implement key creation and auto-key
class_name KeyFactory
extends RefCounted

const KeyframeDataScript = preload("res://animation/keys/keyframe_schema.gd")

## ID provider callback. Assign a Callable(id_prefix:String)->String to inject
## the project's IDService; falls back to a simple counter-based scheme.
var id_provider: Callable = Callable()

var _counter: int = 0


func _init(provider: Callable = Callable()) -> void:
	id_provider = provider


## Generate a unique key ID.
func _generate_id(prefix: String = "key") -> String:
	if id_provider.is_valid():
		return id_provider.call(prefix)
	_counter += 1
	return "%s_%d" % [prefix, _counter]


## Create a new KeyframeData and insert it into the track's key array.
## Replaces an existing key at the same time (within epsilon).
## Returns the key dictionary that was inserted.
## track: any object with a .keys Array and .track_type property.
func create_key(track, time: float, value: Variant, interp: int = 1) -> Dictionary:
	if track == null:
		push_error("KeyFactory.create_key: track is null")
		return {}
	if time < 0.0:
		push_error("KeyFactory.create_key: time must be >= 0")
		return {}
	# Remove any existing key within 0.0001 s of the target time.
	const EPSILON := 0.0001
	track.keys = track.keys.filter(func(k): return absf(float(k.get("time", -1.0)) - time) > EPSILON)

	var k = KeyframeDataScript.new(_generate_id(), time, value)
	k.interpolation = interp
	var kd := k.to_dict()
	track.keys.append(kd)
	return kd


## Insert a key only if no existing key is within epsilon of the given time.
## Returns the existing key dict if one was found, or the new key dict.
func create_key_no_overwrite(track, time: float, value: Variant, interp: int = 1) -> Dictionary:
	const EPSILON := 0.0001
	for k in track.keys:
		if absf(float(k.get("time", -1.0)) - time) <= EPSILON:
			return k
	return create_key(track, time, value, interp)


## Validate a candidate key against a track. Returns Array of error strings.
static func validate_key(track, time: float, value: Variant) -> Array:
	var errors: Array = []
	if track == null:
		errors.append("track is null")
		return errors
	if time < 0.0:
		errors.append("key time must be >= 0")
	return errors
