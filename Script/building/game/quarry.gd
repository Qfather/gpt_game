class_name Quarry
extends ResourceBuildingBase


# ============================================================
# 初始化
# ============================================================

func _ready() -> void:

	super._ready()

	print("========== Quarry 启动 ==========")


# ============================================================
# 分配矿工职业
# ============================================================

func assign_worker_job(worker: Node) -> void:

	worker.assign_job(
		worker.Job.MINER,
		self
	)
