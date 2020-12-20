extends ControlBase

# Controls for changing parts
onready var part_selector_scene: PackedScene = preload("res://assets/ui/submenus/appearance_editor/part_selector.tscn")

# Appearance editor nodes
onready var appearance_hbox: HBoxContainer = $MarginContainer/AppearanceHBox
onready var customization_vbox: VBoxContainer = appearance_hbox.get_node("CustomizationVBox")
onready var skin_color_selector: Control = customization_vbox.get_node("SkinColorSelector")
onready var skin_tone_range: TextureRect = skin_color_selector.get_node("SkinToneRange")
onready var skin_color_range: TextureRect = skin_color_selector.get_node("SkinColorRange")
onready var cursor: Sprite = skin_color_selector.get_node("Cursor")
onready var color_preview: ColorRect = cursor.get_node("ColorPreview")
onready var preview_buttons_vbox: VBoxContainer = appearance_hbox.get_node("PreviewButtonsVBox")
onready var player_container: CenterContainer = preview_buttons_vbox.get_node("PlayerContainer")
onready var buttons_hbox: HBoxContainer = preview_buttons_vbox.get_node("ButtonsHBox")
onready var root: Viewport = get_tree().get_root()

# Player preview nodes
onready var player_skeleton: Node2D = player_container.get_node("Skeleton")
onready var animator: AnimationPlayer = player_skeleton.get_node("AnimationPlayer")
onready var player_left_leg: Polygon2D
onready var player_left_arm: Polygon2D
onready var player_body: Polygon2D
onready var player_clothes: Sprite
onready var player_pants: Sprite
onready var player_facial_hair: Sprite
onready var player_face_wear: Sprite
onready var player_hat_hair: Sprite
onready var player_mouth: Sprite
onready var player_right_leg: Polygon2D
onready var player_right_arm: Polygon2D

signal appearance_saved

const player_data_path: String = "user://player_data.save"

export (String) var player_parts_prefix := "res://assets/player/textures/characters/customizable"
export (Array, String) var player_parts_directories := [
	"01-left-arm",
	"02-body",
	"03-mouth",
	"04-left-leg",
	"05-pants",
	"06-right-leg",
	"07-clothes",
	"08-right-arm",
	"09-facial-hair",
	"10-face-wear",
	"11-hat-hair",
]

var player_part_options: Dictionary = {
	"Clothes": [],
	"Body": [],
	"Facial Hair": [],
	"Face Wear": [],
	"Hat/Hair": [],
	"Mouth": [],
}
var current_customization: Dictionary = {
	"Skin Color": Color.white,
}
var part_selectors: Dictionary = {}
var player_data: Dictionary = {}

var viewport_texture_data: Image

class PlayerPart:
	var part_group: String
	var texture: Texture
	var texture_path: String

class PartOption:
	var part_name: String
	var part_texture: Texture
	var part_texture_path: String

class PlayerClothes extends PartOption:
	var left_leg: PartOption
	var left_arm: PartOption
	var right_leg: PartOption
	var right_arm: PartOption
	var clothes: PartOption
	var pants: PartOption

func _ready() -> void:
	get_tree().get_root().connect("size_changed", self, "_on_root_size_changed")
	if get_tree().get_root().has_node("Main"):
		connect("appearance_saved", get_tree().get_root().get_node("Main").get_node("appearance"), "_on_appearance_saved")

	# Center cursor in the middle of the skin color picker
	cursor.position = skin_color_selector.rect_position + (skin_color_selector.rect_size / 2.0)

	var player_parts_paths: Array = []
	for player_parts_directory in player_parts_directories:
		player_parts_paths.append(Helpers.string_join([player_parts_prefix, player_parts_directory], "/"))

	var player_parts: Array = []
	for path in player_parts_paths:
		var files: Array = Helpers.list_directory(path)
		for file in files:
			# Skip PNG files. We will instead be modifying the PNG import file
			# names because PNG resource files aren't saved on export.
			if file.ends_with("png"):
				continue
			var part_group: String = file.replace(".png.import", "")
			var texture_path: String = Helpers.string_join([path, part_group + ".png"], "/")
			var player_part := PlayerPart.new()
			player_part.part_group = part_group
			player_part.texture = load(texture_path)
			player_part.texture_path = texture_path
			player_parts.append(player_part)

	var grouped_player_parts: Dictionary = {}
	for part in player_parts:
		if grouped_player_parts.has(part.part_group):
			grouped_player_parts[part.part_group].append(part)
		else:
			grouped_player_parts[part.part_group] = [part]

	var part_options: Dictionary = {}
	for group in grouped_player_parts:
		# Player clothes are grouped together
		if len(grouped_player_parts[group]) > 1:
			var player_clothes := PlayerClothes.new()
			var part_group: Array = grouped_player_parts[group]
			for part in part_group:
				var part_option := PartOption.new()
				part_option.part_name = part.part_group
				part_option.part_texture = part.texture
				part_option.part_texture_path = part.texture_path
				if "left" in part.texture_path:
					if "arm" in part.texture_path:
						player_clothes.left_arm = part_option
					elif "leg" in part.texture_path:
						player_clothes.left_leg = part_option
				elif "right" in part.texture_path:
					if "arm" in part.texture_path:
						player_clothes.right_arm = part_option
					elif "leg" in part.texture_path:
						player_clothes.right_leg = part_option
				elif "clothes" in part.texture_path:
					player_clothes.clothes = part_option
					player_clothes.part_name = part.part_group
				elif "pants" in part.texture_path:
					player_clothes.pants = part_option
			player_part_options["Clothes"].append(player_clothes)
		else:
			var part_option := PartOption.new()
			var part: PlayerPart = grouped_player_parts[group][0]
			part_option.part_name = part.part_group
			part_option.part_texture = part.texture
			part_option.part_texture_path = part.texture_path
			if "body" in part.texture_path.to_lower():
				player_part_options["Body"].append(part_option)
			elif "facial" in part.texture_path.to_lower() and "hair" in part.texture_path.to_lower():
				player_part_options["Facial Hair"].append(part_option)
			elif "face" in part.texture_path.to_lower() and "wear" in part.texture_path.to_lower():
				player_part_options["Face Wear"].append(part_option)
			elif "hat" in part.texture_path.to_lower() and "hair" in part.texture_path.to_lower():
				player_part_options["Hat/Hair"].append(part_option)
			elif "mouth" in part.texture_path.to_lower():
				player_part_options["Mouth"].append(part_option)

	for part_option in player_part_options:
		current_customization[part_option] = player_part_options[part_option][0]
		var part_selector: HBoxContainer = part_selector_scene.instance()
		part_selector.get_node("PartLabel").text = part_option
		for part in player_part_options[part_option]:
			part_selector.parts.append(part.part_name)
		part_selector.get_node("CurrentPartLabel").text = part_selector.parts[0]
		part_selector.connect("part_changed", self, "_on_part_changed")
		customization_vbox.add_child(part_selector)
		part_selectors[part_option] = part_selector

	player_left_leg = player_skeleton.get_node("LeftLeg")
	player_left_arm = player_skeleton.get_node("LeftArm")
	player_body = player_skeleton.get_node("Body")
	player_right_leg = player_skeleton.get_node("RightLeg")
	player_right_arm = player_skeleton.get_node("RightArm")
	var spine: Bone2D = player_skeleton.get_node("Skeleton/Spine")
	player_clothes = spine.get_node("Clothes")
	player_pants = spine.get_node("Pants")
	player_facial_hair = spine.get_node("FacialHair")
	player_face_wear = spine.get_node("FaceWear")
	player_hat_hair = spine.get_node("HatHair")
	player_mouth = spine.get_node("Mouth")

func _choose_skin_color(coords: Vector2) -> void:
	"""Chooses the player's new skin color if the mouse is within the palette."""
	if coords.x > 1 and coords.x < skin_color_selector.rect_size.x - 1 and \
	   coords.y > 1 and coords.y < skin_color_selector.rect_size.y - 1:
		cursor.set_position(coords)
		color_preview.show()
		var viewport_coords: Vector2 = cursor.get_viewport_transform() * cursor.global_position
		if viewport_texture_data == null:
			viewport_texture_data = get_viewport().get_texture().get_data()
			viewport_texture_data.flip_y()
			viewport_texture_data.lock()
		var pixel_color: Color = viewport_texture_data.get_pixelv(viewport_coords)
		current_customization["Skin Color"] = pixel_color
		color_preview.color = pixel_color
		_update_preview()
	else:
		color_preview.hide()

func _update_preview() -> void:
	"""Updates the player preview with the currently selected customizations."""
	if player_skeleton.material.get_shader_param("skin_color") != current_customization["Skin Color"]:
		player_skeleton.material.set_shader_param("skin_color", current_customization["Skin Color"])
	var current_clothes: PlayerClothes = current_customization["Clothes"]
	if player_left_leg.texture.resource_path != current_clothes.left_leg.part_texture_path:
		player_left_leg.texture = current_clothes.left_leg.part_texture
		player_left_arm.texture = current_clothes.left_arm.part_texture
		player_right_leg.texture = current_clothes.right_leg.part_texture
		player_right_arm.texture = current_clothes.right_arm.part_texture
		player_clothes.texture = current_clothes.clothes.part_texture
		player_pants.texture = current_clothes.pants.part_texture
	if player_body.texture.resource_path != current_customization["Body"].part_texture_path:
		player_body.texture = current_customization["Body"].part_texture
	if player_facial_hair.texture.resource_path != current_customization["Facial Hair"].part_texture_path:
		player_facial_hair.texture = current_customization["Facial Hair"].part_texture
	if player_face_wear.texture.resource_path != current_customization["Face Wear"].part_texture_path:
		player_face_wear.texture = current_customization["Face Wear"].part_texture
	if player_hat_hair.texture.resource_path != current_customization["Hat/Hair"].part_texture_path:
		player_hat_hair.texture = current_customization["Hat/Hair"].part_texture
	if player_mouth.texture.resource_path != current_customization["Mouth"].part_texture_path:
		player_mouth.texture = current_customization["Mouth"].part_texture

func open() -> void:
	show()
	_load()

func close() -> void:
	hide()

func _close_editor() -> void:
	"""Handle closing the editor differently depending on game state."""
	if GameManager.state == GameManager.State.Start:
		close()
	else:
		UIManager.close_ui("appearance_editor")

func _on_SkinColorSelector_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		_choose_skin_color(event.position)
		if not event.pressed:
			color_preview.hide()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(BUTTON_LEFT):
		_choose_skin_color(event.position)

func _on_part_changed(new_part: String, part_name: String) -> void:
	var part_options: Array = player_part_options[part_name]
	var part_option: PartOption = null
	for option in part_options:
		if option.part_name == new_part:
			part_option = option
	if part_option == null:
		return
	current_customization[part_name] = part_option
	_update_preview()

func _on_root_size_changed() -> void:
	"""Reset the viewport image when the window has been resized."""
	viewport_texture_data = null

func _on_Animations_item_selected(index: int) -> void:
	match index:
		# Idle item
		0:
			animator.play("idle")
		# Move item
		1:
			animator.play("h_move")
		# Death item
		2:
			animator.play("death")

func _on_CancelButton_pressed() -> void:
	_close_editor()

func _on_SaveButton_pressed() -> void:
	_save()
	_close_editor()

func _load() -> void:
	"""
	Loads the player's saved appearance from player_data.save and applies it to
	the preview.
	"""
	player_data = SaveLoadHandler.load_data(player_data_path)
	if player_data.empty():
		# Default customization
		current_customization["Skin Color"] = player_skeleton.material.get_shader_param("skin_color")
		for part_option in player_part_options:
			current_customization[part_option] = player_part_options[part_option][0]
	else:
		for part in current_customization:
			if part == "Skin Color":
				current_customization[part] = Color(player_data["Appearance"][part])
			else:
				for key in player_part_options:
					for part_option in player_part_options[key]:
						if part_option.part_name == player_data["Appearance"][part]["part_name"]:
							current_customization[part] = part_option
							part_selectors[part].set_current_part(part_option.part_name)
	_update_preview()

func _save() -> void:
	"""Saves the player's selected appearance to player_data.save."""
	var clothes: PlayerClothes = current_customization["Clothes"]
	var player_data: Dictionary = {
		"Appearance": {
			"Skin Color": current_customization["Skin Color"].to_html(),
			"Clothes": {
				"part_name": clothes.part_name,
				"left_leg": {
					"part_name": clothes.left_leg.part_name,
					"texture_path": clothes.left_leg.part_texture_path,
				},
				"left_arm": {
					"part_name": clothes.left_arm.part_name,
					"texture_path": clothes.left_arm.part_texture_path,
				},
				"clothes": {
					"part_name": clothes.clothes.part_name,
					"texture_path": clothes.clothes.part_texture_path,
				},
				"pants": {
					"part_name": clothes.pants.part_name,
					"texture_path": clothes.pants.part_texture_path,
				},
				"right_leg": {
					"part_name": clothes.right_leg.part_name,
					"texture_path": clothes.right_leg.part_texture_path,
				},
				"right_arm": {
					"part_name": clothes.right_arm.part_name,
					"texture_path": clothes.right_arm.part_texture_path,
				},
			},
			"Body": {
				"part_name": current_customization["Body"].part_name,
				"texture_path": current_customization["Body"].part_texture_path,
			},
			"Facial Hair": {
				"part_name": current_customization["Facial Hair"].part_name,
				"texture_path": current_customization["Facial Hair"].part_texture_path,
			},
			"Face Wear": {
				"part_name": current_customization["Face Wear"].part_name,
				"texture_path": current_customization["Face Wear"].part_texture_path,
			},
			"Hat/Hair": {
				"part_name": current_customization["Hat/Hair"].part_name,
				"texture_path": current_customization["Hat/Hair"].part_texture_path,
			},
			"Mouth": {
				"part_name": current_customization["Mouth"].part_name,
				"texture_path": current_customization["Mouth"].part_texture_path,
			},
		},
	}
	
	SaveLoadHandler.save_data(player_data_path, player_data)
	emit_signal("appearance_saved")
