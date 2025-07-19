# OllamaClient.gd (Autoload 추천)
extends Node
const URL := "http://127.0.0.1:11434/api/generate"
const MODEL := "gemma3:latest"

signal ollama_result(text: String)

@onready var http := HTTPRequest.new()

func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_response)

func ask(prompt: String) -> void:
	var payload := {
		"model": MODEL,
		"prompt": prompt,
		"stream": false        # true 로 두면 토큰 스트리밍
	}
	var body := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]
	var err := http.request(URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("HTTP request error: %s" % err)

func _on_response(_result, code, _headers, body):
	if code != 200:
		push_error("Ollama error %d" % code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	var text = json["response"]
	print("Ollama result: %s" % text)
	# 호출한 곳으로 결과 전달
	emit_signal("ollama_result", text)
