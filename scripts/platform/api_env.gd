## ApiEnv — base URLs per build channel (spec 8.4), loaded from config/env.tres.
##
## Debug builds talk to the local FastAPI server. The Android emulator cannot
## reach the host loopback, so android_debug_base_url is used there; a device on
## the same LAN needs that value changed to the host's IP.
class_name ApiEnv
extends Resource

@export var debug_base_url: String = "http://127.0.0.1:8000"
@export var android_debug_base_url: String = "http://10.0.2.2:8000"
@export var release_base_url: String = "https://api.thetree.example"
@export var request_timeout_seconds: float = 10.0
@export var save_timeout_seconds: float = 15.0


## Base URL for the current build channel and platform.
func base_url() -> String:
	if OS.is_debug_build():
		if OS.has_feature("android") and not android_debug_base_url.is_empty():
			return android_debug_base_url
		return debug_base_url
	return release_base_url


## Base URL without a trailing slash (safe to concatenate a /v1 path).
func normalized_base_url() -> String:
	return base_url().strip_edges().trim_suffix("/")
