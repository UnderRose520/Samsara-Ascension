class_name GameConstants

const DODGE_DISTANCE := 150.0
const DODGE_IFRAME := 0.25
const DODGE_COOLDOWN := 1.0
const PROJECTILE_SPEED := 300.0
const ATTACK_INTERVAL := 0.35
const PLAYER_ATTACK := 32.0
const ENEMY_HP := 70.0
const ENEMY_BOSS_HP := 160.0
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
const ENEMY_SPAWN_RING := 150.0
const ENEMY_BOSS_SPAWN := Vector2(0, -55)
const COMBO_BREAK_SEC := 2.0
const BUCKET_DECAY := [1.0, 0.8, 0.6]

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

const COMBO_MILESTONES := [10, 30, 50, 100]
