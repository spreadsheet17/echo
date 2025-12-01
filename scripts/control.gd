extends Control

# Signals to communicate back to the Main scene
signal restart_requested
signal quit_requested

# Assuming the buttons are children of a Panel and VBoxContainer
@onready var panel = $Panel
@onready var vbox_container = $Panel/VBoxContainer
@onready var restart_button = $Panel/VBoxContainer/RestartButton
@onready var quit_button = $Panel/VBoxContainer/QuitButton
@onready var title_label = $Panel/VBoxContainer/TitleLabel

func _ready():
	# Initial setup
	set_process_mode(Node.PROCESS_MODE_ALWAYS)

	hide()
	get_tree().paused = false
	
	# --- Button Text (Requested) ---
	restart_button.text = "Restart Maze"
	quit_button.text = "Quit Game"
	
	# Connect signals only if the buttons were found.
	if restart_button and quit_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
		quit_button.pressed.connect(_on_quit_button_pressed)
	else:
		# CRITICAL DEBUG: If this error shows up, your @onready paths are wrong.
		push_error("Exit Menu: Failed to find Restart or Quit buttons at expected paths ($Panel/VBoxContainer/...). Check your scene structure!")
	
	# --- Layout/Centering Fix ---
	self.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_container.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox_container.set_anchors_preset(Control.PRESET_CENTER)
	
	# Ensure mouse is captured initially for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func show_exit_menu(title_text: String):
	# Set the title
	title_label.text = title_text
	
	# Pause the game
	get_tree().paused = true
	
	# Show cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	show()

func _on_restart_button_pressed():
	# DEBUG: Check if this function is running
	print("--- DEBUG: Restart Button Pressed. Attempting to restart. ---")
	
	# HIDE MENU and UNPAUSE
	hide()
	get_tree().paused = false
	
	# Capture Mouse: Restore mouse control to the game for movement
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Emit signal for the main scene to handle the reload
	emit_signal("restart_requested")

func _on_quit_button_pressed():
	# DEBUG: Check if this function is running
	print("--- DEBUG: Quit Button Pressed. Attempting to quit. ---")

	# This command should instantly quit the application/editor
	get_tree().quit()
