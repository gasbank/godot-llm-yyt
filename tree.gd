extends Tree

func _ready():
	var root = create_item()
	root.set_text(0, "시작")
	#hide_root = true
	var child1 = create_item(root)
	child1.set_text(0, "자식 1")
	var child2 = create_item(root)
	child2.set_text(0, "자식 2")
	var subchild1 = create_item(child1)
	subchild1.set_text(0, "자식 1의 자식")
