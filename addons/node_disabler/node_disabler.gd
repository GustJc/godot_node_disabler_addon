@tool
extends EditorPlugin

# TODO: Intercept hotkey group/lock to update button
# TODO: Add hotkey to toggle disable or button at the top
# TODO: Remove code duplication* some done, recheck later
# TODO: use is_visible_in_tree instead of visible??
#         will update correct icon for refreshed nodes, but needs to tranverse all child to update all
#         because only tries to refresh selected nodes, not all children of they
# TODO: Toggle only toggles single selected, and colors are not yet done
# TODO: Toggle TreeItem button only disabled clicked node. Maybe unchecks all. Needs strategy

var scene_tree : Tree

const DISABLE_BUTTON_ID = 20


var ref_button : Array[Button]
var container_button : Button
var container_button_3d : Button
var canvas_toolbar_path = "/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15/DockHSplitLeftL/DockHSplitLeftR/DockHSplitMain/@VBoxContainer@26/DockVSplitCenter/@VSplitContainer@54/@VBoxContainer@55/@EditorMainScreen@102/MainScreen/@CanvasItemEditor@11479/@MarginContainer@11127/@HFlowContainer@11128/@HBoxContainer@11129"
var node3d_toolbar_path = "/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15/DockHSplitLeftL/DockHSplitLeftR/DockHSplitMain/@VBoxContainer@26/DockVSplitCenter/@VSplitContainer@54/@VBoxContainer@55/@EditorMainScreen@102/MainScreen/@Node3DEditor@12336/@MarginContainer@11481/@HFlowContainer@11482/@HBoxContainer@11483"
func _add_plugin_button():

	## Signals for 2d
	var menubar = get_node(canvas_toolbar_path)
	var size = menubar.get_child_count()
	var i = size-1
	var i_button := 0
	while i >= 0:
		var node := menubar.get_child(i)
		if node is Button:
			i_button += 1
			if i_button > 2:
				# Pressed in unreliable
				(node as Button).button_up.connect(_buttonup)
				ref_button.push_back(node)
			if i_button >= 6:
				break
		i -= 1

	## Signals for 3d
	var menubar_3d := get_node(node3d_toolbar_path)
	size = menubar_3d.get_child_count()
	var ii = size-1
	i_button = 0
	while ii >= 0:
		var node := menubar_3d.get_child(ii)
		if node is Button:
			i_button += 1
			if i_button > 8:
				(node as Button).button_up.connect(_buttonup)
				ref_button.push_back(node)
			if i_button >= 12:
				break
		ii -= 1

	## Add buttons now
	container_button = Button.new()
	container_button.icon = EditorInterface.get_base_control().get_theme_icon("ColorRect", "EditorIcons")
	container_button.theme_type_variation = &"FlatButton"
	container_button.self_modulate = Color.AQUA
	container_button_3d = Button.new()
	container_button_3d.icon = EditorInterface.get_base_control().get_theme_icon("ColorRect", "EditorIcons")
	container_button_3d.theme_type_variation = &"FlatButton"
	container_button_3d.self_modulate = Color.SANDY_BROWN

	container_button.pressed.connect(_toggle.bind(container_button))
	container_button_3d.pressed.connect(_toggle.bind(container_button_3d))

	menubar.add_child(container_button)
	menubar.move_child(container_button, i)
	menubar_3d.add_child(container_button_3d)
	menubar_3d.move_child(container_button_3d, ii)


func _toggle(btn:Button):
	btn.self_modulate = Color.BLUE
	var node := _get_node_from_tree_item(scene_tree.get_selected())
	_disable_node(node)
	call_deferred("_refresh_selected_nodes")


func _buttonup():
	print("Btn UP")
	call_deferred("_refresh_selected_nodes")


func _remove_plugin_button():
	if is_instance_valid(container_button):
		container_button.queue_free()
	if is_instance_valid(container_button_3d):
		container_button_3d.queue_free()
	for btn in ref_button:
		btn.button_up.disconnect(_buttonup)


func _exit_tree() -> void:
	if is_instance_valid(scene_tree):
		scene_tree.button_clicked.disconnect(_tree_button_clicked)
	_remove_plugin_button()


func _enter_tree() -> void:
	_add_plugin_button()

	var absolute_tree_path_try := get_tree().root.get_node(^"/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15/DockHSplitLeftL/DockHSplitLeftR/DockVSplitLeftR/DockSlotLeftUR/Scene/@SceneTreeEditor@5131/@Tree@5102")
	if not absolute_tree_path_try:
		print("Did not find it. So scanning...")
		var editor_split_zones := get_tree().root.get_node(^"/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15")
		scene_tree = _find_scene_tree(editor_split_zones)
	else:
		scene_tree = absolute_tree_path_try

	scene_tree.button_clicked.connect(_tree_button_clicked)

	## Disable selected items
	#var start_item = scene_tree.get_selected()
	#var item = start_item
	#while item != null:
		#print("Disabling... ", item)
		#var node := get_tree().root.get_node(item.get_metadata(0))
		#_disable_node(node)
		#item = scene_tree.get_next_selected(item)
#
	#call_deferred("_add_disable_buttons", start_item)


func _refresh_selected_nodes():
	var start_item = scene_tree.get_next_selected(null)
	var item = start_item
	while item != null:
		var node := _get_node_from_tree_item(item)
		var is_disabled = true if node.process_mode == PROCESS_MODE_DISABLED else false
		if is_disabled and "visible" in node:
			if node.visible:
				is_disabled = false

		var index := item.get_button_by_id(0, DISABLE_BUTTON_ID)
		if index == -1:
			if is_disabled: # Disable button does not exist and is fully disabled
				print("No button and IS_DISABLED")
				_add_single_disable_button(item)
		elif not is_disabled: # Button already exists, but not enterily disabled
			print("Not disabled anymore")
			item.erase_button(0, index)
		item = scene_tree.get_next_selected(item)


func _add_disable_buttons(item: TreeItem):
	print("Add buttons!")
	while item:
		print(item)
		_add_single_disable_button(item)
		item = scene_tree.get_next_selected(item)

func _add_single_disable_button(item: TreeItem):
	var index := item.get_button_by_id(0, DISABLE_BUTTON_ID)
	if index != -1:
		return # Already exists

	item.add_button(0,
		EditorInterface.get_base_control().get_theme_icon("ColorRect", "EditorIcons"),
		DISABLE_BUTTON_ID, false, "Node disabled")
	var id = item.get_button_count(0) - 1
	item.set_button_color(0, id, Color.RED)


func _tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int):
	print("Tree clicked")
	print(item.get_button_count(0))
	if id == DISABLE_BUTTON_ID: # Clicked on disable button, so enable node back
		# Only single selected node
		var node := _get_node_from_tree_item(item)
		item.erase_button(0, item.get_button_by_id(0, DISABLE_BUTTON_ID))
		_enable_node(node) # Re-enable process mode and visibility
		print(node)
	else: # Editor may hade remade the buttons, so we need to check if disabled
		# Needs this in case user clicks on icon of non-selected node
		var node := _get_node_from_tree_item(item)
		var is_disabled = true if node.process_mode == PROCESS_MODE_DISABLED else false
		if is_disabled and "visible" in node:
			if node.visible:
				is_disabled = false

		var index := item.get_button_by_id(0, DISABLE_BUTTON_ID)
		if index == -1:
			if is_disabled: # Disable button does not exist and is fully disabled
				_add_single_disable_button(item)
		elif not is_disabled: # Button already exists, but not enterily disabled
			item.erase_button(0, index)
	call_deferred("_refresh_selected_nodes")



func _enable_node(node: Node):
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if "visible" in node:
		node.show()


func _disable_node(node: Node):
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if "visible" in node:
		node.hide()


func _get_node_from_tree_item(tree_item: TreeItem) -> Node:
	return get_tree().root.get_node(tree_item.get_metadata(0))


func _find_scene_tree(base_node: Node) -> Tree:
	if base_node is Tree:
		return base_node
	for n in base_node.get_children():
		var parent: Control = _find_scene_tree(n)
		if parent: return parent
	return null
