extends Node
## Start settings for testing: where the player spawns and whether the lift intro plays.
## Select the "GameStart" node in scenes/main.tscn and change the two properties in the inspector, no code needed.
## This node sits before the Player in the scene so it runs first (the Player reads its start rotation in its own _ready).

enum Spawn {
	LIFT,          ## inside lift 1, facing the doors
	HALL,          ## the lobby outside the lift, facing the locked glass door and card reader
	CORRIDOR,      ## the corridor with the group rooms, just behind the locked door
	BIG_ROOM,      ## the big study hall at the west end of the corridor
	ONLINE_ROOM,   ## the Online committee room
	CUSTOM,        ## use custom_position / custom_facing_degrees below
}

## Where the player starts.
@export var spawn: Spawn = Spawn.ONLINE_ROOM
## Play the lift ride at the start (doors closed, floors counting up, then the doors open).
## Only has an effect when spawn is LIFT; from any other spawn the lift just stays open.
@export var play_lift_intro: bool = true

@export_group("Custom spawn")
## Godot coordinates (Blender x, y, z -> Godot x, z, -y). Used when spawn is CUSTOM.
@export var custom_position: Vector3 = Vector3(0.0, 0.05, 0.0)
## Facing as a yaw angle in degrees: 0 = looking along -Z (north in the Blender plan), 90 = -X (west), -90 = +X (east), 180 = +Z.
@export_range(-180.0, 180.0, 1.0) var custom_facing_degrees: float = 0.0

@export_group("Paths")
@export var player_path: NodePath = ^"../Player"
@export var elevator_path: NodePath = ^"../Elevator"

## spawn -> [position, facing in degrees]
const POINTS := {
	Spawn.LIFT: [Vector3(0.75, 0.05, -1.8), 180.0],
	Spawn.HALL: [Vector3(1.2, 0.05, 1.9), 90.0],
	Spawn.CORRIDOR: [Vector3(-3.0, 0.05, 1.25), 90.0],
	Spawn.BIG_ROOM: [Vector3(-27.5, 0.05, 6.0), -90.0],
	Spawn.ONLINE_ROOM: [Vector3(-14.0, 0.05, -2.2), 90.0],
}


func _ready() -> void:
	var player := get_node_or_null(player_path) as Node3D
	var lift := get_node_or_null(elevator_path)
	if player:
		var pos := custom_position
		var facing := custom_facing_degrees
		if spawn != Spawn.CUSTOM:
			pos = POINTS[spawn][0]
			facing = POINTS[spawn][1]
		player.position = pos
		player.rotation = Vector3(0.0, deg_to_rad(facing), 0.0)
	if lift:
		lift.set("play_intro", play_lift_intro and spawn == Spawn.LIFT)
