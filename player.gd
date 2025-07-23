extends CharacterBody2D
@export var speed: float = 200.0    # 인스펙터에서 조정 가능
@export var gravity   : float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	#if Input.is_action_pressed("move_up"):
	#	dir.y -= 1
	#if Input.is_action_pressed("move_down"):
	#	dir.y += 1

	# 대각선 이동 속도 균일화
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	
	velocity.x = dir.x * speed
	
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, 2000)  # 낙하 속도 제한(선택)
		
	move_and_slide()                # CharacterBody2D 전용
