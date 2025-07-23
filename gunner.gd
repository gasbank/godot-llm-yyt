extends RigidBody2D

@export var target_position : Vector2
@export var speed           : float = 120      # 유지하고 싶은 ‘수평’ 속도
@export var accel_rate      : float = 6        # 보정 강도
@export var arrive_radius   : float = 8        # 도착 허용 오차

func _physics_process(delta):
	var to_target = target_position - global_position
	# 1) 도착 판정
	if to_target.length() <= arrive_radius:
		linear_velocity = Vector2.ZERO
		sleeping = true
		return

	# 2) ‘수평’ 방향 계산 (X축만 사용)
	var dir_x = sign(to_target.x)              # -1, 0, 1
	var desired_vel_x = dir_x * speed

	# 3) 가속 보정 (Y축은 그대로 둡니다)
	var delta_v_x = desired_vel_x - linear_velocity.x
	var impulse_x  = delta_v_x * mass * accel_rate * delta
	apply_central_impulse(Vector2(impulse_x, 0))
