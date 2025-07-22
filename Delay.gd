extends Node

func after(sec: float, callable: Callable) -> void:
	var t := get_tree().create_timer(sec)
	t.timeout.connect(callable)

func pause():
	print('hey')
	get_tree().paused = true
