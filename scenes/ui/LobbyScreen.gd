extends Control
## LobbyScreen — role + element pick, ready-up, player list panel.
## D-07: Single screen, role top, element bottom.
## D-08: Taken roles grayed out with "Taken" label.
## D-09: Live player list panel on right.
##
## Comic-card layout (UI pass 2026-07): three columns of paper cards.
##   Left   — IP, ROLLE card, ELEMENT card, READY/START card (+ host room picker).
##   Middle — VORSCHAU card (animated stage cycle + role ability info) and ELEMENT card;
##            both hidden by default and only shown on hover or after a pick, so the
##            screen starts calm instead of full.
##   Right  — SPIELER card (live player list).

@onready var ip_label: Label = $Main/LeftPanel/IPCard/IPContainer/IPLabel
@onready var copy_btn: Button = $Main/LeftPanel/IPCard/IPContainer/CopyButton
@onready var tank_btn: Button = $Main/LeftPanel/RoleCard/RoleBox/RoleButtons/TankButton
@onready var speedster_btn: Button = $Main/LeftPanel/RoleCard/RoleBox/RoleButtons/SpeedsterButton
@onready var engineer_btn: Button = $Main/LeftPanel/RoleCard/RoleBox/RoleButtons/EngineerButton
@onready var fire_btn: Button = $Main/LeftPanel/ElementCard/ElementBox/ElementButtons/FireButton
@onready var ice_btn: Button = $Main/LeftPanel/ElementCard/ElementBox/ElementButtons/IceButton
@onready var earth_btn: Button = $Main/LeftPanel/ElementCard/ElementBox/ElementButtons/EarthButton
@onready var ready_btn: Button = $Main/LeftPanel/StartCard/StartBox/ReadyButton
@onready var start_btn: Button = $Main/LeftPanel/StartCard/StartBox/StartButton
@onready var status_label: Label = $Main/LeftPanel/StartCard/StartBox/StatusLabel
@onready var player_list: VBoxContainer = $Main/PlayerCard/PlayerBox/PlayerList
@onready var preview_card: PanelContainer = $Main/MiddlePanel/PreviewCard
@onready var preview_image: TextureRect = $Main/MiddlePanel/PreviewCard/PreviewBox/PreviewImage
@onready var preview_stage_label: Label = $Main/MiddlePanel/PreviewCard/PreviewBox/PreviewStageLabel
@onready var role_info: Label = $Main/MiddlePanel/PreviewCard/PreviewBox/RoleInfo
@onready var element_info_card: PanelContainer = $Main/MiddlePanel/ElementInfoCard
@onready var element_info: Label = $Main/MiddlePanel/ElementInfoCard/ElementInfoBox/ElementInfo

var _is_ready: bool = false
var _is_host: bool = false

## Host-only start-room picker: replaced the old OptionButton dropdown with three buttons
## under Start. _selected_room is the id (1=Erba, 2=Altstadt, 3=Burg) sent to start_game.
var _selected_room: int = 1
var _room_buttons: Array = []  ## [{"id": int, "btn": Button}, …]

## Role → character-sprite key (matches assets/active/players/<key>_<stage>_idle.png).
const ROLE_SPRITE_KEY := {"Tank": "tank", "Speedster": "speedster", "Engineer": "engineer"}
const PLAYER_SPRITE_DIR := "res://assets/active/players/"

## Short "what it does" bullets per element, shown in the ElementInfo card on hover/selection.
const ELEMENT_INFO := {
	"Fire": "FEUER 🔥\n• Feuer-Salve auf den nächsten Gegner\n• Zündet Gegner an (Brand-Schaden)\n• Feuert schneller je Tier",
	"Ice": "EIS ❄️\n• Legt Frost-Flecken beim Laufen\n• Verlangsamt Gegner die reinlaufen\n• Mehr Flecken je Tier",
	"Earth": "ERDE 🌿\n• Stein-Aura heilt dich über Zeit\n• Schockwelle stößt Gegner weg\n• Stärker je Tier",
}

## "What the character can do" bullets per role, shown under the preview sprite.
## Numbers mirror Player.gd (_apply_role_stats, _use_stage1/2_ability) and the
## Engineer team-heal in Game.gd — update here if those get retuned.
const ROLE_INFO := {
	"Tank": "TANK 🛡\n• 150 HP — hält am meisten aus\n• [SPACE] Schild: blockt 3s allen Schaden\n• Stufe 2: 6s Schild + reflektiert Schaden",
	"Speedster": "SPEEDSTER 💨\n• Speed 280 — der Schnellste im Team\n• [SPACE] Dash mit Unverwundbarkeit\n• Stufe 2: Doppel-Dash",
	"Engineer": "ENGINEER 🔧\n• [SPACE] Heil-Drohne (bis zu 2 aktiv)\n• Heilt nahe Mitspieler automatisch\n• Stufe 2: stärkere Drohne",
}

## Character preview: loaded idle textures for the current role, cycled 1→2→3 on a timer.
var _preview_role: String = ""
var _preview_textures: Array = []
var _preview_stage: int = 0
var _preview_timer: float = 0.0
const PREVIEW_CYCLE_SEC: float = 1.1

func _ready() -> void:
	_is_host = multiplayer.is_server()

	# Artstyle: same background + comic button/label fonts as the main menu, then the
	# card pass — paper panels with ink text (style_labels' white-outline look is for
	# text sitting directly on the background, not inside a paper card).
	UiStyle.add_background(self)
	UiStyle.style_buttons(self)
	UiStyle.style_labels(self)
	_style_cards()

	# Quiet lobby music (continues from the menu; no restart if already playing).
	Music.play_lobby()

	# NET-01: display host IP prominently
	if _is_host:
		ip_label.text = "Your IP: %s" % Lobby.get_local_ip()
		start_btn.visible = true
		copy_btn.visible = true
		_build_room_picker()
	else:
		ip_label.text = "Connected to host"
		copy_btn.visible = false

	# Wire role buttons
	tank_btn.pressed.connect(_on_role_pressed.bind("Tank"))
	speedster_btn.pressed.connect(_on_role_pressed.bind("Speedster"))
	engineer_btn.pressed.connect(_on_role_pressed.bind("Engineer"))

	# Wire element buttons
	fire_btn.pressed.connect(_on_element_pressed.bind("Fire"))
	ice_btn.pressed.connect(_on_element_pressed.bind("Ice"))
	earth_btn.pressed.connect(_on_element_pressed.bind("Earth"))

	# Hover: preview card follows the hovered role, element card the hovered element.
	# On mouse-out both fall back to the local pick — or hide when nothing is picked,
	# so the middle column starts empty.
	for pair in [[tank_btn, "Tank"], [speedster_btn, "Speedster"], [engineer_btn, "Engineer"]]:
		pair[0].mouse_entered.connect(_show_preview.bind(pair[1]))
		pair[0].mouse_exited.connect(_refresh_preview)
	for pair in [[fire_btn, "Fire"], [ice_btn, "Ice"], [earth_btn, "Earth"]]:
		pair[0].mouse_entered.connect(_show_element_info.bind(pair[1]))
		pair[0].mouse_exited.connect(_refresh_element_info)

	ready_btn.pressed.connect(_on_ready_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	copy_btn.pressed.connect(_on_copy_pressed)
	UiStyle.wire_click_cue(self)

	# Listen to lobby changes
	Lobby.player_list_changed.connect(_refresh_ui)
	_refresh_ui()

# ------------------------------------------------------------------------------
# Comic-card styling
# ------------------------------------------------------------------------------

## Paper card behind each panel; every label inside a card flips to ink text
## (style_labels gave them the white-outline on-background treatment first).
func _style_cards() -> void:
	var cards: Array = [
		$Main/LeftPanel/IPCard, $Main/LeftPanel/RoleCard,
		$Main/LeftPanel/ElementCard, $Main/LeftPanel/StartCard,
		preview_card, element_info_card, $Main/PlayerCard,
	]
	for card in cards:
		card.add_theme_stylebox_override("panel", UiStyle.comic_box(
			Color(UiStyle.PAPER.r, UiStyle.PAPER.g, UiStyle.PAPER.b, 0.94)))
		_ink_labels(card)
	# Card headers: slightly bigger, full ink.
	for header in [
		$Main/LeftPanel/RoleCard/RoleBox/RoleLabel,
		$Main/LeftPanel/ElementCard/ElementBox/ElementLabel,
		$Main/MiddlePanel/PreviewCard/PreviewBox/PreviewLabel,
		$Main/PlayerCard/PlayerBox/PlayerListLabel,
	]:
		header.add_theme_font_size_override("font_size", 22)
	# Info bullet blocks read better a step smaller than the button font.
	element_info.add_theme_font_size_override("font_size", 15)
	role_info.add_theme_font_size_override("font_size", 15)

## Ink text + no outline for every label under `root` (paper-card treatment).
static func _ink_labels(root: Node) -> void:
	for l in root.find_children("*", "Label", true, false):
		l.add_theme_color_override("font_color", UiStyle.INK)
		l.add_theme_constant_override("outline_size", 0)

## Host-only: three room buttons + header, inserted directly under the Start button.
func _build_room_picker() -> void:
	var panel := start_btn.get_parent()
	var box := VBoxContainer.new()
	box.name = "RoomPicker"
	var header := Label.new()
	header.text = "Start-Raum:"
	box.add_child(header)
	var row := HBoxContainer.new()
	for entry in [[1, "Erba"], [2, "Altstadt"], [3, "Burg"]]:
		var b := Button.new()
		b.text = entry[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_room_pressed.bind(entry[0]))
		row.add_child(b)
		_room_buttons.append({"id": entry[0], "btn": b})
	box.add_child(row)
	panel.add_child(box)
	panel.move_child(box, start_btn.get_index() + 1)
	# Created after the _ready styling pass — restyle to match the comic buttons, then
	# ink the header (it sits inside the paper StartCard).
	UiStyle.style_buttons(box)
	UiStyle.style_labels(box)
	_ink_labels(box)
	UiStyle.wire_click_cue(box)
	_refresh_room_buttons()

func _on_room_pressed(room_id: int) -> void:
	_selected_room = room_id
	_refresh_room_buttons()

## Highlight the chosen room (yellow tint) like the role/element selection does.
func _refresh_room_buttons() -> void:
	for entry in _room_buttons:
		entry["btn"].modulate = Color(1, 1, 0.5) if entry["id"] == _selected_room else Color(1, 1, 1)

# ------------------------------------------------------------------------------
# Preview + element info cards (hover-driven, hidden when nothing to show)
# ------------------------------------------------------------------------------

## Show the preview card for `role` ("" hides it) — sprite stage cycle + ability bullets.
func _show_preview(role: String) -> void:
	preview_card.visible = role != ""
	if role == "":
		return
	role_info.text = ROLE_INFO.get(role, "")
	_load_preview_for_role(role)

## Fall back to the locally-picked role; hides the card when nothing is picked yet.
func _refresh_preview() -> void:
	var my_id: int = multiplayer.get_unique_id()
	_show_preview(Lobby.players.get(my_id, {}).get("role", ""))

## Show the element info card for `element` ("" hides it).
func _show_element_info(element: String) -> void:
	element_info_card.visible = element != ""
	if element == "":
		return
	element_info.text = ELEMENT_INFO.get(element, "")

## Fall back to the locally-picked element; hides the card when nothing is picked yet.
func _refresh_element_info() -> void:
	var my_id: int = multiplayer.get_unique_id()
	_show_element_info(Lobby.players.get(my_id, {}).get("element", ""))

## The character art canvases are uniform 256px but the drawn character fills 50–95% of
## them depending on stage (tank_2 uses only 90×128 of its canvas) — showing the raw
## textures made stage 2 read as a shrink. Crop each stage to its opaque bounding box,
## then re-pad so the character fills this fraction of the preview box: mild growth
## 1 → 2 → 3, mirroring the in-game evolution read.
const PREVIEW_STAGE_FRACTION := {1: 0.80, 2: 0.92, 3: 1.0}

## Load the three idle stages for a role into the preview and restart the cycle.
func _load_preview_for_role(role: String) -> void:
	var key: String = ROLE_SPRITE_KEY.get(role, "")
	if key == "":
		return
	if role == _preview_role and _preview_textures.size() == 3:
		return
	_preview_role = role
	_preview_textures = []
	for stage in [1, 2, 3]:
		var path := "%s%s_%d_idle.png" % [PLAYER_SPRITE_DIR, key, stage]
		if ResourceLoader.exists(path):
			_preview_textures.append(_cropped_preview(load(path), stage))
	_preview_stage = 0
	_preview_timer = 0.0
	_update_preview_frame()

## Crop `tex` to its opaque pixels via AtlasTexture, then add back a symmetric margin so
## the content occupies PREVIEW_STAGE_FRACTION of the final frame. Falls back to the raw
## texture when the image data isn't readable.
func _cropped_preview(tex: Texture2D, stage: int) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(used)
	var frac: float = PREVIEW_STAGE_FRACTION.get(stage, 1.0)
	var extra := Vector2(used.size) * (1.0 / frac - 1.0)
	at.margin = Rect2(extra * 0.5, extra)
	return at

func _update_preview_frame() -> void:
	if _preview_textures.is_empty():
		return
	_preview_stage = _preview_stage % _preview_textures.size()
	preview_image.texture = _preview_textures[_preview_stage]
	preview_stage_label.text = "Stufe %d" % (_preview_stage + 1)

func _process(delta: float) -> void:
	# Idle stage cycle: 1 → 2 → 3 → 1 … so the preview shows how the pick evolves.
	if not preview_card.visible or _preview_textures.size() <= 1:
		return
	_preview_timer += delta
	if _preview_timer >= PREVIEW_CYCLE_SEC:
		_preview_timer = 0.0
		_preview_stage = (_preview_stage + 1) % _preview_textures.size()
		_update_preview_frame()

# ------------------------------------------------------------------------------
# Selection + ready flow
# ------------------------------------------------------------------------------

func _on_role_pressed(role: String) -> void:
	if _is_ready:
		return  # D-02: locked when ready
	# Check if role is taken by someone else
	var my_id: int = multiplayer.get_unique_id()
	for id in Lobby.players:
		if id != my_id and Lobby.players[id].get("role", "") == role:
			return  # D-08: taken, do nothing
	Lobby.set_player_role.rpc(role)

func _on_element_pressed(element: String) -> void:
	if _is_ready:
		return  # D-02: locked when ready
	Lobby.set_player_element.rpc(element)

func _on_ready_pressed() -> void:
	_is_ready = !_is_ready
	Lobby.set_player_ready.rpc(_is_ready)
	ready_btn.text = "Un-Ready" if _is_ready else "Ready"
	_set_picks_disabled(_is_ready)

func _on_copy_pressed() -> void:
	var ip: String = Lobby.get_local_ip()
	DisplayServer.clipboard_set(ip)
	var original_text: String = copy_btn.text
	copy_btn.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_btn.text = original_text

func _on_start_pressed() -> void:
	if not _is_host:
		return
	if not Lobby.all_players_ready():
		status_label.text = "Waiting for all players to ready up..."
		return
	Lobby.start_game.rpc(_selected_room)

func _set_picks_disabled(disabled: bool) -> void:
	# D-02: lock/unlock role and element buttons
	var my_id: int = multiplayer.get_unique_id()
	var role_map: Dictionary = {"Tank": tank_btn, "Speedster": speedster_btn, "Engineer": engineer_btn}
	for role in role_map:
		var btn: Button = role_map[role]
		var taken_by_other: bool = false
		for id in Lobby.players:
			if id != my_id and Lobby.players[id].get("role", "") == role:
				taken_by_other = true
				break
		if not taken_by_other:
			btn.disabled = disabled
	for btn in [fire_btn, ice_btn, earth_btn]:
		btn.disabled = disabled

func _refresh_ui() -> void:
	var my_id: int = multiplayer.get_unique_id()
	var my_data: Dictionary = Lobby.players.get(my_id, {})
	var my_role: String = my_data.get("role", "")

	# Preview / element cards follow the local pick (stay hidden until one exists).
	_refresh_preview()
	_refresh_element_info()

	# Update role buttons — D-08: taken by others = grayed + "Taken"
	var role_map: Dictionary = {
		"Tank": tank_btn,
		"Speedster": speedster_btn,
		"Engineer": engineer_btn
	}
	for role in role_map:
		var btn: Button = role_map[role]
		var taken_by_other: bool = false
		for id in Lobby.players:
			if id != my_id and Lobby.players[id].get("role", "") == role:
				taken_by_other = true
				break
		if taken_by_other:
			btn.text = "Taken"
			btn.disabled = true
		else:
			btn.text = role
			if not _is_ready:
				btn.disabled = false
		# Highlight current selection
		btn.modulate = Color(1, 1, 0.5) if my_role == role else Color(1, 1, 1)

	# Update element buttons — highlight selection
	var element_map: Dictionary = {
		"Fire": fire_btn, "Ice": ice_btn, "Earth": earth_btn
	}
	var my_element: String = my_data.get("element", "")
	for elem in element_map:
		var btn: Button = element_map[elem]
		btn.modulate = Color(1, 1, 0.5) if my_element == elem else Color(1, 1, 1)

	# Update Start button (host only) — D-01: only when all ready
	if _is_host:
		start_btn.disabled = not Lobby.all_players_ready()
		status_label.text = "All ready!" if Lobby.all_players_ready() else ""

	# Rebuild player list panel — D-09
	for child in player_list.get_children():
		child.queue_free()
	for id in Lobby.players:
		var data: Dictionary = Lobby.players[id]
		var role_str: String = data.get("role", "Player")  # D-06: "Player" placeholder
		var elem_str: String = data.get("element", "—")
		var ready_str: String = "✓" if data.get("ready", false) else "·"
		var row: Label = Label.new()
		# Show role + element + starting bot level (everyone begins as a Stage-1 bot).
		row.text = "%s  •  %s  •  Bot Lv.1  %s" % [role_str, elem_str, ready_str]
		UiStyle.style_label(row)
		# Rows live inside the paper PlayerCard — ink text, one step smaller.
		row.add_theme_color_override("font_color", UiStyle.INK)
		row.add_theme_constant_override("outline_size", 0)
		row.add_theme_font_size_override("font_size", 17)
		player_list.add_child(row)
