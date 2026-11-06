## ResourceDir — lists loadable resources in a directory, safely.
##
## Godot rewrites `.tres`/`.res` files into `<name>.remap` inside an exported
## build, so a naive `DirAccess` scan with an `ends_with(".tres")` filter finds
## nothing on Android (it works in the editor). This helper strips the `.remap`
## suffix and returns the original resource paths, which `load()` resolves.
class_name ResourceDir
extends RefCounted

const DEFAULT_EXTENSIONS := [".tres", ".res"]


static func list(dir_path: String, extensions: Array = DEFAULT_EXTENSIONS) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir():
			var clean := file.trim_suffix(".remap")
			for extension: String in extensions:
				if clean.ends_with(extension):
					var path := dir_path.path_join(clean)
					if not result.has(path):
						result.append(path)
					break
		file = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
