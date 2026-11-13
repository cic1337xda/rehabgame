class_name LeaderboardManager
extends RefCounted

## File path designated for persistent JSON leaderboard storage within application user directory
const SAVE_PATH : String = "user://leaderboard.json"

## Developmental easter egg default entity configurations
const EASTER_EGG_NAME : String = "hehe"
const EASTER_EGG_SCORE : int = 999999999999

## Reads and parses the persistent JSON dataset into an in-memory array structure
static func load_leaderboard() -> Array:
	var records: Array = []
	
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var raw_content = file.get_as_text()
			file.close()

			var parse_result = JSON.parse_string(raw_content)
			if parse_result is Array:
				records = parse_result
			else:
				printerr("[STORAGE] Data schema mismatch or corrupt JSON payload in persistence store.")
		else:
			printerr("[STORAGE] Failed to open persistence store for reading: ", SAVE_PATH)

	# Verify and inject development easter egg record if missing from storage
	if _ensure_easter_egg_entry(records):
		save_leaderboard(records)

	return records

## Validates presence of developer easter egg and appends baseline benchmark entry if absent
static func _ensure_easter_egg_entry(records: Array) -> bool:
	for entry in records:
		if entry is Dictionary and entry.get("name", "").to_lower() == EASTER_EGG_NAME.to_lower():
			return false

	records.append({
		"name": EASTER_EGG_NAME,
		"high_score": EASTER_EGG_SCORE,
		"last_updated": Time.get_date_string_from_system()
	})
	return true

## Writes the in-memory array structure to persistent storage in formatted JSON
static func save_leaderboard(data: Array) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[STORAGE] Failed to open persistence store for writing: ", SAVE_PATH)
		return

	var serialized_json = JSON.stringify(data, "\t")
	file.store_string(serialized_json)
	file.close()

## Retrieves the existing record dictionary associated with a specified patient name
static func find_patient_record(patient_name: String) -> Dictionary:
	var records = load_leaderboard()
	for entry in records:
		if entry is Dictionary and entry.get("name", "").to_lower() == patient_name.strip_edges().to_lower():
			return entry
	return {}

## Evaluates whether a patient identifier is already registered in the persistent store
static func is_patient_registered(patient_name: String) -> bool:
	var record = find_patient_record(patient_name)
	return not record.is_empty()

## Updates the clinical performance record if the current session score supersedes previous metrics
static func record_session_score(patient_name: String, session_score: int) -> void:
	var sanitized_name = patient_name.strip_edges()
	if sanitized_name.is_empty():
		return

	var records = load_leaderboard()
	var record_found = false

	for i in range(records.size()):
		var entry = records[i]
		if entry is Dictionary and entry.get("name", "").to_lower() == sanitized_name.to_lower():
			record_found = true
			var previous_high = entry.get("high_score", 0)
			# Update high score only if current session performance surpasses prior threshold
			if session_score > previous_high:
				entry["high_score"] = session_score
				entry["last_updated"] = Time.get_date_string_from_system()
				records[i] = entry
			break

	# Append new clinical profile entry if not existing in repository
	if not record_found:
		records.append({
			"name": sanitized_name,
			"high_score": session_score,
			"last_updated": Time.get_date_string_from_system()
		})

	save_leaderboard(records)

## Retrieves the complete sorted list of patients ordered hierarchically by high score
static func get_sorted_records() -> Array:
	var records = load_leaderboard()
	records.sort_custom(func(a, b):
		return a.get("high_score", 0) > b.get("high_score", 0)
	)
	return records
