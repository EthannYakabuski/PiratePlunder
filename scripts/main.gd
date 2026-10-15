extends Node2D
## Small-screen first presentation. Ship cards -> chart -> a single tap to sail.
const ArenaScript := preload("res://scripts/arena.gd")
const CREAM := Color("fff0cc")
const GOLD := Color("ffd27b")
const INK := Color("0c3445")
var ui: Control
var backdrop: Node2D
var arena: Node2D
var screen := "ships"
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
var launch_cards := true
var capture_mode := ""
var capture_dir := "res://store/screenshots/phone"
var capture_time := 0.0
var capture_frames := 0

func _ready() -> void:
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
	show_ships(true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_mode = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_mode.is_empty(): call_deferred("_setup_capture")

func size() -> Vector2: return get_viewport_rect().size

func _resize() -> void:
	match screen:
		"ships": show_ships(launch_cards)
		"chart": show_chart()
		"run": _run_ui()
		"result": _result_ui()
		"logbook": show_logbook()
		"settings": show_settings()
	queue_redraw()

func clear_ui() -> void:
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
	label.size = rect.size
	label.add_theme_font_override("font",title_font if title else body_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent != null else ui).add_child(label)
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

func show_ships(initial := false) -> void:
	_hide_arena()
	screen = "ships"
	launch_cards = initial
	clear_ui()
	var w := size().x
	var h := size().y
	var top := 54.0
	_label("PIRATE\nPLUNDER" if initial else "CHOOSE YOUR SHIP",Rect2(20,top,w-40,116 if initial else 54),53 if initial else 38,GOLD,true,true)
	_label("Tiny ship. Ridiculous adventure." if initial else _voyage_title(),Rect2(22,top+116 if initial else top+58,w-44,35),20,CREAM,true)
	var card_top := 224.0 if initial else 171.0
	var card_h := minf(139,(h-card_top-130)/4.0-10)
	for i in Progression.ships.size():
		var s: Dictionary = Progression.ships[i]
		var y := card_top + i*(card_h+12)
		var card := _button("",Rect2(26,y,w-52,card_h),func(): _choose_ship(i,initial),Color("123d4c"))
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
		_label("HULL %d   SPEED %d   RELOAD %.1fs" % [s.hp,s.speed,s.cooldown],Rect2(104,70,w-184,23),16,Color("b3d9d6"),false,false,card)
		_label("RANK %d  ·  %s" % [rank.rank,s.perk.name],Rect2(104,94,w-184,24),15,GOLD,false,false,card)
	_label("Pick a ship to chart your voyage" if initial else "Tap a ship and set sail",Rect2(20,h-93,w-40,32),18,CREAM,true)
	if initial:
		_button("Logbook",Rect2(30,h-48,145,36),show_logbook,Color("9fcac4"))
		_button("Sound & help",Rect2(w-196,h-48,166,36),show_settings,Color("9fcac4"))
	else: _button("‹ Chart",Rect2(26,h-50,140,38),show_chart,Color("9fcac4"))
	queue_redraw()

func _choose_ship(index: int, initial: bool) -> void:
	selected_ship = index
	if initial:
		selected_level = Progression.next_level()
		chart_biome = mini(4,(selected_level-1)/10)
		show_chart()
	else: start_run()

func _voyage_title() -> String:
	if selected_mode == "endless": return "Endless Seas · How long can you last?"
	if selected_mode == "daily": return "Daily Drift · One seed. Fresh challenge."
	if campaign.get("levels",[]).size() >= selected_level: return "%02d · %s" % [selected_level,campaign.levels[selected_level-1].name]
	return "Your voyage awaits"

func show_chart() -> void:
	_hide_arena()
	screen = "chart"
	clear_ui()
	var w := size().x
	var h := size().y
	_label("YOUR NEXT ADVENTURE",Rect2(20,35,w-40,49),34,GOLD,true,true)
	_label("%d stars  ·  %d gold  ·  %s" % [Progression.metric("campaign_stars"),Progression.gold(),Progression.ships[selected_ship].name],Rect2(20,85,w-40,28),17,CREAM,true)
	var b: Dictionary = campaign.get("biomes",[{}])[chart_biome] if campaign.get("biomes",[]).size() > chart_biome else {}
	_label(b.get("name","Sunlit Shoals"),Rect2(60,133,w-120,44),31,CREAM,true,true)
	_button("‹",Rect2(22,137,42,42),func(): chart_biome = maxi(0,chart_biome-1); show_chart(),Color("8ec4bf"))
	_button("›",Rect2(w-64,137,42,42),func(): chart_biome = mini(4,chart_biome+1); show_chart(),Color("8ec4bf"))
	var path_top := 217.0
	var spacing := minf(48,(h-430)/10)
	for i in 10:
		var id := chart_biome*10+i+1
		var x := w/2 + sin(float(i)*1.1)*w*0.22
		var y := path_top+i*spacing
		var unlocked := Progression.is_level_unlocked(id)
		var state: Dictionary = Progression.level_state(id)
		var stars := int(state.get("stars",0))
		var color := Color("f4cd7e") if unlocked else Color("476772")
		var button := _button(str(id) + (" ★" if id%10 == 0 else ""),Rect2(x-36,y-22,72,45),func(): _select_level(id),color)
		button.disabled = not unlocked
		if stars > 0: _label("★".repeat(stars),Rect2(x+42,y-21,84,40),20,GOLD)
	var bottom := h-232
	_panel(Rect2(22,bottom,w-44,64),Color("0f3545"))
	var next: Dictionary = campaign.levels[Progression.next_level()-1] if campaign.get("levels",[]).size() >= Progression.next_level() else {}
	_label("NEXT: " + str(next.get("name","First Splash")),Rect2(36,bottom+4,w-190,25),17,GOLD)
	_label(str(next.get("briefing","Sink the rival ships!")),Rect2(36,bottom+28,w-186,28),13,CREAM)
	_button("Sail!",Rect2(w-130,bottom+10,91,44),func(): _select_level(Progression.next_level()))
	_button("∞ Endless Seas",Rect2(22,h-151,(w-54)/2,52),func(): selected_mode="endless"; show_ships(false),Color("94d7d0"))
	_button("Daily Drift",Rect2(w/2+5,h-151,(w-54)/2,52),func(): selected_mode="daily"; show_ships(false),Color("ffbd89"))
	_button("Logbook & rewards",Rect2(22,h-84,w-142,44),show_logbook,Color("a6c5bd"))
	_button("⚙",Rect2(w-106,h-84,84,44),show_settings,Color("a6c5bd"))
	queue_redraw()

func _select_level(id: int) -> void:
	selected_level = id
	selected_mode = "campaign"
	show_ships(false)

func start_run() -> void:
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = ArenaScript.new()
	add_child(arena)
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
	var biome_id: String = level_data.get("biome",campaign.biomes[0].id)
	var biome_data: Dictionary = campaign.biomes[0]
	for b in campaign.biomes:
		if b.id == biome_id: biome_data = b
	var chosen: Dictionary = Progression.ships[selected_ship].duplicate(true)
	var bonus: Dictionary = Progression.ship_bonus(chosen.id)
	for key in ["hp","damage"]:
		if bonus.has(key): chosen[key] += bonus[key]
	chosen.cooldown *= bonus.get("cooldown_multiplier",1.0)
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
	hud_buff = _label("",Rect2(20,h-282,w-40,40),18,GOLD,true)
	_label("PORT",Rect2(15,h-33,112,27),15,GOLD,true)
	_label("DRAG TO STEER",Rect2(w/2-105,h-33,210,27),14,Color("b4d8d2"),true)
	_label("STARBOARD",Rect2(w-139,h-33,130,27),15,GOLD,true)
	_label("ONE THUMB · AUTO BROADSIDES" if arena.assisted else "MANUAL BROADSIDES · Q / E",Rect2(20,h-226,w-40,26),12,Color("8abbbc"),true)
	_update_hud()

func _update_hud() -> void:
	if screen != "run" or hud_health == null: return
	hud_health.value = arena.hp
	hud_score.text = "%06d  ·  %d sunk  ·  %02d:%02d" % [arena.score,arena.kills,int(arena.elapsed)/60,int(arena.elapsed)%60]
	var obj: Dictionary = arena.level.objective
	var progress := 0
	match obj.type:
		"kills": progress=arena.kills
		"coins": progress=arena.treasure
		"survive": progress=int(arena.elapsed)
		"boss": progress=arena.bosses
	var names := {"kills":"SINK RIVALS","coins":"SALVAGE TREASURE","survive":"STAY AFLOAT","boss":"SINK THE CAPTAIN"}
	hud_goal.text = "%s  %d / %d" % [names.get(obj.type,"SAIL!"),progress,int(obj.target)] if selected_mode != "endless" else "ENDLESS SEAS  ·  DANGER %d" % (1+int(arena.elapsed/35))
	var buffs := ""
	if arena.combo > 1: buffs += "%dx COMBO!  " % mini(arena.combo,8)
	if arena.shield_time > 0: buffs += "SHIELD %.0fs  " % arena.shield_time
	if arena.rapid_time > 0: buffs += "RAPID %.0fs" % arena.rapid_time
	if arena.tutorial and arena.elapsed < 23:
		buffs = ["Drag the wheel toward your heading", "Cannons fire as rivals cross your sides", "Tap corner cannons for extra control"][mini(2,arena.tutorial_step)]
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
	_button("Auto fire: " + ("ON" if arena.assisted else "OFF"),Rect2(50,h/2-30,w-100,55),func(): arena.assisted=not arena.assisted; Progression.set_setting("auto_fire",arena.assisted); _pause(),Color("97cabe"))
	_button("End voyage",Rect2(50,h/2+43,w-100,55),func(): arena.paused=false; arena.finish(false),Color("e7a184"))
	_label("Steer: wheel / WASD  ·  Cannons: Q / E",Rect2(45,h/2+123,w-90,43),17,CREAM,true)

func _run_finished(summary: Dictionary) -> void:
	last_summary = summary
	reward = Progression.record_run(summary)
	if arena.tutorial: Progression.set_setting("tutorial_seen",true)
	screen = "result"
	_result_ui()

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
		_label("%d / %d  ·  +%d gold" % [quest.get("progress",0),quest.target,quest.coins],Rect2(14,y+42,cw-144,29),17,GOLD,false,false,content)
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
	for item in [["music","Music"],["sfx","Sound effects"],["auto_fire","One-thumb auto fire"],["reduced_motion","Reduced motion"],["haptics","Haptics"]]:
		var key: String=item[0]
		_button(item[1] + ": " + ("ON" if Progression.settings.get(key,true) else "OFF"),Rect2(35,y,w-70,55),func(): Progression.set_setting(key,not Progression.settings.get(key,true)); _music_setting(); show_settings(),Color("a1cfc3"))
		y += 72
	_label("Drag the wheel toward where you want to sail.\nYour ship keeps moving.\n\nRivals crossing either side trigger automatic cannons. Tap the two corner cannons to fire yourself.\n\nCollect gold, green repairs, blue shields and orange rapid-fire boosts.",Rect2(38,y+12,w-76,218),19,CREAM,true)
	_button("Replay the first voyage",Rect2(35,h-133,w-70,54),func(): Progression.set_setting("tutorial_seen",false); selected_level=1; selected_mode="campaign"; show_ships(false))
	_button("‹ Back to chart",Rect2(35,h-63,w-70,45),show_chart,Color("a1cfc3"))
	queue_redraw()

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
	if what == NOTIFICATION_APPLICATION_PAUSED and arena != null and screen == "run": _pause()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen == "run": _pause()
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
		"combat", "boss":
			selected_level = 10 if capture_mode == "boss" else 6
			selected_ship = 2
			start_run()
			arena.debug_invulnerable = true
			arena.automated = true
			arena.player = Vector2(650,500)
			arena.pickups.clear()
			for i in 6: arena._drop(arena.player+Vector2.from_angle(i*1.1)*140,"coin" if i%2==0 else "shield")
			if capture_mode == "boss": arena.elapsed=10; arena._update_spawns(0)
			else:
				for i in 3: arena.spawn_enemy("skirmisher" if i%2==0 else "chaser")
			for i in arena.enemies.size():
				var enemy: Dictionary=arena.enemies[i]
				enemy.pos = arena.player+Vector2(-150 if i%2==0 else 150,-185+float(i)*60)
				enemy.heading=(arena.player-enemy.pos).angle()
			for i in 75: arena.step(1.0/60.0)
			arena.paused=true
			arena.queue_redraw()
			_update_hud()
		"logbook": show_logbook()
		_: show_ships(true)

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
		var spacing := minf(48,(s.y-430)/10)
		var previous := Vector2(s.x/2,217)
		for i in range(1,10):
			var p := Vector2(s.x/2+sin(float(i)*1.1)*s.x*0.22,217+i*spacing)
			draw_line(previous,p,Color("a1ccc2"),7,true)
			previous=p
