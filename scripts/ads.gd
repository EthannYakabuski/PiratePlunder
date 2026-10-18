extends Node
## Android-only Poing 5.1 adapter. Native wrappers are loaded lazily, so the
## plugin's editor mock factory never serves ads in a desktop game or capture.
signal availability_changed
signal banner_space_changed(height: float)
signal fullscreen_started(kind: String)
signal fullscreen_finished(kind: String)

const TEST_UNITS := {"banner":"ca-app-pub-3940256099942544/9214589741", "interstitial":"ca-app-pub-3940256099942544/1033173712", "rewarded":"ca-app-pub-3940256099942544/5224354917"}
const LOAD_TIMEOUT := 30.0
const CONSENT_TIMEOUT := 45.0
const SHOW_TIMEOUT := 180.0
const MAX_LOAD_ATTEMPTS := 4
const RETRY_BURST_COOLDOWN := 240.0
const MAX_AD_AGE := 3300.0

var config: Dictionary = {}
var status := "Ads unavailable on this device"
var save_path := "user://pirateplunder-ad-cadence.json"
var completed_runs := 0
var _due := false
var _backend: Object
var _injected := false
var _consent_busy := false
var _consent_token := 0
var _consent_phase := ""
var _consent_time := 0.0
var _consent_ui := false
var _can_request := false
var _sdk_started := false
var _sdk_ready := false
var _sdk_time := 0.0
var _init_token := 0
var _home := false
var _banner: Object
var _banner_loaded := false
var _banner_token := 0
var _banner_time := 0.0
var _banner_retry := 0.0
var _banner_attempts := 0
var _banner_height := 0.0
var _banner_width := 0
var _slots := {"rewarded":{"ad":null,"loading":false,"generation":0,"attempts":0,"timeout":0.0,"retry":0.0,"age":0.0}, "interstitial":{"ad":null,"loading":false,"generation":0,"attempts":0,"timeout":0.0,"retry":0.0,"age":0.0}}
var _active_kind := ""
var _active_ad: Object
var _active_token := 0
var _active_completion: Callable
var _active_earned := false
var _active_time := 0.0
var _active_presented := false
var _suspended := false

# This normalized bridge uses only APIs present in the supplied plugin. It is
# never constructed on desktop. Tests inject a separate fake with this API.
class NativeBackend extends RefCounted:
	const BASE := "res://addons/admob/gdscript/src/"
	var _initialization_listener: Object
	func _script(path: String) -> Variant:
		return load(BASE + path + ".gd")
	func consent_update(success: Callable, failure: Callable) -> void:
		var ump = _script("ump/api/UserMessagingPlatform")
		ump.consent_information.update(_script("ump/core/ConsentRequestParameters").new(), success, failure)
	func can_request_ads() -> bool:
		var native := Engine.get_singleton("PoingGodotAdMobConsentInformation")
		if native.has_method("can_request_ads"):
			return bool(native.call("can_request_ads"))
		# The supplied v5.1 GDScript API exposes status rather than canRequestAds.
		# UMP's NOT_REQUIRED/OBTAINED statuses are the only accepted fallback.
		var information = _script("ump/api/UserMessagingPlatform").consent_information
		return int(information.get_consent_status()) in [1, 3]
	func consent_required() -> bool:
		return int(_script("ump/api/UserMessagingPlatform").consent_information.get_consent_status()) == 2
	func form_available() -> bool:
		return _script("ump/api/UserMessagingPlatform").consent_information.get_is_consent_form_available()
	func load_form(success: Callable, failure: Callable) -> void:
		_script("ump/api/UserMessagingPlatform").load_consent_form(success, failure)
	func show_form(form: Object, dismissed: Callable) -> void:
		form.show(dismissed)
	func privacy_required() -> bool:
		return int(_script("ump/api/UserMessagingPlatform").consent_information.get_privacy_options_requirement_status()) == 2
	func show_privacy(dismissed: Callable) -> void:
		_script("ump/api/UserMessagingPlatform").show_privacy_options_form(dismissed)
	func initialize(completed: Callable) -> void:
		_initialization_listener = _script("api/listeners/OnInitializationCompleteListener").new()
		_initialization_listener.on_initialization_complete = completed
		# Leave child-directed, under-age and content rating request defaults alone.
		_script("api/MobileAds").initialize(_initialization_listener)
	func load_fullscreen(kind: String, unit: String, success: Callable, failure: Callable) -> void:
		var prefix := "Rewarded" if kind == "rewarded" else "Interstitial"
		var listener = _script("api/listeners/" + prefix + "AdLoadCallback").new()
		listener.on_ad_loaded = success
		listener.on_ad_failed_to_load = failure
		_script("api/" + prefix + "AdLoader").new().load(unit, _script("api/core/AdRequest").new(), listener)
	func show_fullscreen(kind: String, ad: Object, earned: Callable, dismissed: Callable, failed: Callable, shown: Callable) -> void:
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = dismissed
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = failed
		ad.full_screen_content_callback.on_ad_showed_full_screen_content = shown
		if kind == "rewarded":
			var listener = _script("api/listeners/OnUserEarnedRewardListener").new()
			listener.on_user_earned_reward = earned
			ad.show(listener)
		else:
			ad.show()
	func create_banner(unit: String, success: Callable, failure: Callable) -> Object:
		var size_script = _script("api/core/AdSize")
		var size = size_script.get_current_orientation_anchored_adaptive_banner_ad_size(size_script.FULL_WIDTH)
		var banner = _script("api/AdView").new(unit, size, _script("api/core/AdPosition").BOTTOM)
		banner.ad_listener.on_ad_loaded = success
		banner.ad_listener.on_ad_failed_to_load = failure
		banner.hide()
		return banner
	func load_banner(banner: Object) -> void:
		banner.load_ad(_script("api/core/AdRequest").new())

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/admob.json")) if FileAccess.file_exists("res://config/admob.json") else {}
	if parsed is Dictionary: config = parsed
	_load_count()
	if get_viewport(): get_viewport().size_changed.connect(_viewport_changed)

func inject_backend_for_tests(backend: Object) -> void:
	# Explicit dependency injection only; _ready never selects desktop mocks.
	_backend = backend
	_injected = true

func _ensure_backend() -> bool:
	if not config.get("enabled", true): return false
	if _injected: return is_instance_valid(_backend)
	if OS.get_name() != "Android" or DisplayServer.get_name() == "headless": return false
	for singleton in ["PoingGodotAdMob", "PoingGodotAdMobConsentInformation", "PoingGodotAdMobUserMessagingPlatform", "PoingGodotAdMobRewardedAd", "PoingGodotAdMobInterstitialAd", "PoingGodotAdMobAdView", "PoingGodotAdMobAdSize"]:
		if not Engine.has_singleton(singleton): return false
	if _backend == null: _backend = NativeBackend.new()
	return true

func request_consent() -> void:
	if _consent_busy or _sdk_ready or not _active_kind.is_empty() or not _ensure_backend(): return
	_consent_busy = true
	_consent_token += 1
	_consent_phase = "update"
	_consent_time = CONSENT_TIMEOUT
	status = "Checking ad privacy choices"
	_backend.consent_update(_consent_updated.bind(_consent_token), _consent_failed.bind(_consent_token, "update"))

func _consent_updated(token: int) -> void:
	if not _consent_current(token, "update"): return
	if _backend.can_request_ads():
		_finish_consent(token)
	elif _backend.consent_required() and _backend.form_available():
		_consent_phase = "load"
		_backend.load_form(_consent_form_loaded.bind(token), _consent_failed.bind(token, "load"))
	else:
		_finish_consent(token)

func _consent_current(token: int, phase: String = "") -> bool:
	return _consent_busy and token == _consent_token and (phase.is_empty() or phase == _consent_phase)

func _consent_form_loaded(form: Object, token: int) -> void:
	if not _consent_current(token, "load"): return
	if not is_instance_valid(form):
		_finish_consent(token)
		return
	_consent_phase = "form"
	_consent_ui = true
	fullscreen_started.emit("consent")
	_backend.show_form(form, _consent_form_closed.bind(token))

func _consent_failed(_error: Variant, token: int, phase: String) -> void:
	if _consent_current(token, phase): _finish_consent(token)

func _consent_form_closed(_error: Variant, token: int) -> void:
	if _consent_current(token, "form"): _finish_consent(token)

func _finish_consent(token: int) -> void:
	if not _consent_current(token): return
	_consent_busy = false
	_consent_phase = ""
	if _consent_ui:
		_consent_ui = false
		fullscreen_finished.emit("consent")
	_can_request = _backend.can_request_ads()
	if not _can_request:
		status = "Ads unavailable without current privacy permission"
		_clear_ads()
	elif _sdk_ready:
		_start_requests()
	elif not _sdk_started:
		_sdk_started = true
		_sdk_time = LOAD_TIMEOUT
		_init_token += 1
		_backend.initialize(_initialized.bind(_init_token))
	availability_changed.emit()

func _initialized(_initialization_status: Variant, token: int) -> void:
	if token != _init_token or _sdk_ready or not _sdk_started: return
	_sdk_ready = true
	_sdk_time = 0.0
	status = "Test ads enabled" if config.get("use_test_ads", true) else "Ads enabled"
	if _can_request: _start_requests()
	availability_changed.emit()

func _unit(kind: String) -> String:
	if config.get("use_test_ads", true): return str(config.get("test_" + kind + "_unit_id", TEST_UNITS[kind]))
	var value := str(config.get(kind + "_unit_id", ""))
	return value if value.begins_with("ca-app-pub-") and "/" in value else ""

func _start_requests() -> void:
	if not _can_request or not _sdk_ready: return
	for kind in _slots: _request_load(kind)
	_update_banner()

func _request_load(kind: String) -> void:
	var slot: Dictionary = _slots[kind]
	if not _can_request or not _sdk_ready or slot.loading or slot.ad != null or int(slot.attempts) >= MAX_LOAD_ATTEMPTS or float(slot.retry) > 0.0: return
	var unit := _unit(kind)
	if unit.is_empty(): return
	slot.generation += 1
	slot.attempts += 1
	slot.loading = true
	slot.timeout = LOAD_TIMEOUT
	_backend.load_fullscreen(kind, unit, _loaded.bind(kind, int(slot.generation)), _load_failed.bind(kind, int(slot.generation)))

func _loaded(ad: Object, kind: String, generation: int) -> void:
	var slot: Dictionary = _slots[kind]
	if generation != int(slot.generation) or not slot.loading or not _can_request:
		if ad != slot.ad and ad != _active_ad: _destroy(ad)
		return
	if not is_instance_valid(ad):
		_load_failed(null, kind, generation)
		return
	slot.loading = false
	slot.timeout = 0.0
	slot.ad = ad
	slot.age = 0.0
	slot.retry = 0.0
	slot.attempts = 0
	availability_changed.emit()

func _load_failed(_error: Variant, kind: String, generation: int) -> void:
	var slot: Dictionary = _slots[kind]
	if generation != int(slot.generation) or not slot.loading: return
	slot.loading = false
	slot.timeout = 0.0
	slot.retry = minf(60.0, pow(2.0, float(slot.attempts))) if int(slot.attempts) < MAX_LOAD_ATTEMPTS else RETRY_BURST_COOLDOWN
	status = "Ad not available; keep sailing"
	availability_changed.emit()

func is_rewarded_ready() -> bool:
	return _can_request and _sdk_ready and not _consent_busy and _active_kind.is_empty() and _slots.rewarded.ad != null

func show_rewarded_continue(completion: Callable) -> bool:
	if not is_rewarded_ready(): return false
	return _show("rewarded", completion)

func record_completed_run() -> bool:
	if not _injected and (OS.get_name() != "Android" or DisplayServer.get_name() == "headless"): return false
	completed_runs = maxi(completed_runs, maxi(_read_count(save_path), _read_count(save_path + ".bak")))
	completed_runs += 1
	_due = completed_runs % 3 == 0
	if not _save_count(): _due = false
	return _due

func show_interstitial_if_due(completion: Callable) -> bool:
	var due := _due
	_due = false
	if not due or not _can_request or not _sdk_ready or _consent_busy or not _active_kind.is_empty() or _slots.interstitial.ad == null: return false
	return _show("interstitial", completion)

func _show(kind: String, completion: Callable) -> bool:
	var slot: Dictionary = _slots[kind]
	_active_ad = slot.ad
	slot.ad = null
	_active_kind = kind
	_active_token += 1
	_active_completion = completion
	_active_earned = false
	_active_time = SHOW_TIMEOUT
	_active_presented = false
	var token := _active_token
	_update_banner()
	availability_changed.emit()
	fullscreen_started.emit(kind)
	_backend.show_fullscreen(kind, _active_ad, _earned.bind(token), _closed.bind(token), _show_failed.bind(token), _shown.bind(token))
	return true

func _shown(token: int) -> void:
	if token == _active_token and not _active_kind.is_empty(): _active_presented = true

func _earned(_reward: Variant, token: int) -> void:
	if token == _active_token and _active_kind == "rewarded": _active_earned = true

func _closed(token: int) -> void:
	if token == _active_token and not _active_kind.is_empty(): _finish_show(true)

func _show_failed(_error: Variant, token: int) -> void:
	if token == _active_token and not _active_kind.is_empty(): _finish_show(false)

func _finish_show(dismissed: bool) -> void:
	var kind := _active_kind
	var completion := _active_completion
	var granted := dismissed and _active_earned and kind == "rewarded"
	var ad := _active_ad
	_active_kind = ""
	_active_ad = null
	_active_completion = Callable()
	_active_earned = false
	_active_time = 0.0
	_active_presented = false
	_destroy(ad)
	fullscreen_finished.emit(kind)
	if completion.is_valid():
		if kind == "rewarded": completion.call(granted)
		else: completion.call()
	_request_load(kind)
	_update_banner()
	availability_changed.emit()

func set_home_banner_visible(visible: bool) -> void:
	_home = visible
	_update_banner()

func banner_reserved_height() -> float:
	return _banner_height

func _set_banner_height(value: float) -> void:
	if is_equal_approx(value, _banner_height): return
	_banner_height = value
	banner_space_changed.emit(value)

func _update_banner() -> void:
	var visible := _home and _can_request and _sdk_ready and _active_kind.is_empty() and not _consent_busy
	if not visible:
		if is_instance_valid(_banner): _banner.hide()
		_set_banner_height(0.0)
		return
	if is_instance_valid(_banner):
		if _banner_loaded:
			_banner.show()
			_refresh_banner_height()
		return
	if _banner_attempts >= MAX_LOAD_ATTEMPTS or _banner_retry > 0.0 or _unit("banner").is_empty(): return
	_banner_token += 1
	_banner_attempts += 1
	_banner_time = LOAD_TIMEOUT
	_banner_width = DisplayServer.window_get_size().x
	_banner = _backend.create_banner(_unit("banner"), _banner_did_load.bind(_banner_token), _banner_failed.bind(_banner_token))
	if _banner == null:
		_banner_failed(null, _banner_token)
	else:
		_backend.load_banner(_banner)

func _banner_did_load(token: int) -> void:
	if token != _banner_token or _banner_time <= 0.0 or not is_instance_valid(_banner): return
	_banner_loaded = true
	_banner_time = 0.0
	_banner_attempts = 0
	_update_banner()

func _banner_failed(_error: Variant, token: int) -> void:
	if token != _banner_token or _banner_time <= 0.0: return
	_banner_time = 0.0
	_banner_loaded = false
	_destroy(_banner)
	_banner = null
	_banner_retry = minf(60.0, pow(2.0, float(_banner_attempts))) if _banner_attempts < MAX_LOAD_ATTEMPTS else RETRY_BURST_COOLDOWN
	_set_banner_height(0.0)

func _refresh_banner_height() -> void:
	var physical_height := float(_banner.get_height_in_pixels())
	var physical_view := float(DisplayServer.window_get_size().y)
	var logical_view := get_viewport().get_visible_rect().size.y if get_viewport() else 960.0
	_set_banner_height(_logical_banner_height(physical_height, physical_view, logical_view))

func _logical_banner_height(physical_height: float, physical_view: float, logical_view: float) -> float:
	return clampf(physical_height / maxf(physical_view, 1.0) * logical_view, 0.0, logical_view * 0.25)

func _viewport_changed() -> void:
	if is_instance_valid(_banner) and _banner_width != DisplayServer.window_get_size().x:
		_banner_token += 1
		_destroy(_banner)
		_banner = null
		_banner_loaded = false
		_banner_time = 0.0
		_banner_attempts = 0
		_set_banner_height(0.0)
	_update_banner()

func privacy_options_required() -> bool:
	return is_instance_valid(_backend) and _backend.privacy_required()

func show_privacy_options() -> bool:
	if not privacy_options_required() or _consent_busy or not _active_kind.is_empty(): return false
	_consent_busy = true
	_consent_token += 1
	_consent_phase = "form"
	_consent_time = CONSENT_TIMEOUT
	_consent_ui = true
	_update_banner()
	fullscreen_started.emit("consent")
	_backend.show_privacy(_consent_form_closed.bind(_consent_token))
	return true

func _process(delta: float) -> void:
	_tick(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: _suspended = true
	elif what == NOTIFICATION_APPLICATION_RESUMED: _suspended = false

func _tick(delta: float) -> void:
	if _suspended: return
	var expired_show := -1
	# A player may take any amount of time reading a native privacy form.
	# Time out its network preparation, never a form already presented.
	if _consent_busy and not _consent_ui:
		_consent_time -= delta
		if _consent_time <= 0.0: _finish_consent(_consent_token)
	if _sdk_started and not _sdk_ready and _sdk_time > 0.0:
		_sdk_time -= delta
		if _sdk_time <= 0.0:
			_init_token += 1
			status = "Ad initialization unavailable; keep sailing"
	# Once the SDK confirms an ad is on screen, only its terminal callback may
	# resume the game. A wall-clock timer cannot safely infer native dismissal.
	if not _active_kind.is_empty() and not _active_presented:
		_active_time -= delta
		if _active_time <= 0.0: expired_show = _active_token
	if not _can_request or not _sdk_ready:
		if expired_show == _active_token: _finish_show(false)
		return
	for kind in _slots:
		var slot: Dictionary = _slots[kind]
		if slot.loading:
			slot.timeout -= delta
			if float(slot.timeout) <= 0.0: _load_failed(null, kind, int(slot.generation))
		elif slot.ad != null:
			slot.age += delta
			if float(slot.age) >= MAX_AD_AGE:
				_destroy(slot.ad)
				slot.ad = null
				_request_load(kind)
		elif float(slot.retry) > 0.0:
			slot.retry -= delta
			if float(slot.retry) <= 0.0:
				if int(slot.attempts) >= MAX_LOAD_ATTEMPTS: slot.attempts = 0
				_request_load(kind)
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			_banner_time = 0.001
			_banner_failed(null, _banner_token)
	elif _banner_retry > 0.0:
		_banner_retry -= delta
		if _banner_retry <= 0.0:
			if _banner_attempts >= MAX_LOAD_ATTEMPTS: _banner_attempts = 0
			_update_banner()
	# Reloads begun by a terminal callback must not inherit the elapsed time
	# from before that request existed (for example after a stalled frame).
	if expired_show == _active_token: _finish_show(false)

func _clear_ads() -> void:
	for kind in _slots:
		var slot: Dictionary = _slots[kind]
		slot.generation += 1
		slot.loading = false
		_destroy(slot.ad)
		slot.ad = null
		slot.attempts = 0
		slot.retry = 0.0
	_banner_token += 1
	_destroy(_banner)
	_banner = null
	_banner_loaded = false
	_banner_time = 0.0
	_banner_retry = 0.0
	_banner_attempts = 0
	_set_banner_height(0.0)
	availability_changed.emit()

func _destroy(ad: Object) -> void:
	if is_instance_valid(ad) and ad.has_method("destroy"): ad.destroy()

func _read_count(path: String) -> int:
	if not FileAccess.file_exists(path): return -1
	var decoder := JSON.new()
	if decoder.parse(FileAccess.get_file_as_string(path)) != OK: return -1
	var envelope: Variant = decoder.data
	if not envelope is Dictionary or not envelope.get("payload") is String: return -1
	var payload: String = envelope.payload
	if payload.sha256_text() != envelope.get("sha256", ""): return -1
	if decoder.parse(payload) != OK: return -1
	var parsed: Variant = decoder.data
	if not parsed is Dictionary or parsed.get("version") != 1: return -1
	var value: Variant = parsed.get("completed_runs", -1)
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 9007199254740991.0: return -1
	return int(value)

func _load_count() -> void:
	completed_runs = maxi(0, maxi(_read_count(save_path), _read_count(save_path + ".bak")))
	# A pending interstitial never survives a restart or appears at launch.
	_due = false

func _save_count() -> bool:
	completed_runs = maxi(completed_runs, maxi(_read_count(save_path), _read_count(save_path + ".bak")))
	var payload := JSON.stringify({"version":1,"completed_runs":completed_runs})
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
	file.flush()
	file.close()
	if _read_count(save_path + ".tmp") != completed_runs: return false
	if _read_count(save_path) >= 0: DirAccess.copy_absolute(save_path, save_path + ".bak")
	return DirAccess.rename_absolute(save_path + ".tmp", save_path) == OK

func _exit_tree() -> void:
	_consent_token += 1
	_active_token += 1
	_clear_ads()
	_destroy(_active_ad)
	_active_ad = null
