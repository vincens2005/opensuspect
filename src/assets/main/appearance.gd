extends YSort

func _apply_customizations(player: KinematicBody2D, player_data: Dictionary) -> void:
	"""Apply cosmetic changes to a local player."""
	if player_data.empty():
		return

	var skeleton: Node2D
	if player.has_node("SpritesViewport/Skeleton"):
		skeleton = player.get_node("SpritesViewport/Skeleton")
	elif player.has_node("Skeleton"):
		skeleton = player.get_node("Skeleton")
	var body: Polygon2D = skeleton.get_node("Body")
	var left_leg: Polygon2D = skeleton.get_node("LeftLeg")
	var left_arm: Polygon2D = skeleton.get_node("LeftArm")
	var right_leg: Polygon2D = skeleton.get_node("RightLeg")
	var right_arm: Polygon2D = skeleton.get_node("RightArm")
	var spine: Bone2D = skeleton.get_node("Skeleton/Spine")
	var clothes: Sprite = spine.get_node("Clothes")
	var pants: Sprite = spine.get_node("Pants")
	var facial_hair: Sprite = spine.get_node("FacialHair")
	var face_wear: Sprite = spine.get_node("FaceWear")
	var hat_hair: Sprite = spine.get_node("HatHair")
	var mouth: Sprite = spine.get_node("Mouth")

	var appearance: Dictionary = player_data["Appearance"]
	skeleton.material.set_shader_param("skin_color", Color(appearance["Skin Color"]))
	left_leg.texture = load(appearance["Clothes"]["left_leg"]["texture_path"])
	left_arm.texture = load(appearance["Clothes"]["left_arm"]["texture_path"])
	right_leg.texture = load(appearance["Clothes"]["right_leg"]["texture_path"])
	right_arm.texture = load(appearance["Clothes"]["right_arm"]["texture_path"])
	clothes.texture = load(appearance["Clothes"]["clothes"]["texture_path"])
	pants.texture = load(appearance["Clothes"]["pants"]["texture_path"])
	facial_hair.texture = load(appearance["Facial Hair"]["texture_path"])
	face_wear.texture = load(appearance["Face Wear"]["texture_path"])
	hat_hair.texture = load(appearance["Hat/Hair"]["texture_path"])
	mouth.texture = load(appearance["Mouth"]["texture_path"])

func _on_appearance_saved() -> void:
	"""Called when a player changes their appearance in-game."""
	_apply_customizations(get_parent().players[Network.get_my_id()], SaveLoadHandler.load_data(get_parent().player_data_path))
	rpc_id(1, "query_player_data")
	print("appearance saved from new sckript")
