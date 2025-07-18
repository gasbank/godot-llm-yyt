extends Control

@onready var my_input_text_edit: TextEdit = $InputTextEdit
@onready var my_button: Button = $SendButton
@onready var my_label: Label = $ErrorLabel

var click_count: int
var asking: bool
var total_logs: String

func _ready() -> void:
	my_button.pressed.connect(_on_button_pressed)
	my_button.mouse_entered.connect(_on_mouse_entered)
	my_button.mouse_exited.connect(_on_mouse_exited)
	
	my_input_text_edit.scroll_past_end_of_file = false
	
	OllamaClient.ollama_result.connect(_got_answer)
	
func _on_button_pressed() -> void:
	click_count = click_count + 1
	my_label.text = "대답을 기다리는 중!!! (%d회 째 요청)" % [click_count]
	_on_player_interact()

func _on_mouse_entered() -> void:
	#my_label.text = "mouse enter"
	pass
	
func _on_mouse_exited() -> void:
	#my_label.text = "mouse exit"
	pass

func _on_player_interact() -> void:
	if asking:
		return
		
	if my_input_text_edit.text.is_empty():
		pass
	else:
		# 사용자의 질문도 대화 로그 UI에 보여준다.
		$"../TextEdit".text += my_input_text_edit.text + "\n----------------\n"
		
		total_logs += my_input_text_edit.text + "\n"
		my_input_text_edit.text = ""
		OllamaClient.ask(total_logs)
		asking = true

func _got_answer(text):
	asking = false
	my_label.text = ""
	# 답변도 계속 로그에 붙여나간다.
	total_logs += text + "\n"
	print(text)
	#$DialogBox.show_message(text)

func _on_input_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_button_pressed()
			get_viewport().set_input_as_handled()
			#my_input_text_edit.text = ""
			
