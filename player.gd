extends CharacterBody2D

# signals
signal s_jumped

# Moving variables
var speed = 300
var gravity = 200
var last_dir = Vector2.ZERO
var jump_force = 0
var is_grounded = true

# Animation variables
var anim
var direction = 0
var rotating = false
var is_moving = false
var jumping = false

func _process(delta):
	if !get_parent().dialogue_open:
		input(delta)
		animate()
		
func _physics_process(delta):
	if rotating:
		is_grounded = false
	elif not rotating:
		velocity.y += gravity + jump_force
		if velocity.y < 50:
			jumping = true
		else:
			jumping = false
		move_and_slide() # Move and slide HAS to be here due to order of execution, otherwise players can enter green gate from rotating without being grounded
		if is_on_ceiling():
			jump_force = -gravity
		if not is_on_floor():
			jump_force += 10
			is_grounded = false
		elif is_on_floor():
			is_grounded = true
	
# Handles dashing and moving
func input(delta):
	velocity = Vector2.ZERO
	
	if not rotating and Input.is_action_pressed("right"):
		velocity.x += 1
		direction = 1
	if not rotating and Input.is_action_pressed("left"):
		velocity.x -= 1
		direction = -1
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		s_jumped.emit()
		jump_force = -550
	if Input.is_action_pressed("rotation"):
		rotating = true
		is_grounded = false
		var room = get_parent().get_node("Level")
		if Input.is_action_just_pressed("right"):
			room.rotate(PI / 2)
		if Input.is_action_just_pressed("left"):
			room.rotate(-PI / 2)
	if Input.is_action_just_released("rotation"):
		rotating = false
		
	velocity = velocity.normalized() * speed
	
func animate():
	if direction == 1:
		$AnimatedSprite2D.flip_h = false
		$CollisionShape2D.position.x = 8
	else:
		$AnimatedSprite2D.flip_h = true
		$CollisionShape2D.position.x = -8
	if !is_on_floor():
		if jumping:
			$AnimatedSprite2D.play("Jump")
		else:
			$AnimatedSprite2D.play("Fall")
	elif velocity.x != 0:
		$AnimatedSprite2D.play("Run")
	else:
		$AnimatedSprite2D.play("Idle")

