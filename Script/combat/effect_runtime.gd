class_name EffectRuntime
extends RefCounted


var effect: EffectData


func _init(source_effect: EffectData = null) -> void:
	effect = source_effect


func apply(_source: Node, _target: Node) -> bool:
	# 当前阶段只保留统一执行入口，不执行任何实际效果。
	return false
