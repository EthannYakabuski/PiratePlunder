extends Node2D
## Chart -> choose a voyage -> choose a ship. Upgrade individual ships in the yard.
const ArenaScript := preload("res://scripts/arena.gd")
const CREAM := Color("fff0cc")
const GOLD := Color("ffd27b")
const INK := Color("0c3445")
var ui: Control
var backdrop: Node2D
var arena: Node2D
var screen := "chart"
var selected_ship := 0
var selected_level := 1
var selected_mode := "campaign"
var chart_biome := 0
var campaign: Dictionary = {}
var title_font: Font
var body_font: Font
var clock := 0.0
var hud_health: ProgressBar
var hud_title: Label
var hud_score: Label
var hud_goal: Label
var hud_buff: Label
var toast_label: Label
var toast_time := 0.0
var music: AudioStreamPlayer
var reward: Dictionary = {}
var last_summary: Dictionary = {}
var shipyard_return := "chart"
var capture_mode := ""
var capture_dir := "res://store/screenshots/phone"
var capture_time := 0.0
var capture_frames := 0
var ads_service: Node
var _run_serial := 0
var _run_id := ""
var _run_finalized := false
var _revive_busy := false
var _return_to_chart_after_finish := false
var _skip_interstitial := false
var _ads_fullscreen_active := false
var _ad_pause_was_paused := true
var _ad_music_was_paused := false
var _application_backgrounded := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_mode = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if ads_service == null: ads_service = get_node_or_null("/root/Ads")
	if ads_service != null:
		ads_service.banner_space_changed.connect(_banner_layout_changed)
		ads_service.fullscreen_started.connect(_ad_started)
		ads_service.fullscreen_finished.connect(_ad_finished)
		ads_service.availability_changed.connect(_ads_availability_changed)
	if ResourceLoader.exists("res://assets_generated/fonts/LilitaOne-Regular.ttf"): title_font = load("res://assets_generated/fonts/LilitaOne-Regular.ttf")
	else: title_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets_generated/fonts/Nunito-SemiBold.ttf"): body_font = load("res://assets_generated/fonts/Nunito-SemiBold.ttf")
	else: body_font = ThemeDB.fallback_font
	if FileAccess.file_exists("res://data/campaign.json"): campaign = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.add_theme_font_override("font", body_font)
	get_viewport().size_changed.connect(_resize)
	Progression.achievement_unlocked.connect(_achievement_toast)
	music = AudioStreamPlayer.new()
	add_child(music)
	if ResourceLoader.exists("res://assets_generated/audio/pirate_loop.wav"):
		var stream: AudioStreamWAV = load("res://assets_generated/audio/pirate_loop.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
		music.stream = stream
		music.volume_db = -21
		if Progression.settings.get("music",true): music.play()
	selected_level = Progression.next_level()
	chart_biome = mini(4,(selected_level-1)/10)
	show_chart()
	if not capture_mode.is_empty(): call_deferred("_setup_capture")
	elif ads_service != null: ads_service.call_deferred("request_consent")

func size() -> Vector2: return get_viewport_rect().size

func _resize() -> void:
	match screen:
		"ships": show_ships()
		"chart": show_chart()
		"run": _run_ui()
		"result": _result_ui()
		"logbook": show_logbook()
		"settings": show_settings()
		"shipyard": show_shipyard()
		"revive": _revive_ui()
		"revive_ad": _revive_wait_ui()
	queue_redraw()

func clear_ui() -> void:
	if ads_service != null and (screen != "chart" or not capture_mode.is_empty()): ads_service.set_home_banner_visible(false)
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	toast_label = null

func _panel(rect: Rect2, color := Color("123d4c"), border := Color("457c80"), parent: Control = null) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.01,0.08,0.12,0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0,5)
	panel.add_theme_stylebox_override("panel",style)
	(parent if parent != null else ui).add_child(panel)
	return panel

func _label(text: String, rect: Rect2, font_size := 22, color := CREAM, centered := false, title := false, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.add_theme_font_override("font",title_font if title else body_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Set the width after enabling wrapping; an unwrapped minimum width otherwise
	# expands long upgrade descriptions beyond their card before layout settles.
	label.size = rect.size
	(parent if parent != null else ui).add_child(label)
	# Text shaping may invalidate the original unwrapped minimum on tree entry.
	label.set_deferred("size",rect.size)
	return label

func _button(text: String, rect: Rect2, action: Callable, color := Color("e2b76d"), parent: Control = null) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font",body_font)
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_hover_color",INK)
	button.add_theme_color_override("font_pressed_color",INK)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.darkened(0.16) if state == "pressed" else (color.lightened(0.1) if state == "hover" else color)
		if state == "disabled": style.bg_color = Color("52707b")
		style.set_corner_radius_all(16)
		style.border_color = Color("fff0ba") if state == "focus" else color.lightened(0.18)
		style.set_border_width_all(2 if state == "focus" else 1)
		button.add_theme_stylebox_override(state,style)
	button.pressed.connect(action)
	(parent if parent != null else ui).add_child(button)
	return button

func show_ships() -> void:
	_hide_arena()
	screen = "ships"
	clear_ui()
	var w := size().x
	var h := size().y
	var top := 54.0
	_label("CHOOSE YOUR SHIP",Rect2(20,top,w-40,54),38,GOLD,true,true)
	_label(_voyage_title(),Rect2(22,top+58,w-44,35),20,CREAM,true)
	var card_top := 171.0
	var card_h := minf(145,(h-card_top-155)/4.0-10)
	for i in Progression.ships.size():
		var s: Dictionary = Progression.ships[i]
		var loadout: Dictionary = Progression.ship_loadout(s.id)
		var y := card_top + i*(card_h+12)
		var card := _button("",Rect2(26,y,w-52,card_h),func(): _choose_ship(i),Color("123d4c"))
		var texture := TextureRect.new()
		texture.texture = load(str(s.asset).replace("Default size","Retina"))
		texture.position = Vector2(21,14)
		texture.size = Vector2(63,card_h-28)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.rotation = PI
		texture.pivot_offset = texture.size/2
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(texture)
		_label(s.name,Rect2(104,10,w-180,35),31,Color(s.color),false,true,card)
		_label(s.subtitle,Rect2(104,43,w-184,25),16,CREAM,false,false,card)
		var rank: Dictionary = Progression.ship_rank_progress(s.id)
		_label("HULL %d   SPEED %d   RELOAD %.1fs" % [loadout.hp,s.speed,loadout.cooldown],Rect2(104,70,w-184,23),16,Color("b3d9d6"),false,false,card)
		_label("RANK %d  ·  PORT %d / STARBOARD %d" % [rank.rank,loadout.cannons_port,loadout.cannons_starboard],Rect2(104,97,w-184,24),15,GOLD,false,false,card)
	_label("Tap a ship and set sail",Rect2(20,h-135,w-40,30),17,CREAM,true)
	_button("Upgrade ships",Rect2(26,h-94,w-52,40),func(): shipyard_return="ships"; show_shipyard(),Color("e0be7e"))
	_button("‹ Chart",Rect2(26,h-45,w-52,34),show_chart,Color("9fcac4"))
	queue_redraw()

func _choose_ship(index: int) -> void:
	selected_ship = index
	start_run()

func _voyage_title() -> String:
	if selected_mode == "endless": return "Endless Seas · How long can you last?"
	if selected_mode == "daily": return "Daily Drift · One seed. Fresh challenge."
	if campaign.get("levels",[]).size() >= selected_level: return "%02d · %s" % [selected_level,campaign.levels[selected_level-1].name]
	return "Your voyage awaits"

func _chart_path_metrics(banner_height: float) -> Vector2:
	var compact := banner_height > 50
	var bottom := size().y-banner_height
	return Vector2(201 if compact else 217,minf(48,maxf(12,(bottom-(400 if compact else 496))/9)))

func show_chart() -> void:
	_hide_arena()
	screen = "chart"
	clear_ui()
	var w := size().x
	var h := size().y
	if ads_service != null: ads_service.set_home_banner_visible(capture_mode.is_empty() and not _ads_fullscreen_active)
	var banner_height := float(ads_service.banner_reserved_height()) if ads_service != null and capture_mode.is_empty() else 0.0
	var content_bottom := h - banner_height
	_label("YOUR NEXT ADVENTURE",Rect2(20,35,w-40,49),34,GOLD,true,true)
	_label("%d stars  ·  %d gold  ·  %d / 50 voyages" % [Progression.metric("campaign_stars"),Progression.gold(),Progression.metric("campaign_levels_completed")],Rect2(20,85,w-40,28),17,CREAM,true)
	var b: Dictionary = campaign.get("biomes",[{}])[chart_biome] if campaign.get("biomes",[]).size() > chart_biome else {}
	_label(b.get("name","Sunlit Shoals"),Rect2(60,133,w-120,44),31,CREAM,true,true)
	_button("‹",Rect2(22,137,42,42),func(): chart_biome = maxi(0,chart_biome-1); show_chart(),Color("8ec4bf"))
	_button("›",Rect2(w-64,137,42,42),func(): chart_biome = mini(4,chart_biome+1); show_chart(),Color("8ec4bf"))
	var compact_chart := banner_height > 50
	var path_metrics := _chart_path_metrics(banner_height)
	var path_top := path_metrics.x
	var spacing := path_metrics.y
	var node_height := minf(45,maxf(20,spacing-2))
	for i in 10:
		var id := chart_biome*10+i+1
		var x := w/2 + sin(float(i)*1.1)*w*0.22
		var y := path_top+i*spacing
		var unlocked := Progression.is_level_unlocked(id)
		var state: Dictionary = Progression.level_state(id)
		var stars := int(state.get("stars",0))
		var color := Color("f4cd7e") if unlocked else Color("476772")
		var button := _button(str(id) + (" ★" if id%10 == 0 else ""),Rect2(x-36,y-node_height/2,72,node_height),func(): _select_level(id),color)
		button.disabled = not unlocked
		if stars > 0: _label("★".repeat(stars),Rect2(x+42,y-21,84,40),20,GOLD)
	var bottom := content_bottom-232
	var next: Dictionary = campaign.levels[Progression.next_level()-1] if campaign.get("levels",[]).size() >= Progression.next_level() else {}
	if not compact_chart:
		_panel(Rect2(22,bottom,w-44,64),Color("0f3545"))
		_label("NEXT: " + str(next.get("name","First Splash")),Rect2(36,bottom+4,w-190,25),17,GOLD)
		_label(str(next.get("briefing","Sink the rival ships!")),Rect2(36,bottom+28,w-186,28),13,CREAM)
		_button("Sail!",Rect2(w-130,bottom+10,91,44),func(): _select_level(Progression.next_level()))
	_button("∞ Endless Seas",Rect2(22,content_bottom-151,(w-54)/2,52),func(): selected_mode="endless"; show_ships(),Color("94d7d0"))
	_button("Daily Drift",Rect2(w/2+5,content_bottom-151,(w-54)/2,52),func(): selected_mode="daily"; show_ships(),Color("ffbd89"))
	_button("Shipyard",Rect2(22,content_bottom-84,(w-144)/2,44),func(): shipyard_return="chart"; show_shipyard(),Color("e0be7e"))
	_button("Logbook",Rect2(32+(w-144)/2,content_bottom-84,(w-144)/2,44),show_logbook,Color("a6c5bd"))
	_button("⚙",Rect2(w-106,content_bottom-84,84,44),show_settings,Color("a6c5bd"))
	queue_redraw()

func _select_level(id: int) -> void:
	selected_level = id
	selected_mode = "campaign"
	show_ships()

func start_run() -> void:
	_run_serial += 1
	_run_id = Crypto.new().generate_random_bytes(12).hex_encode()
	_run_finalized = false
	_revive_busy = false
	_return_to_chart_after_finish = false
	_skip_interstitial = false
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = ArenaScript.new()
	add_child(arena)
	arena.allow_rewarded_continue = capture_mode.is_empty()
	arena.defeated.connect(_on_defeated)
	var level_data: Dictionary = campaign.levels[selected_level-1].duplicate(true)
	if selected_mode == "endless":
		level_data = {"id":0,"name":"Endless Seas","objective":{"type":"survive","target":999999},"max_enemies":8,"spawn_interval":3.7,"enemy_pool":["chaser","skirmisher","sniper","rammer","runner"],"enemy_strength":1.0,"treasure_count":8,"hazards":[],"reward":{}}
	elif selected_mode == "daily":
		var date: String = Progression.today()
		var seed_id := absi(hash(date))%50
		level_data = campaign.levels[seed_id].duplicate(true)
		level_data.name = "Daily Drift · " + date
		level_data.objective = {"type":"survive","target":90}
		level_data.duration_limit = 100
		level_data.enemy_strength = 1.7
		level_data.boss = null
		level_data.enemy_pool = campaign.endless.enemy_pool.duplicate()
		level_data.spawn_interval = 4.0
		level_data.max_enemies = 7
		level_data.treasure_count = 6
		level_data.hazards = []
	var biome_id: String = level_data.get("biome",campaign.biomes[0].id)
	var biome_data: Dictionary = campaign.biomes[0]
	for b in campaign.biomes:
		if b.id == biome_id: biome_data = b
	var chosen: Dictionary = Progression.ship_loadout(Progression.ships[selected_ship].id)
	chosen.sprite = [4,2,3,6][selected_ship]
	arena.finished.connect(_run_finished)
	arena.hud_changed.connect(_update_hud)
	arena.toast.connect(_toast)
	var tutorial: bool = selected_mode == "campaign" and selected_level == 1 and not Progression.settings.get("tutorial_seen",false)
	arena.start_run(chosen,level_data,biome_data,selected_mode,tutorial)
	if selected_mode == "daily": arena.rng.seed = absi(hash(Progression.today()))
	screen = "run"
	_run_ui()
	queue_redraw()

func _run_ui() -> void:
	clear_ui()
	var w := size().x
	var h := size().y
	_panel(Rect2(14,17,w-28,125),Color(0.025,0.14,0.20,0.92),Color("356776"))
	hud_title = _label(arena.level.name,Rect2(28,25,w-110,29),24,GOLD,false,true)
	_button("Ⅱ",Rect2(w-65,29,39,40),_pause,Color("b4d4c8"))
	hud_health = ProgressBar.new()
	hud_health.position = Vector2(28,66)
	hud_health.size = Vector2(w-126,13)
	hud_health.show_percentage = false
	hud_health.max_value = arena.max_hp
	for kind in ["background","fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("14313f") if kind=="background" else Color("85dba7")
		style.set_corner_radius_all(6)
		hud_health.add_theme_stylebox_override(kind,style)
	ui.add_child(hud_health)
	hud_score = _label("",Rect2(28,89,w-56,36),21,CREAM)
	hud_goal = _label("",Rect2(16,157,w-32,56),23,CREAM,true,true)
	hud_buff = _label("",Rect2(20,h-310,w-40,40),18,GOLD,true)
	_label("PORT",Rect2(15,h-33,112,27),15,GOLD,true)
	_label("DRAG TO STEER",Rect2(w/2-105,h-33,210,27),14,Color("b4d8d2"),true)
	_label("STARBOARD",Rect2(w-139,h-33,130,27),15,GOLD,true)
	_label("AUTO CAPSTONE ACTIVE" if arena.assisted else "HOLD CANNONS TO FIRE",Rect2(w/2-122,h-226,244,26),12,Color("8abbbc"),true)
	for side in 2:
		if arena.secondary_available(side):
			_label("GRAPESHOT",Rect2(20 if side==0 else w-124,h-187,104,20),11,Color("aed9df"),true)
	_update_hud()

func _update_hud() -> void:
	if screen != "run" or hud_health == null: return
	hud_health.value = arena.hp
	hud_score.text = "%06d  ·  %d sunk  ·  %02d:%02d" % [arena.score,arena.kills,int(arena.elapsed)/60,int(arena.elapsed)%60]
	var obj: Dictionary = arena.level.objective
	var progress := 0
	match obj.type:
		"fleet": progress=arena.kills
		"kills": progress=arena.kills
		"coins": progress=arena.treasure
		"survive": progress=int(arena.elapsed)
		"boss": progress=arena.bosses
	var names := {"fleet":"CLEAR THE FLEET","kills":"SINK RIVALS","coins":"SALVAGE TREASURE","survive":"STAY AFLOAT","boss":"SINK THE CAPTAIN"}
	hud_goal.text = "%s  %d / %d" % [names.get(obj.type,"SAIL!"),progress,int(obj.target)] if selected_mode != "endless" else "ENDLESS SEAS  ·  DANGER %d" % (1+int(arena.elapsed/35))
	if selected_mode == "campaign":
		hud_goal.text += "\n" + str(arena.current_encounter_name)
	var buffs := ""
	if arena.combo > 1: buffs += "%dx COMBO!  " % mini(arena.combo,8)
	if arena.shield_time > 0: buffs += "SHIELD %.0fs  " % arena.shield_time
	if arena.rapid_time > 0: buffs += "RAPID %.0fs" % arena.rapid_time
	if arena.tutorial and arena.elapsed < 23:
		buffs = ["Drag the wheel toward your heading", "Hold a corner cannon to fire that side", "Bring rivals alongside for a broadside"][mini(2,arena.tutorial_step)]
	hud_buff.text = buffs

func _pause() -> void:
	if arena == null: return
	arena.paused = true
	clear_ui()
	var w := size().x
	var h := size().y
	_panel(Rect2(24,h/2-210,w-48,420),Color("123543"))
	_label("ANCHORS DOWN",Rect2(40,h/2-188,w-80,55),40,GOLD,true,true)
	_button("Keep sailing",Rect2(50,h/2-106,w-100,60),func(): arena.paused=false; _run_ui())
	if arena.ship.get("primary_auto",false):
		_button("Capstone auto fire: " + ("ON" if arena.assisted else "OFF"),Rect2(50,h/2-30,w-100,55),func(): arena.set_primary_assist(not arena.assisted); Progression.set_setting("auto_fire",arena.assisted); _pause(),Color("97cabe"))
	else:
		_label("Manual cannons · hold either side to fire\nAutomation is a final Shipyard unlock",Rect2(48,h/2-34,w-96,62),18,Color("b8d6ce"),true)
	_button("End voyage",Rect2(50,h/2+43,w-100,55),func(): arena.paused=false; arena.finish(false),Color("e7a184"))
	_label("Steer: wheel / WASD  ·  Cannons: Q / E\nUnlocked grapeshot: Z / C",Rect2(45,h/2+119,w-90,55),16,CREAM,true)

func _run_finished(summary: Dictionary) -> void:
	if _run_finalized: return
	_run_finalized = true
	last_summary = summary
	# Screenshot playback is a read-only preview of the profile. It must never
	# grant XP/gold/unlocks or complete the player's tutorial.
	if capture_mode.is_empty():
		summary.run_id = _run_id
		reward = Progression.record_run(summary)
		if arena.tutorial: Progression.set_setting("tutorial_seen",true)
	else:
		reward={"xp":0,"coins":0,"rank_before":1,"rank_after":1}
	screen = "result"
	_result_ui()
	if capture_mode.is_empty() and ads_service != null:
		var due: bool = ads_service.record_completed_run()
		if due and not _skip_interstitial: call_deferred("_maybe_interstitial",_run_serial)
	if _return_to_chart_after_finish: show_chart()

func _on_defeated() -> void:
	if _run_finalized or arena == null: return
	if ads_service != null and ads_service.is_rewarded_ready() and arena.revives_used < arena.MAX_REVIVES:
		screen = "revive"
		_revive_ui()
	else:
		arena.finalize_defeat()

func _revive_ui() -> void:
	clear_ui()
	var w := size().x
	var h := size().y
	_panel(Rect2(24,h/2-210,w-48,420),Color("123543"))
	_label("ONE MORE VOYAGE?",Rect2(40,h/2-185,w-80,55),34,GOLD,true,true)
	_label("Watch an ad to restore your full hull.\nKeep this voyage's score, treasure and progress.\nOne rescue per voyage.",Rect2(45,h/2-112,w-90,100),20,CREAM,true)
	_button("Watch ad · restore full hull",Rect2(45,h/2+12,w-90,60),_watch_revive,Color("a6d889"))
	_button("End voyage & return",Rect2(45,h/2+95,w-90,55),_decline_revive,Color("b5cfca"))

func _revive_wait_ui() -> void:
	clear_ui()
	var w := size().x
	var h := size().y
	_panel(Rect2(24,h/2-120,w-48,240),Color("123543"))
	_label("YOUR RESCUE AWAITS",Rect2(40,h/2-88,w-80,52),30,GOLD,true,true)
	_label("Complete the rewarded ad to return with full hull.\nYour voyage is paused.",Rect2(45,h/2-15,w-90,95),20,CREAM,true)

func _watch_revive() -> void:
	if screen != "revive" or _revive_busy or _run_finalized: return
	_revive_busy = true
	screen = "revive_ad"
	_revive_wait_ui()
	var serial := _run_serial
	var accepted := false
	if ads_service != null:
		accepted = ads_service.show_rewarded_continue(func(granted: bool): _complete_revive(granted,serial))
	if not accepted: _complete_revive(false,serial)

func _decline_revive() -> void:
	if screen != "revive" or _revive_busy: return
	_complete_revive(false,_run_serial)

func _complete_revive(granted: bool, serial: int = -1) -> void:
	if (serial >= 0 and serial != _run_serial) or _run_finalized or arena == null or not arena.defeat_pending: return
	var attempted_ad := _revive_busy or screen == "revive_ad"
	_revive_busy = false
	if granted and arena.resume_after_reward():
		screen = "run"
		_run_ui()
		if _application_backgrounded or _ads_fullscreen_active: _pause()
		_toast("FULL HULL!  Back to the plunder")
	else:
		_return_to_chart_after_finish = true
		# Avoid stacking another fullscreen ad immediately after an incomplete or
		# failed rewarded presentation. Declining the offer still uses cadence.
		_skip_interstitial = attempted_ad
		arena.finalize_defeat()

func _maybe_interstitial(serial: int) -> void:
	if serial != _run_serial or ads_service == null: return
	if screen != "result" and not (screen == "chart" and _return_to_chart_after_finish): return
	ads_service.show_interstitial_if_due(func(): pass)

func _banner_layout_changed(_height: float) -> void:
	if screen == "chart" and is_inside_tree(): call_deferred("_refresh_banner_layout")

func _refresh_banner_layout() -> void:
	if screen == "chart" and not _ads_fullscreen_active: show_chart()

func _ads_availability_changed() -> void:
	if screen == "settings": call_deferred("_refresh_ad_settings")

func _refresh_ad_settings() -> void:
	if screen == "settings": show_settings()

func _ad_started(_kind: String) -> void:
	_ads_fullscreen_active = true
	if ads_service != null: ads_service.set_home_banner_visible(false)
	_ad_pause_was_paused = arena.paused if arena != null else true
	if arena != null: arena.paused = true
	if music != null:
		_ad_music_was_paused = music.stream_paused
		music.stream_paused = true

func _ad_finished(_kind: String) -> void:
	_ads_fullscreen_active = false
	if music != null: music.stream_paused = _ad_music_was_paused or _application_backgrounded
	if arena != null and arena.running and screen == "run" and not _ad_pause_was_paused:
		if _application_backgrounded: _pause()
		else: arena.paused = false
	if screen == "chart": call_deferred("_refresh_banner_layout")

func _result_ui() -> void:
	clear_ui()
	var w := size().x
	var h := size().y
	_panel(Rect2(25,145,w-50,h-270),Color(0.025,0.17,0.23,0.98))
	_label("PLUNDERED!" if last_summary.won else "A GLORIOUS WRECK!",Rect2(40,175,w-80,74),44,GOLD,true,true)
	_label("★".repeat(int(last_summary.stars)) if last_summary.won else "Your next voyage awaits",Rect2(40,260,w-80,55),49 if last_summary.won else 21,CREAM,true,true)
	_label("%06d" % last_summary.score,Rect2(40,341,w-80,72),55,CREAM,true,true)
	_label("%d ships sunk  ·  %d treasures\n%d:%02d at sea  ·  best combo %dx" % [last_summary.kills,last_summary.treasure,int(last_summary.seconds)/60,int(last_summary.seconds)%60,last_summary.max_combo],Rect2(44,422,w-88,77),21,Color("bce0d6"),true)
	_label("+%d GOLD    +%d SHIP XP" % [reward.get("coins",0),reward.get("xp",0)],Rect2(45,524,w-90,45),25,GOLD,true,true)
	if reward.get("rank_after",1) > reward.get("rank_before",1): _label("SHIP RANK UP!",Rect2(45,568,w-90,33),24,Color("90ecaf"),true,true)
	var y := h-309
	if last_summary.won and selected_mode == "campaign" and selected_level < 50:
		_button("Next adventure →",Rect2(50,y,w-100,60),func(): selected_level+=1; start_run())
	else: _button("Sail again!",Rect2(50,y,w-100,60),start_run)
	_button("Chart & change ship",Rect2(50,y+78,w-100,55),func(): chart_biome=mini(4,(Progression.next_level()-1)/10); show_chart(),Color("a1cfc3"))
	queue_redraw()

func show_logbook() -> void:
	_hide_arena()
	screen = "logbook"
	clear_ui()
	var w := size().x
	var h := size().y
	_label("CAPTAIN'S LOGBOOK",Rect2(20,30,w-40,57),37,GOLD,true,true)
	_button("‹ Chart",Rect2(23,103,127,42),show_chart,Color("a1cfc3"))
	_button("Play Games",Rect2(w-185,103,160,42),func(): PlayServices.sign_in(); _toast(PlayServices.status),Color("a1cfc3"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(22,164)
	scroll.size = Vector2(w-44,h-186)
	ui.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(w-63,2600)
	scroll.add_child(content)
	var cw := w-64
	_label("%d GOLD  ·  %d SHIPS SUNK" % [Progression.gold(),Progression.metric("enemies_sunk")],Rect2(0,0,cw,42),25,CREAM,true,true,content)
	_label(PlayServices.status,Rect2(0,44,cw,44),15,Color("add4cc"),true,false,content)
	_button("Claim daily supply · streak %d" % Progression.login_streak(),Rect2(0,104,cw,50),func(): var r: Dictionary=Progression.claim_login_reward(Progression.ships[selected_ship].id); _toast("+%d GOLD · supply claimed" % r.get("coins",0)); show_logbook(),GOLD,content).disabled = not Progression.login_reward_available()
	_label("DAILY BOUNTIES",Rect2(0,173,cw,40),28,GOLD,false,true,content)
	var y := 224.0
	for quest in Progression.get_daily_quests():
		_panel(Rect2(0,y,cw,92),Color("143e4b"),Color("42777a"),content)
		_label(quest.name,Rect2(14,y+7,cw-28,29),20,CREAM,false,false,content)
		_label("%d / %d  ·  +%d gold" % [quest.get("current",0),quest.target,quest.coins],Rect2(14,y+42,cw-144,29),17,GOLD,false,false,content)
		var qid: String = quest.id
		var claim := _button("Claim",Rect2(cw-108,y+39,94,40),func(): Progression.claim_daily(qid,Progression.ships[selected_ship].id); show_logbook(),Color("a4d5c5"),content)
		claim.disabled = not quest.get("complete",false) or quest.get("claimed",false)
		y += 105
	_label("FAME ON THE HIGH SEAS",Rect2(0,y+13,cw,44),27,GOLD,false,true,content)
	y += 69
	for board in Progression.leaderboards:
		var bid: String=board.id
		_button(board.name + "  ↗",Rect2(0,y,cw,46),func(): PlayServices.show_leaderboards(bid); _toast(PlayServices.status),Color("a4c9c1"),content)
		y += 55
	_label("TREASURED ACHIEVEMENTS",Rect2(0,y+17,cw,42),27,GOLD,false,true,content)
	y += 74
	for achievement in Progression.achievements:
		var unlocked: bool=Progression.data.achievements.has(achievement.id)
		_label(("★ " if unlocked else "○ ") + achievement.name,Rect2(4,y,cw-8,31),20,GOLD if unlocked else CREAM,false,true,content)
		_label(achievement.description,Rect2(29,y+31,cw-34,45),16,Color("9fc4c2"),false,false,content)
		y += 87
	content.custom_minimum_size.y = y+20
	queue_redraw()

func show_settings() -> void:
	_hide_arena()
	screen = "settings"
	clear_ui()
	var w := size().x
	var h := size().y
	_label("SHIPSHAPE SETTINGS",Rect2(20,52,w-40,65),37,GOLD,true,true)
	var y := 157.0
	var options := [["music","Music"],["sfx","Sound effects"],["reduced_motion","Reduced motion"],["haptics","Haptics"]]
	for s in Progression.ships:
		if Progression.ship_loadout(s.id).primary_auto:
			options.append(["auto_fire","Capstone auto fire"])
			break
	for item in options:
		var key: String=item[0]
		_button(item[1] + ": " + ("ON" if Progression.settings.get(key,true) else "OFF"),Rect2(35,y,w-70,55),func(): Progression.set_setting(key,not Progression.settings.get(key,true)); _music_setting(); show_settings(),Color("a1cfc3"))
		y += 72
	_label("Drag the wheel toward your heading. Your ship keeps moving.\n\nHold the left or right cannon to fire that side. Steer alongside rivals for a broadside.\n\nBuy extra cannons and separate grapeshot guns in the Shipyard as your ship ranks up.",Rect2(38,y+12,w-76,218),19,CREAM,true)
	if ads_service != null and ads_service.privacy_options_required():
		_button("Ad privacy choices",Rect2(35,h-194,w-70,45),func(): ads_service.show_privacy_options(),Color("a1cfc3"))
	_button("Replay the first voyage",Rect2(35,h-133,w-70,54),func(): Progression.set_setting("tutorial_seen",false); selected_level=1; selected_mode="campaign"; show_ships())
	_button("‹ Back to chart",Rect2(35,h-63,w-70,45),show_chart,Color("a1cfc3"))
	queue_redraw()

func show_shipyard() -> void:
	_hide_arena()
	screen = "shipyard"
	clear_ui()
	var w := size().x
	var h := size().y
	var ship_id: String = Progression.ships[selected_ship].id
	var s: Dictionary = Progression.ship_loadout(ship_id)
	var rank: Dictionary = Progression.ship_rank_progress(ship_id)
	_label("THE SHIPYARD",Rect2(20,27,w-40,56),40,GOLD,true,true)
	_label("%d GOLD  ·  upgrades stay with each ship" % Progression.gold(),Rect2(20,85,w-40,31),17,CREAM,true)
	var tab_w := (w-52)/4
	for i in Progression.ships.size():
		var index := i
		var name_text: String = Progression.ships[i].name.replace("Golden Gull","Gull")
		var tab := _button(name_text,Rect2(20+i*(tab_w+4),133,tab_w,43),func(): selected_ship=index; show_shipyard(),Color(Progression.ships[i].color) if i==selected_ship else Color("8eb6b2"))
		tab.add_theme_font_size_override("font_size",16)
	_label("%s · RANK %d" % [s.name,rank.rank],Rect2(25,187,w-50,42),30,Color(s.color),true,true)
	_label("%d / %d XP to next rank" % [rank.current,rank.needed] if rank.rank<20 else "MAX RANK · MASTER OF THE SEAS",Rect2(25,230,w-50,27),17,CREAM,true)
	_panel(Rect2(38,269,w-76,9),Color("174752"),Color("174752"))
	var fraction := clampf(float(rank.current)/maxf(1,float(rank.needed)),0,1) if rank.rank<20 else 1.0
	if fraction>0: _panel(Rect2(38,269,(w-76)*fraction,9),Color("a8d985"),Color("a8d985"))
	_label("PORT %d  /  STARBOARD %d   ·   %.1fs reload" % [s.cannons_port,s.cannons_starboard,s.cooldown],Rect2(24,290,w-48,30),18,GOLD,true)
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(22,337)
	scroll.size=Vector2(w-44,h-413)
	ui.add_child(scroll)
	var content := Control.new()
	var upgrades: Array=Progression.get_ship_upgrades(ship_id)
	var cw := w-64
	content.custom_minimum_size=Vector2(cw,upgrades.size()*162)
	scroll.add_child(content)
	for i in upgrades.size():
		var upgrade: Dictionary=upgrades[i]
		var y := float(i)*162
		_panel(Rect2(0,y,cw,150),Color("163e4b"),Color("769989") if upgrade.owned else Color("436e76"),content)
		_label(upgrade.name,Rect2(14,y+7,cw-28,32),24,GOLD if upgrade.owned else CREAM,false,true,content)
		_label(upgrade.description,Rect2(14,y+41,cw-28,59),16,Color("b4d1ce"),false,false,content)
		_label("INSTALLED" if upgrade.owned else str(upgrade.reason),Rect2(14,y+109,cw-160,30),14,Color("91dfa8") if upgrade.owned else Color("b6c7c4"),false,false,content)
		var uid: String=upgrade.id
		var buy := _button("Owned" if upgrade.owned else "%d gold" % upgrade.cost,Rect2(cw-139,y+108,125,34),func(): _buy_upgrade(ship_id,uid),Color("b0cfb8") if upgrade.owned else GOLD,content)
		buy.add_theme_font_size_override("font_size",16)
		buy.disabled=not upgrade.eligible or upgrade.owned
	_button("‹ Choose a ship" if shipyard_return=="ships" else "‹ Your next adventure",Rect2(25,h-57,w-50,42),func(): show_ships() if shipyard_return=="ships" else show_chart(),Color("a4cbc2"))
	queue_redraw()

func _buy_upgrade(ship_id: String, upgrade_id: String) -> void:
	var result: Dictionary=Progression.purchase_upgrade(ship_id,upgrade_id)
	show_shipyard()
	_toast(result.get("message","Upgrade installed"))

func _music_setting() -> void:
	if Progression.settings.music:
		if not music.playing: music.play()
	else: music.stop()

func _hide_arena() -> void:
	if arena != null and is_instance_valid(arena):
		arena.visible = false
		arena.paused = true

func _achievement_toast(id: String) -> void:
	for a in Progression.achievements:
		if a.id == id: _toast("★ " + a.name)

func _toast(message: String) -> void:
	if toast_label != null and is_instance_valid(toast_label): toast_label.queue_free()
	toast_label = _label(message,Rect2(30,size().y*0.26,size().x-60,62),23,GOLD,true,true)
	toast_time = 3.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_backgrounded = true
		if music != null: music.stream_paused = true
		if arena != null and screen == "run" and not _ads_fullscreen_active: _pause()
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_application_backgrounded = false
		if music != null: music.stream_paused = _ads_fullscreen_active
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _ads_fullscreen_active or screen == "revive_ad": return
		if screen == "revive": _decline_revive()
		elif screen == "run": _pause()
		elif screen == "shipyard" and shipyard_return=="ships": show_ships()
		else: show_chart()

func _exit_tree() -> void:
	if music != null and is_instance_valid(music):
		music.stop()
		music.stream = null

func _process(dt: float) -> void:
	clock += dt
	if toast_time > 0:
		toast_time -= dt
		if toast_time <= 0 and toast_label != null and is_instance_valid(toast_label): toast_label.queue_free(); toast_label=null
	if screen != "run" and screen != "result": queue_redraw()
	if not capture_mode.is_empty():
		capture_time += dt
		capture_frames += 1
		if capture_time > (1.6 if capture_mode == "combat" or capture_mode == "boss" else 0.7) and capture_frames > 8:
			capture_mode = ""
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(capture_dir)
			var img := get_viewport().get_texture().get_image()
			var file: String = capture_dir.path_join("capture.png")
			img.save_png(file)
			print("CAPTURE_SAVED " + file + " " + str(img.get_size()))
			get_tree().quit()

func _setup_capture() -> void:
	match capture_mode:
		"chart": show_chart()
		"ships": show_ships()
		"shipyard": show_shipyard()
		"combat", "boss":
			selected_level = 10 if capture_mode == "boss" else 6
			selected_ship = 2
			start_run()
			arena.debug_invulnerable = true
			arena.automated = true
			# Capture the actual authored encounter, without adding ships or moving land.
			for i in (9600 if capture_mode=="boss" else 600):
				if not arena.running: break
				arena.step(1.0/60.0)
				if capture_mode=="boss":
					var visible_boss := false
					for enemy in arena.enemies:
						if enemy.kind=="boss" and enemy.pos.distance_to(arena.player)<260: visible_boss=true
					if visible_boss: break
			arena.paused=true
			arena.queue_redraw()
			_update_hud()
		"logbook": show_logbook()
		_: show_chart()

func _draw() -> void:
	if screen == "run" or screen == "result": return
	var s := size()
	draw_rect(Rect2(Vector2.ZERO,s),Color("087b91"))
	for y in range(-1,int(s.y/67)+2):
		for x in range(-1,int(s.x/72)+2):
			var p := Vector2(x*72+sin(clock*0.5+y)*9,y*67)
			draw_arc(p,14,0.1,2.8,12,Color(0.5,0.95,0.93,0.15),2,true)
	for p in [Vector2(-25,310),Vector2(s.x+25,510),Vector2(s.x-35,s.y-30)]:
		draw_circle(p,97,Color(0.47,0.86,0.78,0.18))
		draw_circle(p,80,Color("e5cc91"))
		draw_circle(p+Vector2(0,2),63,Color("69b580"))
		for i in 4:
			var t: Vector2 = p+Vector2.from_angle(i*2)*36
			draw_line(t+Vector2(2,16),t,Color("92704a"),7,true)
			for j in 5: draw_line(t,t+Vector2.from_angle(j*TAU/5)*24,Color("4e9670"),9,true)
	if screen == "chart":
		var banner_height := float(ads_service.banner_reserved_height()) if ads_service != null and capture_mode.is_empty() else 0.0
		var metrics := _chart_path_metrics(banner_height)
		var spacing := metrics.y
		var previous := Vector2(s.x/2,metrics.x)
		for i in range(1,10):
			var p := Vector2(s.x/2+sin(float(i)*1.1)*s.x*0.22,metrics.x+i*spacing)
			draw_line(previous,p,Color("a1ccc2"),7,true)
			previous=p
