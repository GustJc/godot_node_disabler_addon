@tool
extends EditorPlugin

# TODO: Check if any duplicated code
# TODO: Put disabled icon in all children as well??
#      Needs to use is_visible_in_tree instead of visible if so
#      Would also need to transverse all child to update all, might not be worth it.
# TODO: Multi-select toggles all selected nodes. Don't toggle children nodes.
#   Lock and group will only toggle the parent nodes or siblings.
#   Maybe use the same behavior as it is irrelevant to toggle children and can cause problems.
# FIXME: When a node Process_Mode is DISABLED
#   All children are reprocessed, and the icons are remade.
#   So if the child has the disabled icon, but only the parent is selected and you disable it
#   the child will lose its icon.
#   Updating icons when selecting nodes to mitigate this problem for now.
#   Reprocessing all the selected node tree does not seem worth it. performance wise.

var scene_tree : Tree

const DISABLE_BUTTON_ID = 20
const USE_MULTI_SELECT = true

var ref_button : Array[Button]
var container_button : Button
var container_button_3d : Button
var canvas_toolbar_path = "/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15/DockHSplitLeftL/DockHSplitLeftR/DockHSplitMain/@VBoxContainer@26/DockVSplitCenter/@VSplitContainer@54/@VBoxContainer@55/@EditorMainScreen@102/MainScreen/@CanvasItemEditor@11479/@MarginContainer@11127/@HFlowContainer@11128/@HBoxContainer@11129"
var node3d_toolbar_path = "/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15/DockHSplitLeftL/DockHSplitLeftR/DockHSplitMain/@VBoxContainer@26/DockVSplitCenter/@VSplitContainer@54/@VBoxContainer@55/@EditorMainScreen@102/MainScreen/@Node3DEditor@12336/@MarginContainer@11481/@HFlowContainer@11482/@HBoxContainer@11483"


# Path the user will have to do on Project -> Project Settings -> ...
const PLUGIN_PATH := "plugins/node_disabler/shortcut"
const TOGGLE_DISABLE_SHORTCUT = preload("res://addons/node_disabler/toggle_disable_shortcut.tres")
var shortcut: Shortcut


func _enter_tree() -> void:
	_add_plugin_button() # and intercept menu lock_group buttons to refresh

	# Find ref to Tree used by Godot. If not found, will search for it.
	var absolute_tree_path_try := get_tree().root.get_node(^"/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15/DockHSplitLeftL/DockHSplitLeftR/DockVSplitLeftR/DockSlotLeftUR/Scene/@SceneTreeEditor@5131/@Tree@5102")
	if not absolute_tree_path_try:
		print("Did not find it. So scanning...")
		var editor_split_zones := get_tree().root.get_node(^"/root/@EditorNode@21298/@Panel@14/@VBoxContainer@15")
		scene_tree = _find_scene_tree(editor_split_zones)
	else:
		scene_tree = absolute_tree_path_try

	scene_tree.button_clicked.connect(_tree_button_clicked)
	scene_tree.cell_selected.connect(_selected_callback)
	#scene_tree.multi_selected.connect(_multi_selected_callback)
	scene_tree.item_mouse_selected.connect(_selected_item_mouse)

	# Shortcuts
	shortcut = set_shortcut(PLUGIN_PATH, TOGGLE_DISABLE_SHORTCUT)


func _exit_tree() -> void:
	if is_instance_valid(scene_tree):
		scene_tree.button_clicked.disconnect(_tree_button_clicked)
		scene_tree.cell_selected.disconnect(_selected_callback)
		#scene_tree.multi_selected.disconnect(_multi_selected_callback)
		scene_tree.item_mouse_selected.disconnect(_selected_item_mouse)
	_remove_plugin_button()
	# remove shortcut
	# On exit or deactivation, remove shortcut and ProjectSetting path
	shortcut = null
	ProjectSettings.clear(PLUGIN_PATH)
	ProjectSettings.save()


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
	container_button_3d.self_modulate = Color.AQUA

	container_button.pressed.connect(_toggle_callback)
	container_button_3d.pressed.connect(_toggle_callback)

	menubar.add_child(container_button)
	menubar.move_child(container_button, i)
	menubar_3d.add_child(container_button_3d)
	menubar_3d.move_child(container_button_3d, ii)


func _remove_plugin_button():
	if is_instance_valid(container_button):
		container_button.queue_free()
	if is_instance_valid(container_button_3d):
		container_button_3d.queue_free()
	for btn in ref_button:
		btn.button_up.disconnect(_buttonup)


## Top button callback
func _toggle_callback():
	var node := _get_node_from_tree_item(scene_tree.get_selected())
	var has_disabled := _toggle_node_disabled(node) # Refresh inside
	_set_button_color(has_disabled)
	if USE_MULTI_SELECT:
		_set_all_selection_disabled(has_disabled)


## Does not refresh inside. Call outside it
func _set_all_selection_disabled(is_disabled: bool = true) -> void:
	var start_item = scene_tree.get_next_selected(null)
	var item = start_item
	while item != null:
		var node := _get_node_from_tree_item(item)
		if is_disabled:
			_disable_node(node)
		else:
			_enable_node(node)
		item = scene_tree.get_next_selected(item)


func _set_button_color(is_disabled_color: bool = false):
	if is_disabled_color:
		container_button.self_modulate = Color.RED
		container_button_3d.self_modulate = Color.RED
	else:
		container_button.self_modulate = Color.AQUA
		container_button_3d.self_modulate = Color.AQUA


## Returns TRUE is node was enabled and has become DISABLED
func _toggle_node_disabled(node: Node, refresh_selected: bool = true) -> bool:
	var has_disabled := false
	if _is_node_disabled(node):
		_enable_node(node)
	else:
		_disable_node(node)
		has_disabled = true

	if refresh_selected:
		call_deferred("_refresh_selected_nodes")

	return has_disabled


func _is_node_disabled(node: Node) -> bool:
	var is_disabled = true if node.process_mode == PROCESS_MODE_DISABLED else false
	if is_disabled and "visible" in node:
		if node.visible:
			is_disabled = false
	return is_disabled


func _buttonup():
	print("Btn UP")
	call_deferred("_refresh_selected_nodes")


func _refresh_selected_nodes():
	var start_item = scene_tree.get_next_selected(null)
	if start_item == null: # if none is select, uses the last selected one (greyed border node)
		start_item = scene_tree.get_selected()

	var item = start_item
	while item != null:
		var node := _get_node_from_tree_item(item)
		var is_disabled = _is_node_disabled(node)

		var index := item.get_button_by_id(0, DISABLE_BUTTON_ID)
		if index == -1:
			if is_disabled: # Disable button does not exist and is fully disabled
				#print("No button and IS_DISABLED")
				_add_single_disable_button(item)
		elif not is_disabled: # Button already exists, but not enterily disabled
			#print("Not disabled anymore")
			item.erase_button(0, index)
		item = scene_tree.get_next_selected(item)


func _add_disable_buttons(item: TreeItem):
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
	#print("Tree clicked")
	#print(item.get_button_count(0))
	if id == DISABLE_BUTTON_ID: # Clicked on disable button, so enable node back
		# Only single selected node
		var node := _get_node_from_tree_item(item)
		item.erase_button(0, item.get_button_by_id(0, DISABLE_BUTTON_ID))
		_enable_node(node) # Re-enable process mode and visibility
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


#region Tree selection changed callbacks
func _update_button_colors():
	var node := _get_node_from_tree_item(scene_tree.get_selected())
	var is_disabled := _is_node_disabled(node)
	_set_button_color(is_disabled)


## Works also for when holding shift to multi-select
func _selected_item_mouse(mouse_position: Vector2, mouse_button_index: int):
	_update_button_colors()
	# Just to repair any lost icons due to change in parent process_mode
	call_deferred("_refresh_selected_nodes")


## On changing selected node with mouse or arrows. But not on shift+click, thats on multi_selected
func _selected_callback():
	_update_button_colors()
#endregion // Tree selection changed callbacks


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


func set_shortcut(project_setting_path: String, resource: Shortcut) -> Shortcut:
	ProjectSettings.set_setting(PLUGIN_PATH, resource)
	return resource


# Handles shortcuts. Needs input for mouse to work within the scene dock
func _input(event: InputEvent) -> void:
	# Will only be called once when pressed
	if not event.is_pressed() or event.is_echo(): return
	if shortcut.matches_event(event):
		var node := _get_node_from_tree_item(scene_tree.get_selected())
		if node:
			var has_disabled := _toggle_node_disabled(node) # Refresh inside
			if USE_MULTI_SELECT:
				_set_all_selection_disabled(has_disabled)
