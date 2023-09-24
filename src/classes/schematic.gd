class_name Schematic

extends GraphEdit

signal invalid_instance(ob, note)

const PART_INITIAL_OFFSET = Vector2(50, 50)

var part_scene = preload("res://parts/part.tscn")
var circuit: Circuit
var selected_parts = []
var part_initial_offset_delta = Vector2.ZERO
var file_name = "res://temp.tres"

func _ready():
	circuit = Circuit.new()
	node_deselected.connect(deselect_part)
	node_selected.connect(select_part)
	delete_nodes_request.connect(delete_selected_parts)
	connection_request.connect(connect_wire)
	disconnection_request.connect(disconnect_wire)
	duplicate_nodes_request.connect(duplicate_selected_parts)


func connect_wire(from_part, from_pin, to_part, to_pin):
	# Add guards against invalid connections
	# Think about how to handle reverse (right to left) flow
	# Only allow 1 connection to an input
	for con in get_connection_list():
		if to_part == con.to and to_pin == con.to_port:
			return
	connect_node(from_part, from_pin, to_part, to_pin)
	# Propagate bus value or level


func disconnect_wire(from_part, from_pin, to_part, to_pin):
	disconnect_node(from_part, from_pin, to_part, to_pin)


func remove_connections_to_part(part):
	for con in get_connection_list():
		if con.to == part.name or con.from == part.name:
			disconnect_node(con.from, con.from_port, con.to, con.to_port)


func clear():
	clear_connections()
	for node in get_children():
		if node is Part:
			# Change the node name to avoid conflicts with loaded scene part names
			# whilst the old objects may not be freed up when new parts are being added
			node.name = node.name + "x"
			remove_child(node) # Added this after the above fix
			node.queue_free() # This is delayed


func select_part(part):
	selected_parts.append(part)


func deselect_part(part):
	selected_parts.erase(part)


func delete_selected_parts(_arr):
	# _arr only lists parts that have a close button
	for part in selected_parts:
		if not is_object_instance_invalid(part, "delete_selected_parts"):
			delete_selected_part(part)
	selected_parts.clear()


func delete_selected_part(part):
	for con in get_connection_list():
		if con.to == part.name or con.from == part.name:
			disconnect_node(con.from, con.from_port, con.to, con.to_port)
	remove_child(part)
	part.queue_free()


func duplicate_selected_parts():
	# Base the location off the first selected part relative to the mouse cursor
	var offset = abs(get_local_mouse_position())
	var first_part = true
	for part in selected_parts:
		# Sometimes a previously freed part is one of the selected parts
		if is_object_instance_invalid(part, "duplicate_selected_parts"):
			continue
		if first_part:
			first_part = false
			offset = offset - part.position
			var part_offset = part.position_offset - scroll_offset
			# Can only seem to approximate the position when zoomed.
			# Ideally, the first selected part copy would position itself
			# exacly where the mouse cursor is.
			# Are you up for the challenge to fix this?
			if zoom > 1.1 or zoom < 0.9:
				part_offset *= 0.8 / zoom
			offset = Vector2(offset.x / part.position.x * part_offset.x, \
				offset.y / part.position.y * part_offset.y)
		var new_part = part.duplicate()
		new_part.selected = false
		new_part.position_offset += offset
		add_child(new_part)
		new_part.name = "part" + circuit.get_next_id()


func add_part():
	var part = part_scene.instantiate()
	part.position_offset = PART_INITIAL_OFFSET + scroll_offset / zoom \
		+ part_initial_offset_delta
	update_part_initial_offset_delta()
	add_child(part)
	# We want precise control of node names to keep circuit data robust
	# Godot can sneak in @ marks to the node name, so we assign the name after
	# the node was added to the scene and Godot gave it a name
	part.name = "part" + circuit.get_next_id()


# Avoid overlapping parts that are added via the menu
# Place in a 4x4 pattern since 16 parts are likely to be the max entered in one
# go by a user I think
func update_part_initial_offset_delta():
	var x = part_initial_offset_delta.x
	var y = part_initial_offset_delta.y
	y += 20
	if y > 60:
		y = 0
		x += 20
		if x > 60:
			x = 0
	part_initial_offset_delta = Vector2(x, y)


func save_circuit():
	circuit.connections = get_connection_list()
	circuit.parts = []
	for node in get_children():
		if node is Part:
			# Save the name of the node
			node.node_name = node.name
			circuit.parts.append(node)
	circuit.snap_distance = snap_distance
	circuit.use_snap = use_snap
	circuit.minimap_enabled = minimap_enabled
	circuit.zoom = zoom
	circuit.scroll_offset = scroll_offset
	circuit.save_data(file_name)


func load_circuit():
	clear()
	circuit = Circuit.new().load_data(file_name)
	setup_graph()
	add_parts()
	add_connections()


func add_parts():
	for node in circuit.parts:
		if is_object_instance_invalid(node, "add_parts"):
			continue
		# Todo: instantiate node based on part_type
		var part = part_scene.instantiate()
		part.tag = node.tag
		part.part_type = node.part_type
		part.data = node.data
		add_child(part)
		part.name = node.node_name
		part.position_offset = node.position_offset


func add_connections():
	for con in circuit.connections:
		connect_node(con.from, con.from_port, con.to, con.to_port)


func setup_graph():
	snap_distance = circuit.snap_distance
	use_snap = circuit.use_snap
	zoom = circuit.zoom
	scroll_offset = circuit.scroll_offset
	minimap_enabled = circuit.minimap_enabled


# This function is included because it is difficult to debug situations 
# of freed nodes still persisting in say a weak reference state.
# In this software we frequently delete, duplicate, and create nodes.
func is_object_instance_invalid(ob, note = ""):
	if is_instance_valid(ob):
		return false
	else:
		emit_signal("invalid_instance", ob, note)
		return true
