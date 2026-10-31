## ToastQueue — pure FIFO for the one global toast channel.
##
## ToastService owns presentation and timing; this class owns the order so the
## queue can be unit-tested headless. A message is never shown while another is
## visible: `push()` fills `current` only when idle and otherwise queues it.
class_name ToastQueue
extends RefCounted

var current: String = ""
var _pending: Array[String] = []


## Queues `message`. Returns true when the caller must start showing `current`.
## Consecutive duplicates are dropped so a noisy service cannot flood the screen.
func push(message: String) -> bool:
	var text := message.strip_edges()
	if text.is_empty():
		return false
	if text == current:
		return false
	if not _pending.is_empty() and _pending[_pending.size() - 1] == text:
		return false
	if current.is_empty():
		current = text
		return true
	_pending.append(text)
	return false


## Marks the visible message as finished and promotes the next one.
func complete() -> void:
	if _pending.is_empty():
		current = ""
		return
	current = _pending.pop_front()


## Number of messages waiting behind the visible one.
func pending_count() -> int:
	return _pending.size()


func is_active() -> bool:
	return not current.is_empty()


func clear() -> void:
	current = ""
	_pending.clear()
