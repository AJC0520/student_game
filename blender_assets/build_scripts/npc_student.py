exec(open(LIB).read())

# The fellow student who opens the A4 door (door minigame): same boxy toon style and rig as the player
# (Pv_* pivots, P_* parts, so scripts/player_model.gd animates him unchanged), but dressed differently:
# olive bomber jacket over a white tee, black jeans, white sneakers, orange beanie, backpack and a lanyard with his card.
# Facing +Y in Blender (-> -Z in Godot), feet on z=0. Exported to assets/npc_student.glb.
# The player's objects use the same names, so they are renamed out of the way while this runs and restored at the end.

held = []
pl = bpy.data.collections.get("Player")
if pl:
    for o in pl.objects:
        held.append((o, o.name))
        o.name = o.name + "~hold"

old = bpy.data.collections.get("NpcStudent")
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o)
    bpy.data.collections.remove(old)
bpy.data.orphans_purge(do_recursive=True)

pc = bpy.data.collections.new("NpcStudent")
bpy.context.scene.collection.children.link(pc)
def get_coll():
    return pc

SKIN = ("SkinTan", (0.88, 0.67, 0.52))
HAIR = ("HairDark", (0.16, 0.14, 0.17))
EYE = ("Eye", (0.1, 0.1, 0.14))
JACKET = ("Bomber", (0.32, 0.50, 0.34))
JACKET_DK = ("BomberDark", (0.20, 0.34, 0.24))
TEE = ("Shirt", (0.95, 0.95, 0.93))
PRINT = ("Yellow", (1.0, 0.82, 0.25))
JEANS = ("JeansBlack", (0.15, 0.15, 0.19))
SHOE = ("ShoeWhite", (0.95, 0.95, 0.97))
SOLE = ("ShoeSole", (0.6, 0.62, 0.7))
BEANIE = ("Beanie", (0.88, 0.5, 0.2))
BAG = ("Backpack", (0.25, 0.32, 0.58))
LANYARD = ("Lanyard", (0.2, 0.62, 0.64))
CARD = ("SignWhite", (0.95, 0.95, 0.95))

HIPS_Z = 0.75
root = bpy.data.objects.new("Player_Model", None)
pc.objects.link(root)

def pivot(name, parent, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.08
    pc.objects.link(e)
    e.parent = parent
    e.location = loc
    return e

def attach(ob, parent):
    ob.parent = parent

hips = pivot("Pv_Hips", root, (0, 0, HIPS_Z))
head_pv = pivot("Pv_Head", hips, (0, 0, 0.55))
arm_pv = {s: pivot("Pv_Arm" + n, hips, (s * 0.265, 0, 0.47)) for s, n in ((1, "R"), (-1, "L"))}
leg_pv = {s: pivot("Pv_Leg" + n, hips, (s * 0.085, 0, 0.0)) for s, n in ((1, "R"), (-1, "L"))}

# ---- torso: olive bomber jacket over a white tee with a yellow print, backpack, lanyard + card ----
b = B()
b.box((0.4, 0.24, 0.58), (0, 0, 0.25), JACKET)                     # jacket
b.box((0.42, 0.26, 0.07), (0, 0, -0.04), JACKET_DK)                # ribbed hem
b.box((0.16, 0.02, 0.52), (0, 0.125, 0.29), TEE)                   # tee showing through the open jacket
b.box((0.09, 0.022, 0.07), (0, 0.133, 0.3), PRINT)                 # tee print
b.box((0.06, 0.03, 0.5), (-0.1, 0.13, 0.28), JACKET_DK)            # jacket front edges
b.box((0.06, 0.03, 0.5), (0.1, 0.13, 0.28), JACKET_DK)
b.box((0.3, 0.2, 0.06), (0, 0, 0.56), JACKET_DK)                   # collar
b.box((0.025, 0.02, 0.38), (-0.07, 0.14, 0.33), LANYARD, rot=(0, 0, 14))   # lanyard strap
b.box((0.025, 0.02, 0.38), (0.07, 0.14, 0.33), LANYARD, rot=(0, 0, -14))
b.box((0.085, 0.015, 0.12), (0.0, 0.145, 0.07), CARD)              # the card
b.box((0.085, 0.017, 0.03), (0.0, 0.147, 0.1), LANYARD)
b.box((0.34, 0.14, 0.44), (0, -0.19, 0.27), BAG)                   # backpack
b.box((0.34, 0.03, 0.2), (0, -0.265, 0.17), JACKET_DK)             # front pocket of the bag
for sx in (-0.13, 0.13):
    b.box((0.05, 0.27, 0.05), (sx, -0.02, 0.5), BAG)               # shoulder straps over the shoulders
torso = b.finish("P_Torso", (0, 0, 0))
attach(torso, hips)

# ---- head: beanie, brown fringe poking out, friendly face ----
b = B()
b.box((0.31, 0.28, 0.3), (0, 0, 0.15), SKIN)
b.box((0.34, 0.31, 0.12), (0, -0.005, 0.34), BEANIE)               # beanie
b.box((0.34, 0.31, 0.04), (0, -0.005, 0.28), BEANIE)
b.box((0.33, 0.05, 0.14), (0, -0.14, 0.2), HAIR)                   # hair at the back
b.box((0.3, 0.04, 0.05), (0, 0.15, 0.27), HAIR, rot=(6, 0, 0))     # fringe under the beanie
b.box((0.035, 0.2, 0.12), (-0.165, -0.025, 0.2), HAIR)
b.box((0.035, 0.2, 0.12), (0.165, -0.025, 0.2), HAIR)
for ex in (-0.075, 0.075):
    b.box((0.045, 0.02, 0.055), (ex, 0.142, 0.17), EYE)            # eyes
    b.box((0.065, 0.02, 0.015), (ex, 0.145, 0.225), HAIR)          # eyebrows
b.box((0.03, 0.05, 0.05), (0, 0.15, 0.12), SKIN)                   # nose
b.box((0.07, 0.02, 0.015), (0, 0.142, 0.06), EYE)                  # mouth
head = b.finish("P_Head", (0, 0, 0))
attach(head, head_pv)

# ---- arms: jacket sleeves with ribbed cuffs ----
for s, n in ((1, "R"), (-1, "L")):
    b = B()
    b.box((0.115, 0.115, 0.2), (0, 0, -0.04), JACKET)
    b.box((0.105, 0.105, 0.22), (0, 0, -0.21), JACKET)
    b.box((0.115, 0.115, 0.04), (0, 0, -0.325), JACKET_DK)
    b.box((0.08, 0.08, 0.1), (0, 0, -0.4), SKIN)
    arm = b.finish("P_Arm" + n, (0, 0, 0))
    attach(arm, arm_pv[s])

# ---- legs: black jeans + white sneakers ----
for s, n in ((1, "R"), (-1, "L")):
    b = B()
    b.box((0.14, 0.16, 0.68), (0, 0, -0.3), JEANS)
    b.box((0.14, 0.27, 0.11), (0, 0.04, -0.68), SHOE)
    b.box((0.15, 0.28, 0.03), (0, 0.04, -0.735), SOLE)
    leg = b.finish("P_Leg" + n, (0, 0, 0))
    attach(leg, leg_pv[s])

bpy.context.view_layer.update()
npc_objects = list(pc.objects)

# export, then give the player's objects their names back
bpy.ops.object.select_all(action='DESELECT')
for o in npc_objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=r"C:\Users\asgei\Desktop\student_game\godot_project\assets\npc_student.glb", export_format='GLB',
    use_selection=True, export_apply=True, export_yup=True, export_materials='EXPORT',
    export_cameras=False, export_lights=False)
for o in npc_objects:        # free the plain names (the glb already has them), then restore the player's
    o.name = "NPC_" + o.name
for o, n in held:
    o.name = n
