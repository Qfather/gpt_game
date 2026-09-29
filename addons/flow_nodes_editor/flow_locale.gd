extends RefCounted
class_name FlowLocale

const NODE_TITLES := {
	"add_attribute": "添加属性", "assets": "资源列表", "attract": "吸引", "attribute_random": "属性随机值",
	"attribute_rename": "重命名属性", "bounds_modifier": "边界调整", "clusterize": "聚类", "collapse_points": "合并近点",
	"comment": "注释", "compose_vector": "组合向量", "copy": "复制点", "create_points": "创建点", "create_spline": "创建样条",
	"debug": "调试可视化", "distance": "距离", "execution_index": "执行序号", "expression": "表达式", "filter_data_by_attribute": "按属性筛选数据",
	"filter_data_by_index": "按序号筛选数据", "filter_data_by_tag": "按标签筛选数据", "filter": "条件筛选", "get_bounds": "获取边界",
	"grid_boundary": "网格边界", "grid_connect_points": "网格连接点", "grid_fill_bounds": "填充网格边界", "grid": "生成网格",
	"input": "图输入", "make_bounds": "创建边界", "make_float": "创建浮点数", "make_rotation": "创建旋转", "make_string": "创建文本",
	"make_transform": "创建变换", "make_vector": "创建向量", "match_and_set": "匹配并设置", "math_op": "数学运算",
	"math_rotation_op": "旋转运算", "math_transform_op": "变换运算", "merge": "合并点集", "noise": "噪声采样", "output": "图输出",
	"partition": "分区", "point_offsets": "点偏移", "print_string": "打印文本", "random_color": "随机颜色", "ray_cast": "射线检测",
	"redirect_input": "重定向输入", "redirect_output": "重定向输出", "reduce": "归并", "relax": "点位松弛", "remap": "数值映射",
	"remove_attribute": "移除属性", "sample_around": "周围采样", "sample_mesh": "网格采样", "sample_points": "点采样",
	"sample_spline": "样条采样", "sanity_check": "点数据检查", "scan_meshes": "扫描网格", "scan_nodes": "扫描节点",
	"scan_splines": "扫描样条", "select_points": "选择点", "select": "选择数据", "self_pruning": "邻近点裁剪",
	"sequence_sample": "序列采样", "size": "点数量", "snap_to_grid": "吸附到网格", "sort": "排序点", "spawn_meshes": "生成网格实例",
	"spawn_scenes": "生成场景实例", "spline_intersection": "样条求交", "subdivide_spline": "细分样条", "subgraph": "子图",
	"substract": "差集 / 交集", "surface_sampler": "表面采样", "torus_volume_sampler": "环体采样", "tags_mutate": "标签操作", "transform": "随机变换点",
	"watabou_dungeon": "Watabou 地牢导入", "watabou_dwelling": "Watabou 民居导入"
}

const CATEGORIES := {
	"Metadata": "属性", "Spatial": "空间", "Point Ops": "点集处理", "Sampler": "采样", "Debug": "调试",
	"Math": "数学", "Filter": "筛选", "Uncategorized": "其他", "Control Flow": "流程控制", "Spawner": "实例生成", "Import": "导入"
}

const LABELS := {
	"In": "输入", "Out": "输出", "Data": "数据", "Input": "输入", "Target": "目标", "Attributes": "属性集",
	"Attractors": "吸引点", "Anchors": "中心点", "Centroids": "中心点", "Inside": "符合", "Outside": "不符合", "True": "是", "False": "否",
	"Filled Cells": "已填充单元", "Edges": "边缘", "Corners": "角点", "All": "全部", "Cells": "网格单元", "Bounds": "边界",
	"Splines": "样条", "Pieces": "片段", "Rooms": "房间", "Doors": "门", "Columns": "柱子", "Water": "水体", "Notes": "备注",
	"Floors": "楼层", "Windows": "窗户", "Stairs": "楼梯", "Translation": "位移", "Rotation": "旋转", "Scale": "缩放",
	"In A": "输入 A", "In B": "输入 B", "In C": "输入 C", "Output": "输出", "Execution Index": "执行序号"
}

const DESCRIPTIONS := {
	"add_attribute": "为点数据添加常量属性；未连接输入时会创建一个包含该常量的点。",
	"assets": "创建带有属性、标签和权重的资源列表，可配合“匹配并设置”节点使用。",
	"attract": "将输入点的属性匹配到最近的吸引点。",
	"attribute_random": "为点属性写入随机值或连续序号。",
	"attribute_rename": "重命名属性或数据流，同时保留数据类型和值。",
	"bounds_modifier": "修改点数据中的尺寸与边界信息。",
	"clusterize": "按最大距离将点划分为多个簇，并可输出簇中心。",
	"collapse_points": "合并彼此距离过近的点。",
	"comment": "向流程图添加自定义注释。",
	"compose_vector": "从多个浮点属性或默认值组合出三维向量。",
	"copy": "复制当前点集，并按重复的位移与旋转偏移排列。",
	"create_points": "使用自定义的位置、旋转和尺寸创建点集。",
	"create_spline": "根据输入点创建一条样条曲线。",
	"debug": "强制启用节点数据可视化，便于查看指定调试结果。",
	"distance": "计算每个点到另一组点的最近距离，可按最大距离归一化。",
	"execution_index": "返回当前流程图执行上下文的调用序号。",
	"expression": "使用表达式计算属性值。",
	"filter_data_by_attribute": "根据是否包含指定属性拆分数据。",
	"filter_data_by_index": "按序号或切片表达式选择数据项。",
	"filter_data_by_tag": "按标签拆分数据，可指定多个标签。",
	"filter": "按条件将输入数据拆分为两组。",
	"get_bounds": "获取节点或网格关联的边界信息。",
	"grid_boundary": "从填充的网格单元中提取外露边缘和角点。",
	"grid_connect_points": "在 XZ 平面上用正交网格路径连接排序后的点。",
	"grid_fill_bounds": "在输入或指定边界内为每个网格单元创建一个点。",
	"grid": "按设定间距生成规则网格点。",
	"input": "将流程图节点的输入参数暴露到图中。",
	"make_bounds": "在中心位置创建一个带尺寸的边界点。",
	"make_float": "创建单个浮点数值。",
	"make_rotation": "创建单个旋转值。",
	"make_string": "创建单个文本值。",
	"make_transform": "组合位移、旋转和缩放，创建变换值。",
	"make_vector": "使用三个浮点分量创建单个向量。",
	"match_and_set": "根据匹配属性将资源属性复制到输入点数据。",
	"merge": "合并多个点集及其属性流。",
	"noise": "使用噪声生成或调整点的位置与属性。",
	"output": "将数据从流程图中输出。",
	"point_offsets": "围绕每个输入点按指定偏移创建子点，适合布置重复对象。",
	"print_string": "在输出面板中打印文本，便于调试。",
	"random_color": "为点生成随机颜色。",
	"ray_cast": "从点发射射线并读取命中信息。",
	"spawn_meshes": "在每个点实例化网格，并应用点的位置、旋转和缩放。",
	"spawn_scenes": "在每个点实例化完整场景，并可将点属性赋给场景节点。",
	"sample_spline": "沿输入样条轮廓或内部采样点。",
	"surface_sampler": "在输入点集的边界范围内随机采样点。",
	"torus_volume_sampler": "以输入点为圆环中心，在圆环管状体积内均匀采样，可直接连接实例生成节点。",
	"tags_mutate": "添加、移除或替换数据标签。",
	"transform": "为每个点随机应用位移、旋转和缩放。",
	"watabou_dungeon": "导入 Watabou 导出的 JSON 地牢数据。",
	"watabou_dwelling": "导入 Watabou 导出的 JSON 民居数据。"
}

static func translate_node_meta(template: String, meta: Dictionary) -> Dictionary:
	var localized := meta.duplicate(true)
	localized.title = NODE_TITLES.get(template, str(meta.get("title", template)))
	localized.category = CATEGORIES.get(str(meta.get("category", "")), str(meta.get("category", "其他")))
	if DESCRIPTIONS.has(template):
		localized.tooltip = DESCRIPTIONS[template]
	else:
		localized.tooltip = "用于处理“%s”的流程数据节点。" % localized.title
	for group_name in ["ins", "outs"]:
		var ports: Array = localized.get(group_name, [])
		for port in ports:
			var label := str(port.get("label", ""))
			port.label = LABELS.get(label, label)
		localized[group_name] = ports
	return localized

static func translate_label(value: String) -> String:
	var words := {
		"offset": "偏移", "offsets": "偏移量", "min": "最小", "max": "最大", "minimum": "最小值", "maximum": "最大值",
		"scale": "缩放", "rotation": "旋转", "position": "位置", "translation": "位移", "size": "尺寸",
		"uniform": "均匀", "random": "随机", "randomize": "随机化", "seed": "随机种子", "attribute": "属性", "index": "序号",
		"name": "名称", "value": "数值", "count": "数量", "distance": "距离", "radius": "半径", "angle": "角度",
		"points": "点", "point": "点", "grid": "网格", "cell": "单元", "bounds": "边界", "surface": "表面", "mesh": "网格模型",
		"scene": "场景", "variant": "变体", "weight": "权重", "weights": "权重", "color": "颜色", "enabled": "启用",
		"local": "局部", "world": "世界", "space": "空间", "fill": "填充", "curve": "曲线", "spline": "样条", "tag": "标签", "tags": "标签",
		"input": "输入", "output": "输出", "type": "类型", "mode": "模式", "operation": "运算", "condition": "条件", "threshold": "阈值",
		"factor": "系数", "step": "步长", "interval": "间隔", "resolution": "分辨率", "smooth": "平滑", "strength": "强度", "noise": "噪声",
		"direction": "方向", "segments": "分段数", "selector": "选择器", "target": "目标", "source": "来源", "density": "密度",
		"distribution": "分布", "axis": "轴", "order": "顺序", "range": "范围", "resource": "资源", "float": "浮点数", "int": "整数",
	"string": "文本", "vector": "向量", "bool": "布尔值", "add": "加", "multiply": "乘", "subtract": "减", "sample": "采样",
	"center": "中心", "interior": "内部", "border": "边缘", "tolerance": "容差", "random_seed": "随机种子", "length": "长度",
	"max_distance": "最大距离", "num_clusters": "簇数量", "cluster": "簇", "clusters": "簇", "padding": "边距",
	"attribute_name": "属性名称", "attr_name": "属性名称", "out_name": "输出名称", "out_attribute": "输出属性",
	"data_type": "数据类型", "inspect_enabled": "启用数据检查", "debug_enabled": "启用调试", "debug_mode": "调试模式",
	"debug_scale": "调试缩放", "debug_output": "调试输出", "debug_bulk": "调试批次",
	"debug_port_combined_index": "调试端口序号", "debug_color": "调试颜色", "debug_modulate_by": "调试调制属性",
	"debug_mesh_resource": "调试网格资源", "disabled": "禁用节点", "trace": "输出追踪日志",
	"in_name_a": "输入 A 名称", "in_name_b": "输入 B 名称", "in_name_c": "输入 C 名称", "axis_y": "Y 轴方向",
	"axis_order": "轴顺序", "fit_behaviour": "适配方式", "fit_behavior": "适配方式", "num_samples": "采样数量",
	"one_per_vertex": "每个顶点一个", "face_centers": "面中心", "quasi_random_2_d": "准随机二维", "quasi_random_3_d": "准随机三维",
	"blue_noise_2_d": "蓝噪声二维", "uniform_grid": "均匀网格",
	"from_z": "根据 Z 方向", "from_z_and_y": "根据 Z 与 Y 方向", "from_axis_and_angle": "根据轴与角度",
	"transform_location": "变换位置", "transform_direction": "变换方向", "as_default_debug_draw": "默认调试绘制",
	"as_text": "文本", "as_vector_line": "向量线", "as_line_to": "连线到目标", "as_axis": "坐标轴",
	"by_distance": "按距离", "by_attribute": "按属性", "by_num_clusters": "按簇数量", "by_max_distance": "按最大距离",
	"exact_match": "完全匹配", "starts_with": "开头匹配", "any_where": "任意位置匹配", "x_then_z": "先 X 后 Z", "z_then_x": "先 Z 后 X",
	"greater_or_equal": "大于等于", "less_or_equal": "小于等于", "almost_equal": "近似相等", "logical_a_n_d": "逻辑与",
	"logical_o_r": "逻辑或", "logical_x_o_r": "逻辑异或", "is_null": "为空", "between_excluding_min_max": "区间内（不含端点）",
	"between_including_min_max": "区间内（含端点）", "between_including_min": "区间内（含最小值）", "between_including_max": "区间内（含最大值）",
	"zero_to_one": "0 到 1", "minus_one_to_one": "-1 到 1", "world_3_d": "三维世界空间", "x_z_2_d": "XZ 平面",
	"value_cubic": "立方值噪声", "cellular": "细胞噪声", "simplex_smooth": "平滑单纯形噪声", "f_b_m": "分形布朗运动",
	"ridged": "脊状分形", "ping_pong": "乒乓分形", "override": "覆盖", "use_density": "按密度采样",
	"use_num_samples": "按采样数量", "align_left": "左对齐", "autoscale": "自动缩放", "centered": "居中",
	"align_right": "右对齐", "interspace": "均匀间隔", "a_minus_b": "A 减 B", "a_intersection_b": "A 与 B 的交集",
	"combine": "组合", "invert": "反转", "lerp": "插值",
	"title": "标题", "debug": "调试", "inspect": "检查", "cte": "常量", "data": "数据",
	"in": "输入", "out": "输出", "num": "数量", "attr": "属性", "attributes": "属性", "args": "参数",
	"major_radius": "环半径", "minor_radius": "管道半径", "num_points": "采样数量", "point_size": "点尺寸",
	"tangent_rotation_enabled": "切向旋转", "tangent_rotation_offset": "切向旋转偏移",
	"a": "A", "b": "B", "c": "C", "x": "X", "y": "Y", "z": "Z", "as": "作为", "by": "按",
	"from": "来源", "to": "目标", "use": "使用", "copy": "复制", "generate": "生成", "new": "新建",
	"adjust": "调整", "amplitude": "振幅", "anchor": "锚点", "arrays": "数组", "assets": "资源",
	"assign": "赋值", "behaviour": "方式", "bias": "偏移", "borders": "边界", "bulk": "批次",
	"case": "大小写", "cells": "单元", "centers": "中心", "class": "类", "colors": "颜色",
	"combined": "合并", "copies": "副本", "corners": "角点", "csv": "CSV", "deduplicate": "去重",
	"default": "默认", "descending": "降序", "dir": "方向", "existing": "已有", "expose": "公开",
	"expression": "表达式", "filter": "筛选", "fit": "适配", "fractal": "分形", "gain": "增益",
	"grammar": "语法", "graph": "流程图", "group": "分组", "groups": "分组", "height": "高度",
	"hue": "色相", "id": "编号", "include": "包含", "indices": "索引", "inherit": "继承",
	"intersections": "交点", "iterations": "迭代次数", "keep": "保留", "label": "标签", "labels": "标签",
	"lacunarity": "间隙度", "match": "匹配", "message": "消息", "modulate": "调制", "names": "名称",
	"normal": "法线", "octaves": "倍频", "origin": "原点", "overrides": "覆盖值", "overwrite": "覆盖",
	"palette": "调色板", "parent": "父级", "partition": "分区", "path": "路径", "phase": "相位",
	"ping": "往返", "pong": "往返", "port": "端口", "positions": "位置", "prefix": "前缀",
	"print": "打印", "ratio": "比例", "remap": "重映射", "result": "结果", "rotations": "旋转",
	"samples": "采样数", "sampling": "采样", "sat": "饱和度", "scalable": "可缩放", "select": "选择",
	"selected": "选中", "self": "自身", "sensitive": "敏感", "show": "显示", "sizes": "尺寸",
	"snap": "吸附", "sort": "排序", "spawn": "生成", "start": "起点", "symbol": "符号",
	"test": "测试", "text": "文本", "thickness": "厚度", "transform": "变换", "val": "值",
	"variants": "变体", "vertex": "顶点", "wall": "墙体", "width": "宽度"
	}
	var normalized := value.to_snake_case()
	if words.has(normalized):
		return words[normalized]
	var parts := normalized.split("_")
	for i in range(parts.size()):
		parts[i] = words.get(parts[i], parts[i].capitalize())
	return " ".join(parts)

static func translate_title(value: String, template: String, base_title: String) -> String:
	if template == "substract" and value == "Intersection":
		return "交集"
	if NODE_TITLES.has(template) and value == base_title:
		return NODE_TITLES[template]
	return value

static func translate_enum_hint(hint: String) -> String:
	var translations := {
		"Float": "浮点数", "Int": "整数", "String": "文本", "Vector": "向量", "Color": "颜色", "Bool": "布尔值",
		"Set": "设置", "Add": "加", "Multiply": "乘", "Subtract": "差集", "Intersection": "交集",
		"Nearest": "最近点", "Random": "随机", "Uniform": "均匀", "Grid": "网格", "PoissonDisc": "泊松圆盘",
		"Linear": "线性", "Radial": "径向", "World": "世界空间", "Local": "局部空间", "Relative": "相对",
		"Position": "位置", "Rotation": "旋转", "Size": "尺寸", "Scale": "缩放", "GreaterThan": "大于", "LessThan": "小于",
		"Equal": "等于", "NotEqual": "不等于", "Between": "介于", "Perlin": "柏林噪声", "Simplex": "单纯形噪声", "Value": "值噪声",
		"Fractal": "分形", "None": "无", "Tiled": "平铺", "Corners": "角点", "Edges": "边缘", "Both": "两者",
		"ByDistance": "按距离", "ByAttribute": "按属性", "ByNumClusters": "按簇数量", "ByMaxDistance": "按最大距离",
		"AsDefaultDebugDraw": "默认调试绘制", "AsText": "文本", "AsVectorLine": "向量线", "AsLineTo": "连线到目标", "AsAxis": "坐标轴",
		"ExactMatch": "完全匹配", "StartsWith": "开头匹配", "AnyWhere": "任意位置匹配", "XThenZ": "先 X 后 Z", "ZThenX": "先 Z 后 X",
		"Greater": "大于", "GreaterOrEqual": "大于等于", "Less": "小于", "LessOrEqual": "小于等于", "AlmostEqual": "近似相等",
		"LogicalAND": "逻辑与", "LogicalOR": "逻辑或", "LogicalXOR": "逻辑异或", "IsNull": "为空",
		"BetweenExcludingMinMax": "区间内（不含端点）", "BetweenIncludingMinMax": "区间内（含端点）",
		"BetweenIncludingMin": "区间内（含最小值）", "BetweenIncludingMax": "区间内（含最大值）",
		"Absolute": "绝对值", "Saturate": "限制到 0-1", "Floor": "向下取整", "FloorAsInt": "向下取整为整数",
		"Modulo": "取余数", "ModuloInt": "整数取余", "Frac": "小数部分", "Max": "最大值", "Min": "最小值",
		"OneMinus": "1 减去输入值", "Pow": "乘方", "Round": "四舍五入", "Sign": "符号", "Sqrt": "平方根",
		"Negate": "取反", "From_Z": "根据 Z 方向", "From_Z_And_Y": "根据 Z 与 Y 方向", "From_Axis_And_Angle": "根据轴与角度",
		"Combine": "组合", "Invert": "反转", "Lerp": "插值", "Transform_Location": "变换位置", "Transform_Direction": "变换方向",
		"UniformGrid": "均匀网格", "QuasiRandom2D": "准随机二维", "QuasiRandom3D": "准随机三维", "BlueNoise2D": "蓝噪声二维",
		"UseDensity": "按密度采样", "UseNumSamples": "按采样数量", "OnePerVertex": "每个顶点一个", "FaceCenters": "面中心",
		"AlignLeft": "左对齐", "Autoscale": "自动缩放", "Centered": "居中", "AlignRight": "右对齐", "Interspace": "均匀间隔",
		"A_Minus_B": "A 减 B", "A_Intersection_B": "A 与 B 的交集", "ZeroToOne": "0 到 1", "MinusOneToOne": "-1 到 1",
		"World3D": "三维世界空间", "XZ2D": "XZ 平面", "ValueCubic": "立方值噪声", "Cellular": "细胞噪声",
		"SimplexSmooth": "平滑单纯形噪声", "FBM": "分形布朗运动", "Ridged": "脊状分形", "PingPong": "乒乓分形",
		"Override": "覆盖", "Remove": "移除", "Replace": "替换", "FromTranslationRotationScale": "由位移、旋转和缩放创建"
	}
	var values := hint.split(",")
	for i in range(values.size()):
		var key := values[i].strip_edges()
		values[i] = translations.get(key, key)
	return ",".join(values)

static func translate_node_title(node: Object) -> String:
	var title: String = str(node.call("getTitle"))
	var node_meta: Dictionary = node.get("meta_node")
	var base_title := str(node_meta.get("title", ""))
	if title == base_title:
		return NODE_TITLES.get(str(node.get("template_name")), title)
	var dynamic_titles := {
		"Expression": "表达式", "Greater Than": "大于", "Less Than": "小于", "Equal": "等于", "Not Equal": "不等于",
		"Add": "加法", "Subtract": "减法", "Multiply": "乘法", "Divide": "除法", "Intersection": "交集", "Substract": "差集"
	}
	if dynamic_titles.has(title):
		return dynamic_titles[title]
	var template := str(node.get("template_name"))
	if template == "add_attribute":
		var type_name: String = FlowData.DataType.keys()[int(node.get("data_type"))]
		return "%s - %s" % [str(node.get("attr_name")), translate_enum_hint(type_name)]
	if template == "filter":
		return translate_enum_hint(title.replace(" ", ""))
	if template == "math_rotation_op":
		return translate_enum_hint(title)
	if template == "partition":
		return "分区：%s" % str(node.get("attribute_name"))
	if template == "subgraph" and title == "Subgraph":
		return "子图"
	return title
