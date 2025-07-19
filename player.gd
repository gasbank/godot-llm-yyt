extends CharacterBody2D
@export var speed: float = 200.0    # 인스펙터에서 조정 가능

func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1

	# 대각선 이동 속도 균일화
	if dir != Vector2.ZERO:
		dir = dir.normalized()

	velocity = dir * speed
	move_and_slide()                # CharacterBody2D 전용
