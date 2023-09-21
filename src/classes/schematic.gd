class_name Schematic

extends GraphEdit

const PART_OFFSET_STEP = Vector2(100, 100)
const PART_INITIAL_OFFSET = Vector2(100, 100)

var circuit: Circuit
var selected_parts = {}
var part_name_id = 0

func _ready():
	circuit = Circuit.new()
	node_deselected.connect(deselect_part)
	node_selected.connect(select_part)
	delete_nodes_request.connect(delete_selected_parts)
	copy_nodes_request.connect(copy_selected_parts)
	connection_request.connect(connect_wire)
	disconnection_request.connect(disconnect_wire)


func connect_wire(from_part, from_pin, to_part, to_pin):
	# Add guards against invalid connections
	connect_node(from_part, from_pin, to_part, to_pin)
	circuit.connections = get_connection_list()
	# Propagate bus value or level


func disconnect_wire(from_part, from_pin, to_part, to_pin):
	disconnect_node(from_part, from_pin, to_part, to_pin)
	circuit.connections = get_connection_list()


func remove_connections_to_part(part):
	for con in get_connection_list():
		if con.to == part.name or con.from == part.name:
			disconnect_node(con.from, con.from_port, con.to, con.to_port)


func clear():
	clear_connections()
	circuit.connections.clear()
	circuit.parts.clear()
	for node in get_children():
		if node is Part:
			node.queue_free()


func select_part(part):
	selected_parts[part] = true


func deselect_part(part):
	selected_parts[part] = false


func delete_selected_parts(_arr):
	# _arr only lists parts with a close button
	for part in selected_parts.keys():
		if selected_parts[part]:
			delete_selected_part(part)
	selected_parts.clear()
	circuit.connections = get_connection_list()


func delete_selected_part(part):
	circuit.parts.erase(part)
	for con in get_connection_list():
		if con.to == part.name or con.from == part.name:
			disconnect_node(con.from, con.from_port, con.to, con.to_port)
	part.queue_free()


func copy_selected_parts():
	for part in selected_parts.keys():
		if selected_parts[part]:
			for node in get_children():
				if node == part:
					var new_part = part.duplicate()
					new_part.position_offset += PART_OFFSET_STEP
					part_name_id += 1
					new_part.name = "part" + str(part_name_id)
					add_child(new_part)


func add_part(part: Part):
	part.position_offset = PART_INITIAL_OFFSET + scroll_offset / zoom
	part_name_id += 1
	part.name = "part" + str(part_name_id)
	add_child(part)
	
