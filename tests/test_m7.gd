## M7 tests: backoff schedule, URL building, offline queue persistence, save sync
## policy/merge, remote config merge/TTL, server-row mapping and the
## "ApiClient is the only HTTPRequest owner" rule. No network is used.
extends RefCounted

const API_CLIENT_PATH := "res://scripts/platform/api_client.gd"


func test_api_backoff_schedule() -> Variant:
	var expected: Array[int] = [1000, 2000, 4000, 8000, 16000]
	for attempt in expected.size():
		if ApiBackoff.delay_msec(attempt) != expected[attempt]:
			return _fail("attempt %d should wait %d ms" % [attempt, expected[attempt]])
	if ApiBackoff.delay_msec(9) != 16000:
		return _fail("attempts clamp at 16 s")
	if ApiBackoff.delay_msec(0, 0.5) != 1500:
		return _fail("explicit jitter should extend the delay")
	for attempt in expected.size():
		var base := expected[attempt]
		var delay := ApiBackoff.jittered_delay_msec(attempt)
		if delay < int(base * 0.85) or delay > int(base * 1.15) + 1:
			return _fail("jittered delay %d outside ±15 %% of %d" % [delay, base])
	return true


func test_api_url_building() -> Variant:
	if ApiUrls.join("http://127.0.0.1:8000/", "/v1/save") != "http://127.0.0.1:8000/v1/save":
		return _fail("trailing slash must not double up")
	if ApiUrls.join("http://127.0.0.1:8000", "v1/config") != "http://127.0.0.1:8000/v1/config":
		return _fail("a path without a leading slash is accepted")
	var url := ApiUrls.build(
		"http://127.0.0.1:8000/",
		"/v1/leaderboard",
		{"scope": "weekly", "limit": 100, "cursor": ""}
	)
	if url != "http://127.0.0.1:8000/v1/leaderboard?scope=weekly&limit=100":
		return _fail("unexpected leaderboard URL: %s" % url)
	if not ApiUrls.build("http://x", "/v1/events", {"nickname": "a b"}).ends_with("nickname=a%20b"):
		return _fail("query values must be URI-encoded")
	if ApiUrls.build("http://x", "/v1/save", {}) != "http://x/v1/save":
		return _fail("an empty query must not add ?")
	return true


func test_api_result_typed() -> Variant:
	var ok := ApiResult.success(200, {"revision": 2})
	if not ok.ok or ok.status != 200 or int(ok.data.get("revision", 0)) != 2:
		return _fail("success factory")
	var failure := ApiResult.failure(409, &"stale_revision", "stale", false)
	if failure.ok or not failure.is_conflict() or failure.retryable:
		return _fail("409 must be a non-retryable conflict")
	failure.data = {"detail": {"code": "stale_revision", "server": {"revision": 4, "payload": {"a": 1}}}}
	if int(failure.server_save().get("revision", 0)) != 4:
		return _fail("conflict exposes the server copy")
	if not ApiResult.failure(0, &"timeout", "", true).retryable:
		return _fail("transport errors are retryable")
	return true


func test_api_queue_persistence() -> Variant:
	var queue := ApiQueue.new()
	var path := "user://api_queue_test.json"
	var op := ApiQueue.make_op(&"PUT", "/v1/save", {"revision": 0, "payload": {"a": 1}}, "key-1", 100)
	if not queue.enqueue(op):
		return _fail("first enqueue should succeed")
	if queue.enqueue(op.duplicate(true)):
		return _fail("the same idempotency key must not queue twice")
	if queue.size() != 1:
		return _fail("queue size should be 1")
	if not queue.save_to_file(path):
		return _fail("queue should persist")
	var restored := ApiQueue.new()
	if not restored.load_from_file(path) or restored.size() != 1:
		return _fail("queue should reload one operation")
	if str(restored.peek().get("idempotency_key", "")) != "key-1":
		return _fail("idempotency key should survive the round-trip")
	# A GET/diagnostic call is not a queueable mutation.
	if queue.enqueue(ApiQueue.make_op(&"GET", "/v1/save", {}, "key-2", 100)):
		return _fail("GET must not enter the offline queue")
	var failure := ApiQueue.make_op(&"PUT", "/v1/save", {}, "key-3", 100)
	queue.enqueue(failure)
	for attempt in 4:
		if not queue.mark_failure(failure):
			return _fail("attempt %d should still be retryable" % attempt)
	if queue.mark_failure(failure):
		return _fail("the fifth failure must drop the operation")
	if queue.size() != 1:
		return _fail("only the dropped operation should be gone")
	queue.clear()
	if not queue.is_empty():
		return _fail("clear empties the queue")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true


func test_save_sync_policy() -> Variant:
	if SaveSyncMerge.decide(true, 3, 3) != SaveSyncMerge.DECISION_PUSH:
		return _fail("equal revision + dirty pushes")
	if SaveSyncMerge.decide(false, 3, 3) != SaveSyncMerge.DECISION_NOOP:
		return _fail("equal revision + clean is a no-op")
	if SaveSyncMerge.decide(false, 2, 3) != SaveSyncMerge.DECISION_PULL:
		return _fail("server newer + clean pulls")
	if SaveSyncMerge.decide(true, 2, 3) != SaveSyncMerge.DECISION_MERGE:
		return _fail("server newer + dirty merges")
	if SaveSyncMerge.decide(true, 4, 3) != SaveSyncMerge.DECISION_PULL:
		return _fail("a server rollback is authoritative")
	return true


func test_save_sync_three_way_merge() -> Variant:
	var base := {
		"wallet": {"coins": 10, "gems": 1},
		"stats": {"best_wave": 5},
		"cards": {"equipped": [null, null]},
		"settings": {"music": 0.8},
	}
	var local := {
		"wallet": {"coins": 20, "gems": 1},
		"stats": {"best_wave": 9},
		"cards": {"equipped": ["greed", null]},
		"settings": {"music": 0.5, "language": "uk"},
	}
	var server := {
		"wallet": {"coins": 15, "gems": 2},
		"stats": {"best_wave": 5},
		"cards": {"equipped": [null, null]},
		"settings": {"music": 0.9},
		"shop": {"owned_products": ["thetree.no_ads"]},
	}
	var merged := SaveSyncMerge.three_way_merge(base, local, server)
	var payload: Dictionary = merged["payload"]
	if int(payload["wallet"]["coins"]) != 15:
		return _fail("a real conflict must resolve to the server value")
	if int(payload["wallet"]["gems"]) != 2:
		return _fail("unchanged local values take the server value")
	if int(payload["stats"]["best_wave"]) != 9:
		return _fail("a local-only change is kept as a patch")
	if str(payload["cards"]["equipped"][0]) != "greed":
		return _fail("local-only array change is kept")
	if not is_equal_approx(float(payload["settings"]["music"]), 0.9):
		return _fail("settings conflict resolves to the server")
	if str(payload["settings"]["language"]) != "uk":
		return _fail("a key added only locally survives the merge")
	if not payload.has("shop"):
		return _fail("a key added only on the server survives the merge")
	var conflicts: Array = merged["conflicts"]
	if not conflicts.has("wallet.coins") or not conflicts.has("settings.music"):
		return _fail("conflicts must be reported: %s" % str(conflicts))
	var applied: Array = merged["local_changes"]
	if not (applied.has("stats") or applied.has("stats.best_wave")):
		return _fail("local changes must be reported: %s" % str(applied))
	if base["wallet"]["coins"] != 10 or base["stats"]["best_wave"] != 5:
		return _fail("the merge must not mutate its inputs")
	return true


func test_remote_config_merge_and_ttl() -> Variant:
	var defaults := {
		"feature_flags": {"tournaments": true, "friends": false},
		"ad_frequency": {"interstitial_every_runs": 3},
		"list": [1, 2],
	}
	var remote := {"feature_flags": {"friends": true}, "list": [9]}
	var merged := RemoteConfigMerger.merge(defaults, remote)
	if not bool(merged["feature_flags"]["tournaments"]):
		return _fail("default flags are kept")
	if not bool(merged["feature_flags"]["friends"]):
		return _fail("remote flags override defaults")
	if int(merged["ad_frequency"]["interstitial_every_runs"]) != 3:
		return _fail("untouched nested sections survive")
	if merged["list"] != [9]:
		return _fail("lists are replaced, not merged")
	if bool(defaults["feature_flags"]["friends"]):
		return _fail("merge must not mutate the defaults")
	if not RemoteConfigMerger.is_fresh(100, 200, 3600):
		return _fail("a 100 s old cache is fresh")
	if RemoteConfigMerger.is_fresh(0, 100, 3600):
		return _fail("an absent cache is never fresh")
	if RemoteConfigMerger.is_fresh(100, 3701, 3600):
		return _fail("a cache older than the TTL is stale")
	return true


func test_leaderboard_backend_mapping() -> Variant:
	var row := LeaderboardBackend.parse_entry({
		"rank": 4,
		"player_id": "p-1",
		"nickname": "Elandra",
		"avatar_id": "avatar_03",
		"max_wave": 31,
		"playtime_s": 2400,
		"submitted_at": "2026-10-31T08:00:00.123456Z",
		"is_player": true,
	})
	if int(row["best_wave"]) != 31 or int(row["max_wave"]) != 31:
		return _fail("server max_wave maps to best_wave")
	if int(row["playtime"]) != 2400:
		return _fail("server playtime_s maps to playtime")
	if int(row["rank"]) != 4 or not bool(row["is_player"]):
		return _fail("rank and is_player are kept")
	if int(row["submitted_at"]) <= 0:
		return _fail("ISO timestamps must parse to unix seconds")
	var entries := LeaderboardBackend.parse_entries([row, "ignored", {}])
	if entries.size() != 2:
		return _fail("non-dictionary rows are skipped")
	return true


func test_env_and_remote_defaults_resources() -> Variant:
	var env := load("res://config/env.tres") as ApiEnv
	if env == null:
		return _fail("config/env.tres must load as ApiEnv")
	if not env.base_url().begins_with("http"):
		return _fail("env.tres must provide an http base URL")
	if not env.normalized_base_url().ends_with("8000") and not env.normalized_base_url().ends_with(".example"):
		return _fail("unexpected base URL: %s" % env.normalized_base_url())
	var defaults := load("res://config/remote_defaults.tres") as RemoteConfig
	if defaults == null:
		return _fail("config/remote_defaults.tres must load as RemoteConfig")
	if not bool(defaults.feature_flags.get("tournaments", false)):
		return _fail("remote defaults must enable tournaments")
	if int(defaults.ad_frequency.get("interstitial_every_runs", 0)) != 3:
		return _fail("remote defaults must carry the ad frequency")
	return true


func test_only_api_client_owns_http_request() -> Variant:
	var offenders: Array[String] = []
	_scan_scripts("res://scripts", offenders)
	for path: String in offenders:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("HTTPRequest.new(") and path != API_CLIENT_PATH:
			return _fail("HTTPRequest must only be created in ApiClient: %s" % path)
	if not FileAccess.file_exists(API_CLIENT_PATH):
		return _fail("ApiClient is missing")
	return true


func _scan_scripts(directory: String, offenders: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			_scan_scripts(path, offenders)
		elif entry.ends_with(".gd"):
			offenders.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _fail(message: String) -> Variant:
	print("  FAIL: ", message)
	return false
