extends Node

static func get_random_with_script(root_node: Node, target_script: Script) -> Node:
	var current_root := root_node
	if current_root == null:
		return null
		
	var stack : Array[Node] = [current_root]
	var bucket : Array[Node] = []
	
	while stack.size() > 0:
		var n : Node = stack.pop_back()
		if n.get_script() == target_script:
			bucket.append(n)
		stack.append_array(n.get_children())
	
	return bucket.pick_random() if bucket else null
