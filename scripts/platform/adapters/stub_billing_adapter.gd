## StubBillingAdapter — no store on desktop/editor.
##
## Keeps the shop in its "Store unavailable" state while the debug simulate button
## exercises the local grant path (IapService.debug_simulate_purchase).
extends RefCounted

var _host: Node


func _init(host: Node) -> void:
	_host = host


func initialize(_callbacks: Dictionary) -> void:
	pass


func is_available() -> bool:
	return false


func price_for(_product_id: String) -> String:
	return ""


func purchase(_product_id: String) -> Dictionary:
	return {"response_code": 2, "debug_message": "store not available on this platform"}


func restore() -> void:
	if _host != null and _host.has_method("_on_restored"):
		_host.call("_on_restored", [])


func consume(_token: String) -> void:
	pass


func acknowledge(_token: String) -> void:
	pass
