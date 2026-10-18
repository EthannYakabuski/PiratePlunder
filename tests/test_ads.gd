extends SceneTree
## Real plugin wrappers remain uninitialized. Every network/UI operation is fake.
const AdsScript = preload("res://scripts/ads.gd")
var checks := 0
var failures := 0
var managers: Array = []

class FakeAd extends RefCounted:
	var destroyed := 0
	func destroy() -> void: destroyed += 1

class FakeBanner extends FakeAd:
	var visible := false
	func show() -> void: visible = true
	func hide() -> void: visible = false
	func get_height_in_pixels() -> int: return 100

class CompletionReceiver extends Node:
	func completed(_granted: bool) -> void: pass

class FakeBackend extends RefCounted:
	var allowed := false
	var required := false
	var form_exists := false
	var privacy := false
	var updates := 0
	var initializations := 0
	var consent_ok: Callable
	var consent_error: Callable
	var form_ok: Callable
	var form_error: Callable
	var form_closed: Callable
	var privacy_closed: Callable
	var initialized: Callable
	var requests := {"rewarded":[],"interstitial":[]}
	var shows: Array = []
	var banners: Array = []
	var banner_ok: Callable
	var banner_error: Callable
	var banner_loads := 0
	func consent_update(success: Callable, failure: Callable) -> void:
		updates += 1
		consent_ok = success
		consent_error = failure
	func can_request_ads() -> bool: return allowed
	func consent_required() -> bool: return required
	func form_available() -> bool: return form_exists
	func load_form(success: Callable, failure: Callable) -> void:
		form_ok = success
		form_error = failure
	func show_form(_form: Object, dismissed: Callable) -> void: form_closed = dismissed
	func privacy_required() -> bool: return privacy
	func show_privacy(dismissed: Callable) -> void: privacy_closed = dismissed
	func initialize(completed: Callable) -> void:
		initializations += 1
		initialized = completed
	func load_fullscreen(kind: String, unit: String, success: Callable, failure: Callable) -> void:
		requests[kind].append({"unit":unit,"loaded":success,"failed":failure})
	func show_fullscreen(kind: String, ad: Object, earned: Callable, dismissed: Callable, failed: Callable, shown: Callable) -> void:
		shows.append({"kind":kind,"ad":ad,"earned":earned,"closed":dismissed,"failed":failed,"shown":shown})
	func create_banner(unit: String, success: Callable, failure: Callable) -> Object:
		var banner := FakeBanner.new()
		banners.append({"unit":unit,"ad":banner})
		banner_ok = success
		banner_error = failure
		return banner
	func load_banner(_banner: Object) -> void: banner_loads += 1

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func make(name: String, backend: FakeBackend = null):
	var ads = AdsScript.new()
	ads.save_path = "res://tests/.test-ads-%s.json" % name
	ads.config = {"enabled":true,"use_test_ads":true}
	if backend != null: ads.inject_backend_for_tests(backend)
	managers.append(ads)
	return ads

func start(ads: Node, backend: FakeBackend) -> void:
	backend.allowed = true
	ads.request_consent()
	backend.consent_ok.call()
	backend.initialized.call(null)

func load_ad(backend: FakeBackend, kind: String) -> FakeAd:
	var ad := FakeAd.new()
	backend.requests[kind][-1].loaded.call(ad)
	return ad

func _run() -> void:
	_test_native_guards()
	_test_consent()
	_test_rewarded()
	_test_interstitials()
	_test_loading()
	_test_banner()
	_test_persistence()
	for ads in managers:
		ads._clear_ads()
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(ads.save_path + suffix): DirAccess.remove_absolute(ads.save_path + suffix)
		ads.free()
	print("ADS_SUITE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _test_native_guards() -> void:
	var ads = make("native-guard")
	ads.request_consent()
	ads.set_home_banner_visible(true)
	check(ads._backend == null and not ads.is_rewarded_ready() and ads.banner_reserved_height() == 0.0, "desktop/headless never creates a native or editor-mock backend")
	check(not ads.record_completed_run() and ads.completed_runs == 0 and not FileAccess.file_exists(ads.save_path), "unsupported desktop/headless finalizations never create or modify ad cadence")
	var callbacks: Array = []
	check(not ads.show_rewarded_continue(func(granted: bool): callbacks.append(granted)) and callbacks.is_empty(), "unavailable rewarded returns false without calling completion")
	check(not ads.show_privacy_options(), "unavailable privacy options safely return false")
	var backend := FakeBackend.new()
	var disabled = make("disabled", backend)
	disabled.config.enabled = false
	disabled.request_consent()
	check(backend.updates == 0, "disabled advertising never requests consent or initializes")
	check(ads._unit("rewarded") == "ca-app-pub-3940256099942544/5224354917", "default rewarded unit is Google's test unit")
	ads.config.use_test_ads = false
	ads.config.rewarded_unit_id = ""
	check(ads._unit("rewarded").is_empty(), "production mode with no ad unit cannot accidentally send a test/production request")

func _test_consent() -> void:
	var backend := FakeBackend.new()
	var ads = make("consent", backend)
	ads.request_consent()
	ads.request_consent()
	check(backend.updates == 1 and backend.initializations == 0 and backend.requests.rewarded.is_empty(), "consent update is single-flight and blocks SDK/ad requests")
	backend.consent_error.call(null)
	check(not ads._can_request and backend.initializations == 0, "consent error with unknown permission fails closed")
	backend.required = true
	backend.form_exists = true
	ads.request_consent()
	backend.consent_ok.call()
	check(backend.form_ok.is_valid() and backend.initializations == 0, "required consent loads a form before any SDK request")
	var events: Array = []
	ads.fullscreen_started.connect(func(kind: String): events.append("start:" + kind))
	ads.fullscreen_finished.connect(func(kind: String): events.append("finish:" + kind))
	backend.form_ok.call(FakeAd.new())
	check(events == ["start:consent"], "consent form announces a fullscreen pause")
	backend.consent_error.call(null)
	backend.form_error.call(null)
	check(ads._consent_busy and backend.initializations == 0, "stale earlier-phase failures cannot dismiss a visible consent form")
	ads._tick(600.0)
	check(ads._consent_busy and events == ["start:consent"] and backend.initializations == 0, "reading a visible native consent form never times out or resumes gameplay")
	backend.allowed = true
	backend.form_closed.call(null)
	backend.form_closed.call(null)
	check(events == ["start:consent","finish:consent"] and backend.initializations == 1, "consent dismissal initializes once and duplicate callbacks are ignored")
	backend.initialized.call(null)
	backend.initialized.call(null)
	ads.request_consent()
	check(backend.requests.rewarded.size() == 1 and backend.requests.interstitial.size() == 1 and backend.initializations == 1, "SDK callback duplicates do not duplicate preloads or initialization")
	backend.privacy = true
	check(ads.privacy_options_required() and ads.show_privacy_options(), "required privacy options can be opened explicitly")
	backend.allowed = false
	backend.privacy_closed.call(null)
	check(not ads.is_rewarded_ready() and not ads._can_request, "privacy permission revocation clears ad availability")
	var late := FakeAd.new()
	backend.requests.rewarded[0].loaded.call(late)
	check(late.destroyed == 1 and ads._slots.rewarded.ad == null, "a late load after consent revocation is destroyed")
	var unavailable := FakeBackend.new()
	unavailable.required = true
	var blocked = make("unavailable-form", unavailable)
	blocked.request_consent()
	unavailable.consent_ok.call()
	check(unavailable.initializations == 0 and not blocked._consent_busy, "required but unavailable form leaves play usable without ads")
	blocked.request_consent()
	var stale: Callable = unavailable.consent_ok
	blocked._tick(46.0)
	unavailable.allowed = true
	stale.call()
	check(unavailable.initializations == 0 and not blocked._consent_busy, "timed-out consent and stale callbacks cannot initialize ads")
	var cached := FakeBackend.new()
	var cached_ads = make("sdk-cached-consent", cached)
	cached.allowed = true
	cached_ads.request_consent()
	cached.consent_error.call(null)
	check(cached.initializations == 1, "SDK-verified permission remains usable after a consent-update network error")

func _test_rewarded() -> void:
	var backend := FakeBackend.new()
	var ads = make("rewarded", backend)
	start(ads, backend)
	var first := load_ad(backend, "rewarded")
	backend.requests.rewarded[-1].loaded.call(first)
	check(first.destroyed == 0 and ads.is_rewarded_ready(), "duplicate loaded callback cannot destroy the ready single-use ad")
	var results: Array = []
	var events: Array = []
	ads.fullscreen_started.connect(func(kind: String): events.append("start:" + kind))
	ads.fullscreen_finished.connect(func(kind: String): events.append("finish:" + kind))
	check(ads.is_rewarded_ready() and ads.show_rewarded_continue(func(granted: bool): results.append(granted); events.append("completion")), "ready rewarded ad accepts a single presentation")
	check(not ads.is_rewarded_ready() and not ads.show_rewarded_continue(func(_granted: bool): results.append("duplicate")), "single-use rewarded ad cannot be shown twice")
	var show: Dictionary = backend.shows[-1]
	show.earned.call(null)
	show.earned.call(null)
	check(results.is_empty(), "earned reward alone never completes or revives early")
	show.closed.call()
	show.closed.call()
	show.failed.call(null)
	show.earned.call(null)
	check(results == [true] and first.destroyed == 1, "earned and dismissed rewards complete exactly once despite duplicate terminal events")
	check(events == ["start:rewarded","finish:rewarded","completion"], "fullscreen finish precedes reward completion so gameplay can resume safely")
	check(backend.requests.rewarded.size() == 2, "consumed rewarded ad immediately preloads a fresh single-use ad")
	load_ad(backend, "rewarded")
	ads.show_rewarded_continue(func(granted: bool): results.append(granted))
	var second_show: Dictionary = backend.shows[-1]
	show.earned.call(null)
	show.closed.call()
	check(results == [true], "callbacks from a previous ad cannot affect the current presentation")
	second_show.closed.call()
	second_show.earned.call(null)
	check(results == [true,false], "early close and later reward callback do not grant a revive")
	load_ad(backend, "rewarded")
	ads.show_rewarded_continue(func(granted: bool): results.append(granted))
	backend.shows[-1].earned.call(null)
	backend.shows[-1].failed.call(null)
	check(results == [true,false,false], "failed presentation never grants a reward even after an earned callback")
	load_ad(backend, "rewarded")
	ads.show_rewarded_continue(func(granted: bool): results.append(granted))
	var timed_out: Dictionary = backend.shows[-1]
	ads._tick(181.0)
	timed_out.closed.call()
	check(results == [true,false,false,false], "missing terminal callback times out once without granting or hanging gameplay")
	load_ad(backend, "rewarded")
	ads.show_rewarded_continue(func(granted: bool): results.append(granted))
	var visible: Dictionary = backend.shows[-1]
	visible.shown.call()
	ads._tick(600.0)
	check(results == [true,false,false,false] and ads._active_kind == "rewarded", "SDK-confirmed visible ad never resumes gameplay from a watchdog timer")
	visible.earned.call(null)
	visible.closed.call()
	check(results == [true,false,false,false,true], "long visible ad completes only when SDK dismisses it")
	load_ad(backend, "rewarded")
	ads.show_rewarded_continue(func(granted: bool): results.append(granted))
	ads._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	ads._tick(600.0)
	check(results.size() == 5 and ads._active_kind == "rewarded", "background time cannot exhaust the presentation watchdog")
	ads._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	backend.shows[-1].failed.call(null)
	load_ad(backend, "rewarded")
	var receiver := CompletionReceiver.new()
	ads.show_rewarded_continue(receiver.completed)
	receiver.free()
	backend.shows[-1].earned.call(null)
	backend.shows[-1].closed.call()
	check(ads._active_kind.is_empty(), "a freed completion target is ignored safely while presentation cleanup still finishes")

func _test_interstitials() -> void:
	var backend := FakeBackend.new()
	var ads = make("interstitial", backend)
	start(ads, backend)
	load_ad(backend, "interstitial")
	var completions: Array = []
	check(not ads.record_completed_run() and not ads.record_completed_run() and ads.record_completed_run(), "only every third finalized voyage creates an interstitial opportunity")
	check(ads.show_interstitial_if_due(func(): completions.append(true)), "third finalized voyage shows an already-preloaded interstitial")
	check(not ads.show_interstitial_if_due(func(): completions.append(false)), "an interstitial boundary is consumed once")
	var show: Dictionary = backend.shows[-1]
	show.closed.call()
	show.failed.call(null)
	check(completions == [true] and backend.requests.interstitial.size() == 2, "interstitial dismissal/failure completion is once-only and reloads")
	ads.record_completed_run()
	ads.record_completed_run()
	ads.record_completed_run()
	check(not ads.show_interstitial_if_due(func(): completions.append(false)), "no fill at a due boundary simply continues play")
	load_ad(backend, "interstitial")
	check(backend.shows.size() == 1 and not ads.show_interstitial_if_due(func(): completions.append(false)), "a later ad load never shows a missed interstitial")
	check(not ads.record_completed_run() and ads.completed_runs == 7, "cadence progresses independently from no-fill or rewarded ads")

func _test_loading() -> void:
	var backend := FakeBackend.new()
	var ads = make("loading", backend)
	start(ads, backend)
	var old: Dictionary = backend.requests.rewarded[0]
	old.failed.call(null)
	old.failed.call(null)
	ads._tick(1.0)
	check(backend.requests.rewarded.size() == 1, "duplicate load failure does not bypass retry backoff")
	ads._tick(1.1)
	check(backend.requests.rewarded.size() == 2, "failed load retries after bounded backoff")
	var late := FakeAd.new()
	old.loaded.call(late)
	check(late.destroyed == 1 and not ads.is_rewarded_ready(), "stale prior load cannot overwrite a newer request")
	for index in range(3):
		backend.requests.rewarded[-1].failed.call(null)
		ads._tick(65.0)
	check(backend.requests.rewarded.size() == 4 and not ads.is_rewarded_ready(), "persistent no-fill pauses after four bounded load attempts")
	ads._tick(174.0)
	check(backend.requests.rewarded.size() == 4, "exhausted reward burst does not hammer during the four-minute cooldown")
	ads._tick(1.1)
	check(backend.requests.rewarded.size() == 5 and ads._slots.rewarded.attempts == 1, "reward loading starts a fresh bounded burst after cooldown expiry")
	load_ad(backend, "rewarded")
	check(ads.is_rewarded_ready() and backend.shows.is_empty(), "reward no-fill recovers readiness without automatically presenting any ad")
	_test_interstitial_retry_recovery()
	var hanging := FakeBackend.new()
	var hanging_ads = make("load-timeout", hanging)
	start(hanging_ads, hanging)
	hanging_ads._tick(31.0)
	check(not hanging_ads._slots.rewarded.loading and not hanging_ads._slots.interstitial.loading, "load callbacks that never arrive time out safely")
	var init_backend := FakeBackend.new()
	var init_ads = make("init-timeout", init_backend)
	init_backend.allowed = true
	init_ads.request_consent()
	init_backend.consent_ok.call()
	init_ads._tick(31.0)
	init_backend.initialized.call(null)
	check(not init_ads._sdk_ready and init_backend.requests.rewarded.is_empty() and init_backend.initializations == 1, "late SDK initialization after timeout is ignored without duplicate initialization")

func _test_interstitial_retry_recovery() -> void:
	var backend := FakeBackend.new()
	var ads = make("interstitial-retry", backend)
	start(ads, backend)
	for index in range(4):
		backend.requests.interstitial[-1].failed.call(null)
		if index < 3: ads._tick(pow(2.0, float(index + 1)) + 0.01)
	ads.record_completed_run()
	ads.record_completed_run()
	ads.record_completed_run()
	check(not ads.show_interstitial_if_due(func(): pass), "exhausted interstitial no-fill consumes its missed boundary normally")
	ads._tick(239.0)
	check(backend.requests.interstitial.size() == 4 and backend.shows.is_empty(), "four failed interstitial loads respect the long cooldown")
	ads._can_request = false
	ads._tick(1000.0)
	check(backend.requests.interstitial.size() == 4, "cooldown recovery never requests ads without consent permission")
	ads._can_request = true
	ads._tick(1.1)
	check(backend.requests.interstitial.size() == 5 and ads._slots.interstitial.attempts == 1, "interstitial loading recovers with a fresh burst after consent and cooldown")
	load_ad(backend, "interstitial")
	check(ads._slots.interstitial.ad != null and backend.shows.is_empty() and not ads.show_interstitial_if_due(func(): pass), "recovered interstitial stays preloaded and never replays the missed boundary")

func _test_banner() -> void:
	var backend := FakeBackend.new()
	var ads = make("banner", backend)
	var spaces: Array = []
	ads.banner_space_changed.connect(func(height: float): spaces.append(height))
	start(ads, backend)
	check(backend.banners.is_empty(), "preloading fullscreen ads never creates a banner outside home")
	ads.set_home_banner_visible(true)
	ads.set_home_banner_visible(true)
	check(backend.banners.size() == 1 and not backend.banners[0].ad.visible and ads.banner_reserved_height() == 0.0, "home creates one hidden adaptive banner until loaded")
	backend.banner_ok.call()
	check(backend.banners[0].ad.visible and ads.banner_reserved_height() > 0.0 and not spaces.is_empty(), "loaded home banner reports reserved logical layout space")
	check(ads._logical_banner_height(100.0, 1920.0, 960.0) == 50.0 and ads._logical_banner_height(-1.0, 1920.0, 960.0) == 0.0, "physical banner pixels convert to safe logical viewport height")
	ads.set_home_banner_visible(false)
	check(not backend.banners[0].ad.visible and ads.banner_reserved_height() == 0.0 and spaces[-1] == 0.0, "leaving home hides the banner and releases every reserved pixel")
	ads.set_home_banner_visible(true)
	check(backend.banners.size() == 1 and backend.banners[0].ad.visible, "returning home reuses its loaded banner without duplicate creation")
	load_ad(backend, "rewarded")
	ads.show_rewarded_continue(func(_granted: bool): pass)
	check(not backend.banners[0].ad.visible and ads.banner_reserved_height() == 0.0, "fullscreen presentations hide home banners")
	backend.shows[-1].closed.call()
	check(backend.banners[0].ad.visible, "fullscreen dismissal restores banner only if home is still active")
	var old_banner: FakeBanner = backend.banners[0].ad
	var old_callback: Callable = backend.banner_ok
	ads._banner_width = -999
	ads._viewport_changed()
	check(old_banner.destroyed == 1 and backend.banners.size() == 2 and ads.banner_reserved_height() == 0.0, "viewport width change rebuilds adaptive banner and releases stale layout space")
	old_callback.call()
	check(not backend.banners[-1].ad.visible, "old banner load callbacks cannot show a replacement before it is loaded")
	backend.banner_ok.call()
	check(backend.banners[-1].ad.visible and ads.banner_reserved_height() > 0.0, "resized adaptive banner reserves space after its own load completes")
	var failed := FakeBackend.new()
	var nofill = make("banner-no-fill", failed)
	start(nofill, failed)
	nofill.set_home_banner_visible(true)
	failed.banner_error.call(null)
	failed.banner_error.call(null)
	check(nofill.banner_reserved_height() == 0.0 and failed.banners[0].ad.destroyed == 1, "banner no-fill keeps home usable without blank reserved space")
	for index in range(3):
		nofill._tick(pow(2.0, float(index + 1)) + 0.01)
		failed.banner_error.call(null)
	nofill._tick(239.0)
	check(failed.banners.size() == 4 and nofill.banner_reserved_height() == 0.0, "four failed banners remain absent throughout their long cooldown")
	nofill.set_home_banner_visible(false)
	nofill._tick(1.1)
	check(failed.banners.size() == 4 and nofill._banner_attempts == 0, "banner cooldown expires without requesting a banner outside home")
	nofill.set_home_banner_visible(true)
	check(failed.banners.size() == 5, "returning home after cooldown starts a fresh banner retry burst")
	failed.banner_ok.call()
	check(failed.banners[-1].ad.visible and nofill.banner_reserved_height() > 0.0 and failed.shows.is_empty(), "banner no-fill recovers after cooldown without creating a fullscreen popup")

func _test_persistence() -> void:
	var first = make("cadence-save", FakeBackend.new())
	first.record_completed_run()
	first.record_completed_run()
	var reloaded = make("cadence-reader", FakeBackend.new())
	reloaded.save_path = first.save_path
	reloaded._load_count()
	check(reloaded.completed_runs == 2 and reloaded.record_completed_run(), "finalized-game count persists and the third game is due after restart")
	var restarted = make("cadence-restart", FakeBackend.new())
	restarted.save_path = first.save_path
	restarted._load_count()
	check(restarted.completed_runs == 3 and not restarted._due, "restart restores the count without scheduling any launch-time ad")
	check(not first.record_completed_run() and first.completed_runs == 4, "stale in-memory counters advance the persisted maximum instead of moving backwards")
	var file := FileAccess.open(first.save_path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	restarted._load_count()
	check(restarted.completed_runs == 3, "corrupted cadence primary recovers its verified backup")
	var failed = make("cadence-unwritable", FakeBackend.new())
	failed.save_path = "res://tests/.missing-ad-directory/cadence.json"
	failed.record_completed_run()
	failed.record_completed_run()
	check(not failed.record_completed_run() and not failed._due, "failed count persistence cannot create an interstitial opportunity")
