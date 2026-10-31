## MissionTemplateTable — the authored mission pool (spec 6.6).
##
## One resource (`res://data/missions/templates.tres`) holds every template so the
## generator and the tests load the same data. MissionService picks a deterministic
## subset per daily/weekly cycle.
class_name MissionTemplateTable
extends Resource

const PATH := "res://data/missions/templates.tres"

@export var templates: Array[MissionTemplate] = []


## Loads the authored table, or an empty one when the file is missing.
static func load_table(path: String = PATH) -> MissionTemplateTable:
	var resource: Resource = load(path)
	if resource is MissionTemplateTable:
		return resource as MissionTemplateTable
	push_error("MissionTemplateTable: cannot load '%s'" % path)
	return MissionTemplateTable.new()


func templates_for(period: StringName) -> Array[MissionTemplate]:
	var result: Array[MissionTemplate] = []
	for template: MissionTemplate in templates:
		if template != null and template.period == period:
			result.append(template)
	result.sort_custom(func(a: MissionTemplate, b: MissionTemplate) -> bool:
		if a.order == b.order:
			return String(a.id) < String(b.id)
		return a.order < b.order
	)
	return result
