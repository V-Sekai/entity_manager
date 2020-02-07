extends Node
class_name Entity
tool

const entity_manager_const = preload("entity_manager.gd")

"""
Parenting
"""
enum {
	ENTITY_PARENT_STATE_OK,
	ENTITY_PARENT_STATE_CHANGED
	ENTITY_PARENT_STATE_INVALID
}

signal attachment_points_pre_change()
signal attachment_points_post_change()

var entity_parent_state : int = ENTITY_PARENT_STATE_OK
var entity_parent : Node = null
var entity_children : Array = []
var attachment_id : int = 0

"""
Entity Manager
"""
var entity_manager : entity_manager_const = null

"""
Transform Notification
"""
export(NodePath) var transform_notification_node_path : NodePath = NodePath()
var transform_notification_node : Node = null

"""
Simulation Logic Node
"""
export(NodePath) var simulation_logic_node_path : NodePath = NodePath()
var simulation_logic_node : Node = null
	
func get_simulation_logic_node() -> Node:
	return simulation_logic_node

"""
Network Identity Node
"""
export(NodePath) var network_identity_node_path : NodePath = NodePath()
var network_identity_node : Node = null

func get_network_identity_node() -> Node:
	return network_identity_node

"""
Network Logic Node
"""
export(NodePath) var network_logic_node_path : NodePath = NodePath()
var network_logic_node : Node = null

func get_network_logic_node() -> Node:
	return network_logic_node

func _entity_ready() -> void:
	if !Engine.is_editor_hint():
		if simulation_logic_node:
			simulation_logic_node._entity_ready()
			
func is_subnode_property_valid() -> bool:
	if Engine.is_editor_hint() == false:
		return true
	else:
		return filename != "" or (is_inside_tree() and get_tree().edited_scene_root and get_tree().edited_scene_root == self)

static func sub_property_path(p_property : String, p_sub_node_name : String) -> String:
	var split_property : PoolStringArray = p_property.split("/", -1)
	var property : String = ""
	if split_property.size() > 1 and split_property[0] == p_sub_node_name:
		for i in range(1, split_property.size()):
			property += split_property[i]
			if i != (split_property.size()-1):
				property += "/"
	
	return property
			
func _get_property_list() -> Array:
	var properties : Array = []
	var node : Node = get_node(simulation_logic_node_path)
	if node and node != self:
		if is_subnode_property_valid():
			var node_property_list = node.get_property_list()
			for property in node_property_list:
				if property.usage & PROPERTY_USAGE_EDITOR and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					if property.name.substr(0, 1) != '_': 
						property.name = "simulation_logic_node/" + property.name
						properties.push_back(property)
		
	return properties
	
func get_sub_property(p_path : NodePath, p_property : String, p_sub_node_name : String):
	var variant = null
	var node = get_node_or_null(p_path)
	if node and node != self:
		var property : String = sub_property_path(p_property, p_sub_node_name)
		if property.substr(0, 1) != '_': 
			variant = node.get(property)
			if typeof(variant) == TYPE_NODE_PATH:
				if variant != "":
					var sub_node : Node = node.get_node_or_null(variant)
					if sub_node:
						variant = get_path_to(sub_node)
					else:
						variant = NodePath()
				else:
					variant = NodePath()
	return variant

func set_sub_property(p_path : NodePath, p_property : String, p_value, p_sub_node_name : String) -> bool:
	var node = get_node_or_null(p_path)
	if node != null and node != self:
		var property : String = sub_property_path(p_property, p_sub_node_name)
		if property.substr(0, 1) != '_':
			var variant = p_value
			if typeof(variant) == TYPE_NODE_PATH:
				if variant != "":
					var sub_node = get_node_or_null(variant)
					if sub_node:
						return node.set(property, node.get_path_to(sub_node))
					else:
						return node.set(property, NodePath())
				else:
					return node.set(property, NodePath())
			return node.set(property, variant)
	return false
	
func _get(p_property : String):
	if Engine.is_editor_hint():
		var variant = null
		if is_subnode_property_valid():
			variant = get_sub_property(simulation_logic_node_path, p_property, "simulation_logic_node")
		return variant

func _set(p_property : String, p_value) -> bool:
	if Engine.is_editor_hint():
		var return_val : bool = false
		if is_subnode_property_valid():
			return_val = set_sub_property(simulation_logic_node_path, p_property, p_value, "simulation_logic_node")
			
		return return_val
	else:
		return false
		
func get_attachment_node(p_attachment_id : int) -> Node:
	return get_simulation_logic_node().get_attachment_node(p_attachment_id)
	
func _add_entity_child_internal(p_entity_child : Node) -> void:
	if p_entity_child:
		var child_name : String = p_entity_child.get_name()
		if entity_children.has(p_entity_child):
			ErrorManager.error("_add_entity_child: does not have entity child {child_name}!".format({"child_name":child_name}))
		else:
			entity_children.push_back(p_entity_child)
			p_entity_child.connect("attachment_points_pre_change", self, "remove_to_attachment")
			p_entity_child.connect("attachment_points_post_change", self, "add_to_attachment")
	else:
		ErrorManager.error("_add_entity_child: attempted to add null entity child!")
	
func _remove_entity_child_internal(p_entity_child : Node) -> void:
	if p_entity_child:
		var child_name : String = p_entity_child.get_name()
		if entity_children.has(p_entity_child):
			var index = entity_children.find(p_entity_child)
			if index != -1:
				entity_children.remove(index)
				p_entity_child.disconnect("attachment_points_pre_change", self, "refresh_attachment")
				p_entity_child.disconnect("attachment_points_post_change", self, "refresh_attachment")
			else:
				ErrorManager.error("_remove_entity_child: does not have entity child {child_name}!".format({"child_name":child_name}))
		else:
			ErrorManager.error("_remove_entity_child: does not have entity child {child_name}!".format({"child_name":child_name}))
	else:
		ErrorManager.error("_remove_entity_child: attempted to remove null entity child!")
	
func _has_entity_parent_internal() -> bool:
	if entity_parent != null:
		if entity_parent.get_script() == get_script():
			return true
			
	return false
	
func _set_entity_parent_internal(p_entity_parent : Node) -> void:
	if p_entity_parent == entity_parent:
		return
		
	# Remove any previous parents
	if _has_entity_parent_internal():
		entity_parent._remove_entity_child_internal(self)
	
	# Set the entity parent if its a valid entity
	if p_entity_parent == null or (p_entity_parent and p_entity_parent.get_script() == get_script()):
		entity_parent = p_entity_parent
	
	# If the entity parent is not null, check if it is valid, and then add it to its list of children
	if entity_parent != null:
		entity_parent._add_entity_child_internal(self)
		
func add_to_attachment():
	if entity_parent != null:
		# Remove it from the tree and remove its original entity parent
		if is_inside_tree():
			printerr("add_to_attachment: already inside tree!")
		else:
			# Now add it back into the tree which will automatically reparent it
			entity_parent.get_attachment_point(attachment_id).add_child(self)
	else:
		printerr("add_to_attachment: does not have entity parent!")
		
func remove_from_attachment():
	if entity_parent != null:
		# Remove it from the tree and remove its original entity parent
		if is_inside_tree():
			get_parent().remove_child(self)
		else:
			printerr("remove_from_attachment: not inside tree!")
	else:
		printerr("remove_from_attachment: does not have entity parent!")
		
func attachment_points_pre_change() -> void:
	emit_signal("attachment_points_pre_change")

func attachment_points_post_change() -> void:
	emit_signal("attachment_points_pre_change")
		
func get_entity_parent() -> Node:
	return entity_parent
		
func set_entity_parent(p_entity_parent : Node) -> void:
	# Same parent, no update needed
	if p_entity_parent == entity_parent:
		return
	
	# Save the global transform
	var last_global_transform : Transform = Transform()
	
	if simulation_logic_node:
		last_global_transform = simulation_logic_node.get_global_transform()
	
	# Remove it from the tree and remove its original entity parent
	if is_inside_tree():
		remove_from_attachment()
	
	# Make sure that the entity parent is null or a valid entity node
	if p_entity_parent == null or (p_entity_parent.get_script() == get_script()):
		var network_identity_node : Node = get_network_identity_node()
		
		# Now add it back into the tree which will automatically reparent it
		if p_entity_parent == null:
			if network_identity_node:
				network_identity_node.network_replication_manager.get_entity_root_node().add_child(self)
		else:
			add_to_attachment()
			
		# Reload the previously saved global transform
		if simulation_logic_node:
			simulation_logic_node.set_global_transform(last_global_transform)
		
func clear_entity_parent() -> void:
	set_entity_parent(null)
			
func _enter_tree() -> void:
	if !Engine.is_editor_hint():
		if _has_entity_parent_internal():
			ErrorManager.error("Entity is trying to enter the tree with an existing entity parent!")
		else:
			_set_entity_parent_internal(get_parent())
	
func _exit_tree() -> void:
	if !Engine.is_editor_hint():
		if _has_entity_parent_internal():
			_set_entity_parent_internal(null)
	
func cache_nodes() -> void:
	transform_notification_node = get_node_or_null(transform_notification_node_path)
	if transform_notification_node == self:
		transform_notification_node = null
		
	simulation_logic_node = get_node_or_null(simulation_logic_node_path)
	if simulation_logic_node == self:
		simulation_logic_node = null
		
	network_identity_node = get_node_or_null(network_identity_node_path)
	if network_identity_node == self:
		network_identity_node = null
		
	network_logic_node = get_node_or_null(network_logic_node_path)
	if network_logic_node == self:
		network_logic_node = null
	
func _ready() -> void:
	if !Engine.is_editor_hint():
		entity_manager = get_node_or_null("/root/EntityManager")
		if entity_manager:
			add_to_group("Entities")
			
			cache_nodes()
				
			if connect("ready", entity_manager, "_entity_ready", [self]) != OK:
				printerr("entity: ready could not be connected!")
			if connect("tree_exiting", entity_manager, "_entity_exiting", [self]) != OK:
				printerr("entity: tree_exiting could not be connected!")
			
