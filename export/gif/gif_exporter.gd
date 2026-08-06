# GifExporter -- Encodes animated GIF89a files from Image frames without external dependencies.
class_name GifExporter
extends RefCounted


func export_frames(frames: Array, output_path: String, fps: float = 24.0, loop_count: int = 0) -> Dictionary:
	if frames.is_empty():
		return {"success": false, "errors": ["at least one frame is required"]}
	var first: Image = (frames[0] as Dictionary).get("image")
	if first == null or first.is_empty():
		return {"success": false, "errors": ["first frame has no image"]}
	var size := first.get_size()
	var data := PackedByteArray()
	_append_text(data, "GIF89a")
	_append_u16(data, size.x)
	_append_u16(data, size.y)
	data.append(0xF7) # Global palette, 8-bit colour resolution and 256 entries.
	data.append(0)
	data.append(0)
	_append_palette(data)
	_append_loop_extension(data, loop_count)
	var delay := maxi(1, int(round(100.0 / maxf(fps, 0.001))))
	for frame in frames:
		var image: Image = (frame as Dictionary).get("image")
		if image == null or image.get_size() != size:
			return {"success": false, "errors": ["all GIF frames must have the same size"]}
		_append_graphics_control(data, delay)
		data.append_array([0x2C, 0, 0, 0, 0])
		_append_u16(data, size.x)
		_append_u16(data, size.y)
		data.append(0)
		data.append(8)
		_append_sub_blocks(data, _lzw_literals(_indexed_pixels(image)))
	data.append(0x3B)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir()) != OK:
		return {"success": false, "errors": ["cannot create GIF directory"]}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "errors": ["cannot write GIF"]}
	file.store_buffer(data)
	file.close()
	return {"success": true, "path": output_path, "frame_count": frames.size()}


func _append_palette(data: PackedByteArray) -> void:
	for index in range(256):
		data.append(int(float(index >> 5) / 7.0 * 255.0))
		data.append(int(float((index >> 2) & 7) / 7.0 * 255.0))
		data.append(int(float(index & 3) / 3.0 * 255.0))


func _indexed_pixels(image: Image) -> PackedByteArray:
	var pixels := PackedByteArray()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var colour := image.get_pixel(x, y)
			pixels.append((int(round(colour.r * 7.0)) << 5) | (int(round(colour.g * 7.0)) << 2) | int(round(colour.b * 3.0)))
	return pixels


func _lzw_literals(pixels: PackedByteArray) -> PackedByteArray:
	var codes := PackedInt32Array([256])
	for index in range(pixels.size()):
		if index > 0 and index % 200 == 0:
			codes.append(256)
		codes.append(pixels[index])
	codes.append(257)
	return _pack_9bit_codes(codes)


func _pack_9bit_codes(codes: PackedInt32Array) -> PackedByteArray:
	var bits := PackedByteArray()
	var accumulator := 0
	var bit_count := 0
	for code in codes:
		accumulator |= code << bit_count
		bit_count += 9
		while bit_count >= 8:
			bits.append(accumulator & 0xFF)
			accumulator >>= 8
			bit_count -= 8
	if bit_count > 0:
		bits.append(accumulator & 0xFF)
	return bits


func _append_loop_extension(data: PackedByteArray, loop_count: int) -> void:
	data.append_array([0x21, 0xFF, 0x0B])
	_append_text(data, "NETSCAPE2.0")
	data.append_array([0x03, 0x01])
	_append_u16(data, clampi(loop_count, 0, 65535))
	data.append(0)


func _append_graphics_control(data: PackedByteArray, delay: int) -> void:
	data.append_array([0x21, 0xF9, 0x04, 0x00])
	_append_u16(data, delay)
	data.append_array([0, 0])


func _append_sub_blocks(data: PackedByteArray, payload: PackedByteArray) -> void:
	var position := 0
	while position < payload.size():
		var count := mini(255, payload.size() - position)
		data.append(count)
		data.append_array(payload.slice(position, position + count))
		position += count
	data.append(0)


func _append_u16(data: PackedByteArray, value: int) -> void:
	data.append(value & 0xFF)
	data.append((value >> 8) & 0xFF)


func _append_text(data: PackedByteArray, value: String) -> void:
	data.append_array(value.to_ascii_buffer())
