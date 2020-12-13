extends StaticBody2D

#if true, door will slide to the left
var openLeft: bool = true 
var open: bool = false

func _ready():
# warning-ignore:return_value_discarded
	MapManager.connect("interacted_with", self, "interacted_with")

func toggle(newState: bool = not open):
	if newState:
		open()
	else:
		close()

# warning-ignore:function_conflicts_variable
func open():
	if openLeft:
		position.x -= $CollisionShape2D.shape.extents.x * 2 * scale.x
	else:
		position.x += $CollisionShape2D.shape.extents.x * 2 * scale.x
	open = true

func close():
	if openLeft:
		position.x += $CollisionShape2D.shape.extents.x * 2 * scale.x
	else:
		position.x -= $CollisionShape2D.shape.extents.x * 2 * scale.x
	open = false

# warning-ignore:unused_argument
func interacted_with(interactNode: Node, from: Node, interact_data: Dictionary):
	if interactNode != self:
		return
	if not from.has_method("get_state"):
		return
	toggle(from.get_state())
