## AnalyticsService — privacy-aware event logging (spec 8.6).
##
## Debug builds always print events. Network batching is OFF unless
## res://config/monetization.tres sets analytics_enabled. Batches go through
## ApiClient to POST /v1/events (the only HTTPRequest owner since M7). Events are
## dropped when offline or when the request fails (no unbounded queue), and the
## only identifier the server stores is the authenticated player id.
extends Node

const MAX_QUEUE := 100
const FLUSH_INTERVAL_SECONDS := 30.0

var _config: MonetizationConfig
var _enabled: bool = false
var _queue: Array[Dictionary] = []
var _flush_timer: float = 0.0
var _sending: bool = false
var _sent_count: int = 0
var _dropped_count: int = 0


func _ready() -> void:
	_config = MonetizationConfig.load_config()
	_enabled = _config.analytics_enabled
	set_process(_enabled)
	# Launch events from the global bus (spec 8.6); no gameplay code changes.
	EventBus.run_started.connect(func() -> void:
		track(&"run_start", {"at": TimeService.now_unix()})
	)
	EventBus.wave_cleared.connect(func(wave: int) -> void:
		track(&"wave_cleared", {"wave": wave})
	)
	EventBus.scene_changed.connect(func(scene_id: StringName) -> void:
		track(&"screen_view", {"screen": String(scene_id)})
	)


## Init hook used by App; analytics never blocks boot and never fails it.
func init_service() -> void:
	pass


## Records one event. `props` must contain only non-personal gameplay data.
func track(event: StringName, props: Dictionary = {}) -> void:
	if OS.is_debug_build():
		print("[Analytics] %s %s" % [event, JSON.stringify(props)])
	if not _enabled:
		return
	var entry := {
		"name": String(event),
		"client_ts": TimeService.now_unix(),
		"props": _sanitize(props),
	}
	_queue.append(entry)
	if _queue.size() > MAX_QUEUE:
		_queue.pop_front()
		_dropped_count += 1
	if _queue.size() >= maxi(_config.analytics_batch_size, 1):
		flush()


func _process(delta: float) -> void:
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL_SECONDS:
		_flush_timer = 0.0
		flush()


## Sends the pending batch through ApiClient. Safe to call from tests.
func flush() -> void:
	if not _enabled or _sending or _queue.is_empty():
		return
	if not ApiClient.is_online() or not ApiClient.is_authenticated():
		_dropped_count += _queue.size()
		_queue.clear()
		return
	var batch_size := clampi(_config.analytics_batch_size, 1, _queue.size())
	var batch: Array = _queue.slice(0, batch_size)
	# Remove optimistically: a failed request is dropped, per spec 8.6.
	_queue = _queue.slice(batch_size)
	_sending = true
	_send_batch(batch)


func _send_batch(batch: Array) -> void:
	var result: ApiResult = await ApiClient.request(
		&"POST", "/v1/events", {"events": batch}, {"queue": false, "retry_attempts": 1}
	)
	_sending = false
	if result.ok:
		_sent_count += batch.size()
	else:
		_dropped_count += batch.size()
	if not _queue.is_empty():
		flush()


## Drops any pending batch (used by tests and on shutdown).
func clear() -> void:
	_queue.clear()


func is_enabled() -> bool:
	return _enabled


func pending_count() -> int:
	return _queue.size()


func dropped_count() -> int:
	return _dropped_count


func _sanitize(props: Dictionary) -> Dictionary:
	# Never send free-form personal data: keep scalars only, drop huge strings.
	var clean := {}
	for key: String in props.keys():
		var value: Variant = props[key]
		if value is String:
			clean[key] = (value as String).substr(0, 120)
		elif value is int or value is float or value is bool:
			clean[key] = value
	return clean


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()
