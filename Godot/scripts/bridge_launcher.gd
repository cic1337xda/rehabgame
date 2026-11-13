extends Node

## Process identifier for active external bridge execution
var bridge_pid : int = -1

func _ready() -> void:
	_launch_telemetry_bridge()

## Spawns external Python telemetry bridge based on host platform architecture
func _launch_telemetry_bridge() -> void:
	var os_name = OS.get_name()
	var python_bin = "python"
	
	if os_name == "Linux" or os_name == "FreeBSD":
		python_bin = "python3"
		
	# Determine executing context: inside Godot editor or running standalone binary
	var resolved_script_path = ""
	
	if OS.has_feature("editor"):
		# In editor: inspect local project resource tree
		var candidate_paths = [
			"res://scripts/bridge-with-value.py",
			"res://bridge-with-value.py"
		]
		for path in candidate_paths:
			if FileAccess.file_exists(path):
				resolved_script_path = ProjectSettings.globalize_path(path)
				break
	else:
		# In exported executable: locate script sitting alongside the executable file
		var base_directory = OS.get_executable_path().get_base_dir()
		var candidate_paths = [
			base_directory.path_join("bridge-with-value.py"),
			base_directory.path_join("scripts/bridge-with-value.py")
		]
		for path in candidate_paths:
			if FileAccess.file_exists(path):
				resolved_script_path = path
				break

	if resolved_script_path.is_empty():
		printerr("[BRIDGE ERROR] Python bridge script could not be located on disk.")
		return

	# Launch detached background process
	bridge_pid = OS.create_process(python_bin, [resolved_script_path])
	
	if bridge_pid > 0:
		print("[BRIDGE] Telemetry bridge started with PID: ", bridge_pid)
	else:
		printerr("[BRIDGE ERROR] Failed to launch external Python bridge.")

## Ensures graceful process termination when Godot application terminates
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_terminate_telemetry_bridge()

## Terminates background sub-process
func _terminate_telemetry_bridge() -> void:
	if bridge_pid > 0:
		print("[BRIDGE] Terminating telemetry bridge PID: ", bridge_pid)
		OS.kill(bridge_pid)
		bridge_pid = -1
