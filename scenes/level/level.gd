tool extends Node2D

export (Vector2) var tutorial_spawn_pos1 = Vector2(40, 40)
export (Vector2) var tutorial_spawn_pos2 = Vector2(184, 136)

export (Globals.Level) var type
export (int) var world = 0

const unit_scene = preload("res://scenes/unit/unit.tscn")
const blast_scene = preload("res://scenes/explosion/blast.tscn")
const explosion_scene = preload("res://scenes/explosion/explosion.tscn")
const message_scene = preload("res://scenes/message/message.tscn")
const portal_scene = preload("res://scenes/portal/portal.tscn")
const gun_scene = preload("res://scenes/gun/gun.tscn")

const bg_colors = [Color("390947"), Color("09471a")]

const player_data = preload("res://resources/units/player.tres")

var fighting = false
var rounds_left = 1
const type_to_rounds_left = { Globals.Level.FIGHT: 3, Globals.Level.BOSS: 1 }

var size = Vector2(224, 176)

var enemy_order = ["ai_red", "ai_green", "ai_pink", "boss"]
var level_ind = 0
var current_enemy_type = enemy_order[level_ind]

var waves_per_level = 3
var current_wave = 0

const unit_data = {
	"ai_grey": preload("res://resources/units/ai_grey.tres"),
	"ai_red": preload("res://resources/units/ai_red.tres"),
	"ai_green": preload("res://resources/units/ai_green.tres"),
	"ai_pink": preload("res://resources/units/ai_pink.tres"),
	"boss": preload("res://resources/levels/BOSS/0/saw.tres")
}

onready var player = get_node_or_null("Player")
var reset = false
var portal_spawned = false

func _ready() -> void:
	Globals.tutorial_mode = true
	Signals.connect("spawn", self, "spawn")
	Signals.connect("spawn_unit", self, "spawn_unit")
	Signals.connect("blast", self, "blast")
	Signals.connect("explode", self, "explode")
	Signals.connect("message", self, "message")
	Signals.connect("wipe_on_completed", self, "on_wipe_on_completed")
	Signals.connect("world_ui_completed", self, "load_level")
	Signals.connect("player_died", self, "on_player_died")
	Signals.connect("game_won", self, "on_player_died")
	
	Signals.emit_signal("world_changed", world)
	reset_level(true)

func _process(delta):
	if fighting and not portal_spawned:
		var enemy_exists = false
		for unit in $Units.get_children():
			if not unit.data.player:
				enemy_exists = true
				break
		if not enemy_exists:
			yield(get_tree().create_timer(0.05), "timeout")
			enemy_exists = false
			for unit in $Units.get_children():
				if not unit.data.player:
					enemy_exists = true
					break
			if not enemy_exists:
				if Globals.tutorial_mode:
					portal_spawned = true
					spawn_portal()
				else:
					if current_wave < waves_per_level - 1:
						current_wave += 1
						spawn_wave()
					else:
						portal_spawned = true
						spawn_portal()

func on_player_died(gpos):
	reset = true
	Signals.emit_signal("wipe_on", gpos, 1)

func on_wipe_on_completed():
	for unit in $Units.get_children():
		unit.queue_free()
	for spawn in $Spawns.get_children():
		spawn.queue_free()

func spawn(node):
	var pos = node.position
	$Spawns.add_child(node)
	node.global_position = pos

func spawn_unit(gpos, udata):
	var unit = unit_scene.instance()
	unit.data = udata
	unit.position = gpos - $Units.global_position
	unit.start_delay = 0.5
	yield(get_tree(), "idle_frame")
	$Units.add_child(unit)

func blast(gpos, dir):
	var blast = blast_scene.instance()
	$Spawns.add_child(blast)
	blast.global_position = gpos
	blast.direction = dir

func explode(gpos):
	var explosion = explosion_scene.instance()
	$Spawns.add_child(explosion)
	explosion.global_position = gpos

func message(gpos, text, color):
	var msg = message_scene.instance()
	msg.position = gpos
	msg.text = text
	msg.color = color
	spawn(msg)

func reset_level(to_start=true):
	reset = false
	fighting = false
	portal_spawned = false
	current_wave = 0
	
	var new_data = {}
	for key in unit_data.keys():
		new_data[key] = unit_data[key].duplicate(true)
	Globals.unit_data = new_data
	
	if to_start:
		if Globals.tutorial_mode:
			$BG/TutorialIcons.visible = true
		else:
			$BG/TutorialIcons.visible = false
			level_ind = 0
			current_enemy_type = enemy_order[level_ind]
			type = Globals.Level.FIGHT
			waves_per_level = 3
		for child in $Spawns.get_children():
			child.queue_free()
		for child in $Units.get_children():
			child.queue_free()
	
	if player and is_instance_valid(player):
		player.queue_free()
	player = unit_scene.instance()
	player.data = player_data.duplicate()
	player.position = size / 2
	add_child(player)
	var gun = gun_scene.instance()
	player.add_child(gun)
	player.drop_in(1.0)
	
	Signals.emit_signal("wipe_off", Vector2(320,240)/2, 0)
	yield(Signals, "wipe_off_completed")
	
	if Globals.tutorial_mode:
		Signals.emit_signal("play_music", "tut")
		spawn_tutorial_wave()
	else:
		Signals.emit_signal("play_music", "fight")
		spawn_wave()
		
	yield(get_tree(), "idle_frame")
	fighting = true

func load_level():
	if Globals.tutorial_mode:
		Globals.tutorial_mode = false
		reset_level(true)
	else:
		update_level_type()

func spawn_tutorial_wave():
	spawn_unit(tutorial_spawn_pos1, Globals.unit_data["ai_grey"].duplicate(true))
	spawn_unit(tutorial_spawn_pos2, Globals.unit_data["ai_grey"].duplicate(true))
	for unit in $Units.get_children():
		if not unit.data.player:
			unit.data.dashes = false
			unit.data.saws = false
			unit.data.magic = false
			unit.speed = 0

func spawn_wave():
	if current_enemy_type == "boss":
		# Instancier le boss directement dans la scène en cours
		var boss_scene = preload("res://scenes/boss/boss_saw.tscn")
		var boss_instance = boss_scene.instance()
		boss_instance.position = size / 2
		add_child(boss_instance)
		return
	var num_enemies = current_wave + 2
	var margin = 50
	for i in range(num_enemies):
		var pos = Vector2(rand_range(margin, size.x - margin), rand_range(margin, size.y - margin))
		spawn_unit(pos, Globals.unit_data[current_enemy_type].duplicate(true))

func update_level_type():
	level_ind += 1
	if level_ind >= enemy_order.size():
		win_game()
		return
	current_enemy_type = enemy_order[level_ind]
	if current_enemy_type == "boss":
		type = Globals.Level.BOSS
		waves_per_level = 1
		Signals.emit_signal("update_level_ui", "Boss")
	else:
		type = Globals.Level.FIGHT
		waves_per_level = 3
		Signals.emit_signal("update_level_ui", str(level_ind + 1))
	current_wave = 0
	Signals.emit_signal("update_enemy_icon", current_enemy_type)
	reset_level(false)

func spawn_portal():
	var portal = portal_scene.instance()
	if current_enemy_type == "boss":
		portal.custom_text = "Boss Fight!"
	else:
		portal.custom_text = "Next Level"
	$Spawns.add_child(portal)
	portal.position = Vector2(size.x / 2, size.y / 2)
	portal.connect("portal_entered", self, "on_portal_entered")

func spawn_custom_portal(text):
	var portal = portal_scene.instance()
	portal.custom = true
	portal.custom_text = text
	var ind = world % len(Globals.world_to_color)
	portal.custom_color = Globals.world_to_color[ind]
	$Spawns.add_child(portal)
	portal.position = size / 2
	portal.connect("portal_entered", self, "on_portal_entered")
	return portal

func on_portal_entered():
	portal_spawned = false
	load_level()

func win_game():
	Signals.emit_signal("stop_music", true)
	yield(get_tree(), "idle_frame")
	yield(get_tree().create_timer(1), "timeout")
	Signals.emit_signal("message", Vector2(160,120), "Victory!", Globals.green)
	yield(get_tree().create_timer(2), "timeout")
	get_tree().change_scene("res://scenes/tutorial.tscn")

