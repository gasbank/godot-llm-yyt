extends RigidBody2D
class_name Bullet

@export var smooth_time      : float  = 0.25   # Unity SmoothDamp 의 Time
@export var max_force        : float  = 8000.0 # 힘 제한 (안정성)
@export var face_forward     : bool = true   # 바라보게 할지
@export var explosion_prefab: PackedScene

var target : Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_target(new_target: Node2D) -> void:
	target = new_target            # 타깃 교체
func clear_target() -> void:
	target = null                  # 타깃 해제
	
func _on_body_entered(other: Node) -> void:
	other.queue_free()
	_self_destruct()
	
func _self_destruct():
	queue_free()
	var explosion := preload('res://explosion.tscn').instantiate() as GPUParticles2D
	explosion.global_position = global_position
	explosion.restart()
	get_parent().add_child(explosion)
	
	
# _integrate_forces() 를 쓰면 서브‑스텝에서도 안정
func _integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	if not is_instance_valid(target):
		_self_destruct()
		return

	# --- 1) 스프링/댐퍼 계수 계산 (임계 감쇠) ----------------------------
	var tau     :float = max(smooth_time, 0.0001)        # 시정수
	var omega   := 2.0 / tau                       # 2/τ  (ω = 2ζ/τ, ζ=1)
	var k       := omega * omega * mass            # 스프링 상수 k = m·ω²
	var c       := 2.0 * mass * omega              # 댐핑 c = 2·m·ω    (임계)

	# --- 2) 현재 오차 & 힘 계산 -----------------------------------------
	var pos_err := target.global_position - global_position
	var vel_err := Vector2.ZERO - linear_velocity          # 목표 속도 = 0
	var force   := pos_err * k + vel_err * c               # F = ‑k·x ‑ c·v

	# --- 3) 힘 크기 제한 & 적용 -----------------------------------------
	if force.length() > max_force:
		force = force.normalized() * max_force

	apply_force(force)          # Godot 4.x (3.x: add_central_force)

	# --- 4) 회전 (선택) --------------------------------------------------
	if face_forward and linear_velocity.length() > 1.0:
		rotation = linear_velocity.angle()
