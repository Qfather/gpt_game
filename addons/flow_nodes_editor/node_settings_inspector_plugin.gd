@tool
extends EditorInspectorPlugin
class_name FlowNodesInspectorPlugin

var _creating_default_editor := false

func _can_handle(object):
	return object is FlowNodeBase

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if _creating_default_editor:
		return false
	var node : FlowNodeBase = object as FlowNodeBase
	if node != null:
		# name property should ot be modified by the user
		if name == "name" or name.begins_with( "resource_" ):
			return true
		if not node.exposeParam( name ):
			return true
		_creating_default_editor = true
		var editor := EditorInspector.instantiate_property_editor(object, type, name, hint_type, hint_string, usage_flags, wide)
		_creating_default_editor = false
		if editor:
			add_property_editor(name, editor, false, FlowLocale.translate_label(name))
			return true
	return false
