extends Node

var file_path = "res://TestFiles/TestAutotileTool.png"
var output_folder_path = "res://Output/"

export var tile_size := Vector2(32, 16)
export var autotile_nb_tiles := Vector2(5, 9)
export var empty_tile_pos := Vector2(128, 0)

onready var half_tile = tile_size / 2
onready var quarter_tile = tile_size / 4

var src_img : Image
var output_img : Image

var sides_rect_array := Array()
var corner_rect_array := Array()

#### ACCESSORS ####


#### BUILT-IN ####

func _ready() -> void:
	generate_autotile(file_path)


#### VIRTUALS ####



#### LOGIC ####


func generate_autotile(path: String) -> void:
	src_img = Image.new()
	src_img.load(path)
	var src_image_rect = src_img.get_used_rect()
	var src_file_name = get_file_name(path)
	
	# Fetch the rect of the sides and  
	sides_rect_array = _fetch_sides()
	corner_rect_array = _fetch_corners()
	
	output_img = Image.new()
	var output_size = tile_size * autotile_nb_tiles
	
	# Copie the source image
	output_img.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	output_img.blit_rect(src_img, src_image_rect, Vector2.ZERO)
	
	# Place 2 sides tiles
	_place_base_tile(tile_size * Vector2(0, 2), Vector2(2, 2))
	_place_sides(tile_size * Vector2(0, 2), Vector2(2, 2), 2)
	
	# Place 3 sides tiles
	_place_base_tile(tile_size * Vector2(2, 2), Vector2(2, 2))
	_place_sides(tile_size * Vector2(2, 2), Vector2(2, 2), 3)
	
	# Place 2 sides and 1 corner tiles
	_place_base_tile(tile_size * Vector2(0, 4), Vector2(2, 2))
	_place_sides(tile_size * Vector2(0, 4), Vector2(2, 2), 2)
	_place_corners(tile_size * Vector2(0, 4), Vector2(2, 2), [1, 3, 0, 2])
	
	# Place the 4 sides tile 
	_place_base_tile(tile_size * Vector2(4, 1), Vector2(1, 1))
	_place_sides(tile_size * Vector2(4, 1), Vector2(1, 1), 4)
	
	# Place the 2 sides parallel tile
	_place_base_tile(tile_size * Vector2(4, 2), Vector2(1, 2))
	_place_sides(tile_size * Vector2(4, 2), Vector2(1, 2), 2, true)
	
	# Place the 2 corners sides
	_place_base_tile(tile_size * Vector2(2, 4), Vector2(3, 2))
	_place_corners(tile_size * Vector2(2, 4), Vector2(3, 2), [0, 2, 1, 3, 2, 0])
	_place_corners(tile_size * Vector2(2, 4), Vector2(3, 2), [2, 1, 3, 0, 3, 1])
	
	# Place the 1 side 1 corner
	_place_base_tile(tile_size * Vector2(0, 6), Vector2(4, 2))
	_place_sides(tile_size * Vector2(0, 6), Vector2(4, 2), 1)
	_place_corners(tile_size * Vector2(0, 6), Vector2(2, 2), [1, 0, 3, 3])
	_place_corners(tile_size * Vector2(2, 6), Vector2(2, 2), [0, 1, 2, 2])
	
	# Place the 3 corners tiles
	_place_base_tile(tile_size * Vector2(0, 7), Vector2(4, 1))
	_place_corners(tile_size * Vector2(0, 7), Vector2(4, 1), [0, 1, 2, 3])
	_place_corners(tile_size * Vector2(0, 7), Vector2(4, 1), [1, 2, 3, 0])
	_place_corners(tile_size * Vector2(0, 7), Vector2(4, 1), [2, 3, 0, 1])
	
	# place the 4 corners tiles
	_place_base_tile(tile_size * Vector2(4, 6), Vector2(1, 1))
	for i in range(4):
		_place_corners(tile_size * Vector2(4, 6), Vector2(1, 1), [i])
	
	
	var __ = output_img.save_png(output_folder_path + src_file_name + "_output.png")


func _place_base_tile(origin: Vector2, nb_tiles: Vector2) -> void:
	for i in range(nb_tiles.y):
		for j in range(nb_tiles.x):
			output_img.blit_rect(src_img, Rect2(empty_tile_pos, tile_size), origin + Vector2(j, i) * tile_size)


func _place_sides(origin: Vector2, nb_tiles: Vector2, nb_sides: int, opposite: bool = false) -> void:
	var iter = 0
	for i in range(nb_tiles.y):
		for j in range(nb_tiles.x):
			for k in range(nb_sides):
				var side_id = wrapi(iter - k - (k * int(opposite)), 0, 4)
				var side_rect = sides_rect_array[side_id]
				var src_cell = _find_cell(side_id)
				var inside_cell_pos = _find_side_inside_cell_pos(src_cell)
				var cell_pos = Vector2(j, i) * tile_size
				var dest_pos = origin + cell_pos + inside_cell_pos
				output_img.blit_rect(src_img, side_rect, dest_pos)
			
			iter += 1


func _place_corners(origin: Vector2, nb_tiles:= Vector2(2, 2), corners_id_array = range(3)) -> void:
	var iter = 0
	for i in range(nb_tiles.y):
		for j in range(nb_tiles.x):
			var corner_id = corners_id_array[iter]
			var corner_rect = corner_rect_array[corner_id]
			var cell = Vector2(j, i)
			var corner_cell = _find_cell(corner_id)
			var inside_cell_pos = _find_corner_inside_cell_pos(corner_cell)
			var dest_pos = origin + (cell * tile_size) + inside_cell_pos
			output_img.blit_rect(src_img, corner_rect, dest_pos)
			iter += 1


func _find_cell(id: int) -> Vector2:
	return Vector2(_find_column(id), _find_line(id))


func _find_column(id: int) -> int:
	return id % 2


func _find_line(id: int) -> int:
	return int(float(id) / 2)


func _find_side_inside_cell_pos(cell_pos: Vector2) -> Vector2:
	var x = int(cell_pos.x) if cell_pos.y == 0 else int(!bool(cell_pos.x))
	return half_tile * Vector2(x, cell_pos.y)


func _find_corner_inside_cell_pos(cell_pos: Vector2) -> Vector2:
	if cell_pos.y == 0:
		return Vector2(cell_pos.x * (tile_size.x - quarter_tile.x),  half_tile.y - quarter_tile.y / 2)
	else:
		return Vector2(half_tile.x - quarter_tile.x / 2, cell_pos.x * (tile_size.y - quarter_tile.y))


func _fetch_sides() -> Array:
	var sides_array = []
	for i in range(2):
		for j in range(2):
			var cell_pos = Vector2(j, i)
			var tile_pos = tile_size * cell_pos
			var inside_tile_pos = _find_side_inside_cell_pos(cell_pos)
			var rect = Rect2(tile_pos + inside_tile_pos, half_tile)
			sides_array.append(rect)
	return sides_array


func _fetch_corners() -> Array:
	var sides_array = []
	var corner_origin = Vector2(2 * tile_size.x, 0)
	for i in range(2):
		for j in range(2):
			var cell = Vector2(j, i)
			var inside_cell_pos = _find_corner_inside_cell_pos(cell)
			var rect = Rect2(corner_origin + inside_cell_pos + cell * tile_size, quarter_tile)
			sides_array.append(rect)
	return sides_array


func get_file_name(path: String) -> String:
	var splitted_path = path.split("/")
	var file_name = splitted_path[-1]
	return file_name.split(".")[0]


#### INPUTS ####



#### SIGNAL RESPONSES ####
