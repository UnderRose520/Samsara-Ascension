class_name GameConstants

const DODGE_DISTANCE := 200.0
const DODGE_DURATION := 0.10
const DODGE_IFRAME := 0.16
const HIT_INVULN := 0.45
const DODGE_COOLDOWN := 1.0

## 与 combat_floor 背景一致（1280×720，左上 -640,-360）
const ARENA_HALF_WIDTH := 640.0
const ARENA_HALF_HEIGHT := 360.0

## 碰撞层：1=障碍/地形池，16=场地围墙
const COLLISION_LAYER_OBSTACLE := 1
const COLLISION_LAYER_WALL := 16
const COLLISION_MASK_ARENA := COLLISION_LAYER_WALL | COLLISION_LAYER_OBSTACLE

## 积水地形：可通行，移速倍率与出水后恢复时间
const TERRAIN_WET_SLOW_MULT := 0.62
const TERRAIN_WET_RECOVERY_SEC := 1.4
const TERRAIN_WATER_SLOW_REFRESH_SEC := 0.28
const TERRAIN_SWAMP_ROOT_SEC := 1.15
const TERRAIN_SWAMP_RETRIGGER_SEC := 3.2
const TERRAIN_FIRE_DAMAGE_PER_SEC := 7.0
const TERRAIN_FIRE_TICK_SEC := 0.45
const PROJECTILE_SPEED := 300.0
const ATTACK_INTERVAL := 0.38
const PLAYER_ATTACK := 18.0
const ENEMY_HP := 95.0
const ENEMY_BOSS_HP := 220.0
const MAX_ROOM_ENEMIES := 14
const ENEMY_MOVE_SPEED := 130.0
const ENEMY_BOSS_MOVE_SPEED := 105.0
const ENEMY_AGGRO_RANGE := 560.0
const ENEMY_CONTACT_RANGE := 38.0
const ENEMY_ATTACK_WINDUP := 0.42
const ENEMY_ATTACK_WINDUP_ELITE := 0.32
const ENEMY_ATTACK_WINDUP_BOSS := 0.55
const ENEMY_ATTACK_START_RANGE := 48.0
const ENEMY_ORBIT_RADIUS := 52.0
const ENEMY_ORBIT_RADIUS_BOSS := 36.0
const ENEMY_ORBIT_SPREAD := 10.0
const ENEMY_ARRIVAL_THRESHOLD := 18.0
const ENEMY_SEPARATION_RADIUS := 32.0
const ENEMY_SPAWN_CENTER := Vector2(0, -100)
const ENEMY_SPAWN_RING := 165.0
const ENEMY_SPAWN_RING_EXTRA := 22.0
const ENEMY_BOSS_SPAWN := Vector2(0, -55)
const COMBO_BREAK_SEC := 2.0
const BUCKET_DECAY := [1.0, 0.8, 0.6]

## 索敌评分参数见 data/combat/targeting_config.csv（TargetingConfig）

const AFFIX_REROLL_COST := 50
const AFFIX_SKIP_REWARD := 30
const STARTING_GOLD := 50

const SHOP_AFFIX_COST := 80
const SHOP_HEAL_COST := 40
const SHOP_RARE_COST := 120

const COLOR_BG := Color("#0d0d0d")
const COLOR_ARENA := Color("#1a1a2e")
const COLOR_PLAYER := Color("#4ecdc4")
const COLOR_ENEMY := Color("#ef4444")
const COLOR_PROJECTILE := Color("#ffd700")
const COLOR_UI := Color("#f0ece4")

const QUALITY_COLORS := {
	0: Color("#b0b0b0"),
	1: Color("#4e9af1"),
	2: Color("#a855f7"),
	3: Color("#f59e0b"),
	4: Color("#ef4444"),
}

const COMBO_MILESTONES := [10, 30, 60, 100]

static var current_arena_bounds := {
	"x": -640.0,
	"y": -352.0,
	"width": 1280.0,
	"height": 704.0,
}


static func clamp_to_arena(pos: Vector2, body_radius: float = 12.0) -> Vector2:
	var margin := body_radius + 2.0
	var min_x := float(current_arena_bounds.get("x", -ARENA_HALF_WIDTH)) + margin
	var min_y := float(current_arena_bounds.get("y", -ARENA_HALF_HEIGHT)) + margin
	var max_x := min_x + float(current_arena_bounds.get("width", ARENA_HALF_WIDTH * 2.0)) - margin * 2.0
	var max_y := min_y + float(current_arena_bounds.get("height", ARENA_HALF_HEIGHT * 2.0)) - margin * 2.0
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))


static func set_arena_bounds(bounds: Dictionary) -> void:
	current_arena_bounds = {
		"x": float(bounds.get("x", -ARENA_HALF_WIDTH)),
		"y": float(bounds.get("y", -ARENA_HALF_HEIGHT)),
		"width": float(bounds.get("width", ARENA_HALF_WIDTH * 2.0)),
		"height": float(bounds.get("height", ARENA_HALF_HEIGHT * 2.0)),
	}


static func reset_arena_bounds() -> void:
	set_arena_bounds({"x": -640.0, "y": -352.0, "width": 1280.0, "height": 704.0})
