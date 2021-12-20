@tool
class_name SimulationLogic extends "res://addons/entity_manager/component_node.gd" # component_node.gd


# Static value, do not edit at runtime
# warning-ignore:unused_private_class_variable
@export var _entity_type: String = ""

func _enter_tree() -> void:
	if ! Engine.is_editor_hint():
		add_to_group("entity_managed")


func _exit_tree() -> void:
	if ! Engine.is_editor_hint():
		remove_from_group("entity_managed")


func _transform_changed() -> void:
	pass


func cache_node(p_node_path: NodePath) -> Node:
	return get_node_or_null(p_node_path)


func get_attachment_id(_attachment_string: String) -> int:
	return -1


func get_attachment_node(_attachment_id: int) -> Node:
	return get_entity_node()


func _entity_parent_changed() -> void:
	pass


##############
# Networking #
##############


func is_entity_master() -> bool:
	if get_tree() != null and ! get_tree().multiplayer.has_multiplayer_peer():
		return true
	else:
		if is_multiplayer_authority():
			return true
		else:
			return false


func _entity_representation_process(_delta: float) -> void:
	pass


func _entity_physics_pre_process(_delta: float) -> void:
	pass


func _entity_physics_process(_delta: float) -> void:
	pass


func _entity_physics_post_process(_delta: float) -> void:
	pass


func _entity_ready() -> void:
	pass


func entity_child_pre_remove(_entity_child: Node) -> void:
	pass


func can_request_master_from_peer(_id: int) -> bool:
	return false


func can_transfer_master_from_session_master(_id: int) -> bool:
	return false

