tool
extends EditorPlugin
class_name IsoAutotileImporter

onready var editor_interface = get_editor_interface()
onready var editor_file_system = editor_interface.get_resource_filesystem()

onready var file_dialogue_scene = load("res://addons/IsoAutotileGenerator/FileDialogue/FileDialog.tscn")
var tileset_template_path = "res://addons/IsoAutotileGenerator/TilesetTemplate/TilesetTemplate.tres" 

enum SUB_PART{
	CORNER,
	SIDE
}

var tile_size := Vector2(32, 16)
var autotile_nb_tiles := Vector2(5, 10)
var empty_tile_cell := Vector2(4, 0)

var half_tile = tile_size / 2
var quarter_tile = tile_size / 4

var src_img : Image
var output_img : Image

var sides_rect_array := Array()
var corner_rect_array := Array()

var last_path : String = ""

var handled_ext = ["png", "jpg", "jpeg"]

var file_dialogue : FileDialog = null
var button_dict : Dictionary = {}

var print_logs : bool = true

signal selected_path_changed(path)


#### ACCESSORS ####


#### BUILT-IN ####

func _ready() -> void:
	var __ = connect("selected_path_changed", self, "_on_selected_path_changed")


func _process(delta: float) -> void:
	var path = editor_interface.get_current_path()
	if last_path != path:
		emit_signal("selected_path_changed", path)
		last_path = path


func is_file(path: String) -> bool:
	var splitted_path = path.split("/")
	var last_elem = splitted_path[-1]
	return ".".is_subsequence_ofi(last_elem)


func is_file_type_handled(path) -> bool:
	var splitted_path = path.split(".")
	var last_elem = splitted_path[-1]
	return last_elem in handled_ext


func is_file_tileset(path: String) -> bool:
	var splitted_path = path.split(".")
	var last_elem = splitted_path[-1]
	if last_elem == "tres":
		var resource = load(path)
		return resource is TileSet
	return false


func create_button(button_name: String):
	var min_button_name = button_name.to_lower().replace(" ", "_")
	if button_dict.get(min_button_name) != null && \
		is_instance_valid(button_dict[min_button_name]):
		return
	
	var button = Button.new()
	button_dict[min_button_name] = button
	button.name = min_button_name
	button.text = button_name
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
	if print_logs:
		print("Button added: %s" % min_button_name)
	
	button.connect("pressed", self, "_on_button_%s_pressed" % min_button_name)


func destroy_button(button_name: String) -> void:
	var min_button_name = button_name.to_lower().replace(" ", "_")
	var button = button_dict.get(min_button_name)
	if button != null && is_instance_valid(button):
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, button)
		button.queue_free()
		button_dict.erase(min_button_name)
		
		if print_logs:
			print("button destroyed: %s" % min_button_name)


#### VIRTUALS ####


#### LOGIC ####


func generate_autotile(file_path: String, output_path: String) -> void:
	src_img = Image.new()
	src_img.load(file_path)
	var src_image_rect = src_img.get_used_rect()
	var src_file_name = get_file_name(file_path)

	# Fetch the rect of the sides and
	sides_rect_array = _fetch_subtexture_rect(SUB_PART.SIDE)
	corner_rect_array = _fetch_subtexture_rect(SUB_PART.CORNER)

	output_img = Image.new()
	var output_size = tile_size * autotile_nb_tiles

	# Copie the source image
	output_img.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	output_img.blit_rect(src_img, src_image_rect, Vector2.ZERO)
	
	_place_base_tile(tile_size * Vector2(0, 2), Vector2(5, 8))

	# Place 2 sides tiles
	_place_sides(tile_size * Vector2(0, 2), Vector2(2, 2), 2)

	# Place 3 sides tiles
	_place_sides(tile_size * Vector2(2, 2), Vector2(2, 2), 3)

	# Place 2 sides and 1 corner tiles
	_place_sides(tile_size * Vector2(0, 4), Vector2(2, 2), 2)
	_place_corners(tile_size * Vector2(0, 4), Vector2(2, 2), [1, 3, 0, 2])

	# Place the 4 sides tile
	_place_sides(tile_size * Vector2(4, 1), Vector2(1, 1), 4)

	# Place the 2 sides parallel tile
	_place_sides(tile_size * Vector2(4, 2), Vector2(1, 2), 2, true)

	# Place the 2 corners sides
	_place_corners(tile_size * Vector2(2, 4), Vector2(3, 2), [0, 2, 1, 3, 2, 0])
	_place_corners(tile_size * Vector2(2, 4), Vector2(3, 2), [2, 1, 3, 0, 3, 1])

	# Place the 1 side 1 corner
	_place_sides(tile_size * Vector2(0, 6), Vector2(4, 2), 1)
	_place_corners(tile_size * Vector2(0, 6), Vector2(2, 2), [1, 0, 3, 2])
	_place_corners(tile_size * Vector2(2, 6), Vector2(2, 2), [0, 1, 2, 3])
	
	# Place the 1 Side 2 corners
	_place_sides(tile_size * Vector2(0, 8), Vector2(4, 1), 1)
	_place_corners(tile_size * Vector2(0, 8), Vector2(4, 1), [1, 0, 0, 1])
	_place_corners(tile_size * Vector2(0, 8), Vector2(4, 1), [3, 3, 2, 2])
	
	# Place the 3 corners tiles
	for i in range(3):
		var corner_id_array = range_wrapi(i, 4, 0, 4)
		_place_corners(tile_size * Vector2(0, 9), Vector2(4, 1), corner_id_array)

	# place the 4 corners tiles
	for i in range(4):
		_place_corners(tile_size * Vector2(4, 6), Vector2(1, 1), [i])

	var output_file_path = output_path + src_file_name + "_output.png"
	var __ = output_img.save_png(output_file_path)
	editor_file_system.scan()


func _place_base_tile(origin: Vector2, nb_tiles: Vector2) -> void:
	var empty_tile_pos = empty_tile_cell * tile_size
	for i in range(nb_tiles.y):
		for j in range(nb_tiles.x):
			var cell_pos = Vector2(j, i) * tile_size
			output_img.blit_rect(src_img, Rect2(empty_tile_pos, tile_size), origin + cell_pos)


func _place_sides(origin: Vector2, nb_tiles: Vector2, nb_sides: int, opposite: bool = false) -> void:
	var iter = 0
	for i in range(nb_tiles.y):
		for j in range(nb_tiles.x):
			for k in range(nb_sides):
				var side_id = wrapi(iter - k - (k * int(opposite)), 0, 4)
				var side_rect = sides_rect_array[side_id]
				var src_cell = _find_cell(side_id)
				var inside_cell_pos = _find_inside_cell_pos(SUB_PART.SIDE, src_cell)
				var cell_pos = Vector2(j, i) * tile_size
				var dest_pos = origin + cell_pos + inside_cell_pos
				output_img.blit_rect(src_img, side_rect, dest_pos)

			iter += 1


func _place_corners(origin: Vector2, nb_tiles:= Vector2(2, 2), part_id_array = range(3)) -> void:
	var iter = 0
	for i in range(nb_tiles.y):
		for j in range(nb_tiles.x):
			var part_id = part_id_array[iter]
			var part_rect = part_id_array[part_id]
			var cell = Vector2(j, i)
			var part_cell = _find_cell(part_id)
			var inside_cell_pos = _find_inside_cell_pos(SUB_PART.CORNER, part_cell)
			var dest_pos = origin + (cell * tile_size) + inside_cell_pos
			output_img.blit_rect(src_img, part_rect, dest_pos)
			iter += 1


func range_wrapi(init_val: int, nb_values: int, min_val: int, max_val: int, increment: int = 1) -> Array:
	var range_array = range(0, nb_values, increment)
	var output_array = []
	for val in range_array:
		output_array.append(wrapi(init_val + val, min_val, max_val))
	
	return output_array


func _find_cell(id: int) -> Vector2:
	return Vector2(_find_column(id), _find_line(id))


func _find_column(id: int) -> int:
	return id % 2


func _find_line(id: int) -> int:
	return int(float(id) / 2)


func _find_inside_cell_pos(sub_part_type: int, cell_pos: Vector2) -> Vector2:
	if sub_part_type == SUB_PART.SIDE:
		var x = int(cell_pos.x) if cell_pos.y == 0 else int(!bool(cell_pos.x))
		return half_tile * Vector2(x, cell_pos.y)
	else:
		if cell_pos.y == 0:
			return Vector2(cell_pos.x * (tile_size.x - quarter_tile.x),  half_tile.y - quarter_tile.y / 2)
		else:
			return Vector2(half_tile.x - quarter_tile.x / 2, cell_pos.x * (tile_size.y - quarter_tile.y))


func add_autotile_to_tileset(tileset_path: String, texture_path: String):
	var tileset : TileSet = load(tileset_path)
	if print_logs && tileset != null:
		print("Tileset loaded from path %s" % tileset_path)
		
	var texture = load(texture_path)
	if print_logs && texture != null:
		print("Texture loaded from path %s" % texture_path)
	
	# Add the tile
	var tile_id = tileset.get_tiles_ids().size()
	tileset.create_tile(tile_id)
	tileset.tile_set_texture(tile_id, texture)
	tileset.tile_set_tile_mode(tile_id, TileSet.AUTO_TILE)
	tileset.tile_set_region(tile_id, Rect2(Vector2.ZERO, autotile_nb_tiles * tile_size))
	tileset.autotile_set_size(tile_id, tile_size)
	tileset.autotile_set_bitmask_mode(tile_id, TileSet.BITMASK_3X3_MINIMAL)
	tileset.autotile_set_icon_coordinate(tile_id, Vector2(4, 1))
	
	# Apply the bitmask
	var template : TileSet = load(tileset_template_path)
	for i in range(autotile_nb_tiles.y):
		for j in range(autotile_nb_tiles.x):
			var bitmask = template.autotile_get_bitmask(0, Vector2(j, i))
			tileset.autotile_set_bitmask(tile_id, Vector2(j, i), bitmask)
	
	# Overwrite the tileset file
	ResourceSaver.save(last_path, tileset)


func _fetch_subtexture_rect(sub_part_type: int) -> Array:
	var origin = Vector2(2 * tile_size.x, 0) if sub_part_type == SUB_PART.CORNER else Vector2.ZERO
	var subtexture_size = half_tile if sub_part_type == SUB_PART.SIDE else quarter_tile
	var part_array = []
	for i in range(2):
		for j in range(2):
			var cell_pos = Vector2(j, i)
			var tile_pos = tile_size * cell_pos
			var inside_tile_pos = _find_inside_cell_pos(sub_part_type, cell_pos)
			var rect = Rect2(origin + tile_pos + inside_tile_pos, subtexture_size)
			part_array.append(rect)
	return part_array


func get_file_name(path: String) -> String:
	var splitted_path = path.split("/")
	var file_name = splitted_path[-1]
	return file_name.split(".")[0]



func _instanciate_file_dialogue():
	file_dialogue = file_dialogue_scene.instance()
	file_dialogue.connect("file_selected", self, "_on_file_dialogue_file_selected")
	
	editor_interface.get_editor_viewport().add_child(file_dialogue)
	file_dialogue.set_current_dir(last_path.get_base_dir() + "/")
	file_dialogue.set_current_path(last_path.get_base_dir() + "/")
	file_dialogue.set_visible(true)
	file_dialogue.invalidate()


#### INPUTS ####



#### SIGNAL RESPONSES ####

func _on_selected_path_changed(path: String) -> void:
	if print_logs: 
		print("current path %s" % path)
	
	if is_file(path) && is_file_type_handled(path):
		create_button("Generate autotile")
	else:
		destroy_button("Generate autotile")
	
	if is_file(path) && is_file_tileset(path):
		print("Tileset handled")
		create_button("Add autotile texture")
	else:
		destroy_button("Add autotile texture")


func _on_button_generate_autotile_pressed() -> void:
	if print_logs:
		print("Autotile gen button pressed")
	
	generate_autotile(last_path, last_path.get_base_dir() + "/")


func _on_button_add_autotile_texture_pressed() -> void:
	if print_logs:
		print("Add autotile texture button pressed")
	
	_instanciate_file_dialogue()


func _on_file_dialogue_file_selected(texture_file_path: String) -> void:
	if is_file(texture_file_path) && is_file_type_handled(texture_file_path):
		if print_logs:
			print("")
		file_dialogue.queue_free()
		
		add_autotile_to_tileset(last_path, texture_file_path)
