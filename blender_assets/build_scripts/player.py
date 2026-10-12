exec(open(LIB).read())

# Third-person player character: a student in a hoodie, built from the same flat-shaded, outlined toon boxes as the level.
# Facing +Y in Blender (-> -Z in Godot, the engine's "forward"), feet on z=0, ~1.8 m tall.
# The body is split into rigid parts hung on pivot empties (Pv_*) so Godot can animate them (walk cycle) without a skeleton.

# ---- remove previous build ----
old = bpy.data.collections.get("Player")
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o)
    bpy.data.collections.remove(old)
bpy.data.orphans_purge(do_recursive=True)

pc = bpy.data.collections.new("Player")
bpy.context.scene.collection.children.link(pc)
def get_coll():
    return pc

SKIN = ("Skin", (0.96, 0.76, 0.62))
HAIR = ("Hair", (0.24, 0.15, 0.1))
EYE = ("Eye", (0.1, 0.1, 0.14))
HOODIE = ("Hoodie", (0.9, 0.35, 0.25))
HOODIE_DK = ("HoodieDark", (0.68, 0.23, 0.2))
STRING = ("Drawstring", (0.95, 0.93, 0.88))
JEANS = ("Jeans", (0.22, 0.32, 0.56))
SHOE = ("ShoeWhite", (0.95, 0.95, 0.97))
SOLE = ("ShoeSole", (0.6, 0.62, 0.7))

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
    ob.parent = parent          # identity parent inverse: ob.location is local to the pivot

hips = pivot("Pv_Hips", root, (0, 0, HIPS_Z))
head_pv = pivot("Pv_Head", hips, (0, 0, 0.55))
arm_pv = {s: pivot("Pv_Arm" + n, hips, (s * 0.265, 0, 0.47)) for s, n in ((1, "R"), (-1, "L"))}
leg_pv = {s: pivot("Pv_Leg" + n, hips, (s * 0.085, 0, 0.0)) for s, n in ((1, "R"), (-1, "L"))}

# ---- torso: the hoodie (slim) ----
b = B()
b.box((0.4, 0.24, 0.58), (0, 0, 0.25), HOODIE)                 # body
b.box((0.42, 0.26, 0.07), (0, 0, -0.04), HOODIE_DK)            # ribbed hem
b.box((0.27, 0.03, 0.14), (0, 0.125, 0.08), HOODIE_DK)         # kangaroo pocket
b.box((0.27, 0.16, 0.18), (0, -0.16, 0.5), HOODIE_DK, rot=(-20, 0, 0))   # hood hanging on the back
b.box((0.29, 0.21, 0.07), (0, 0.0, 0.57), HOODIE_DK)           # hood collar
b.box((0.025, 0.02, 0.16), (-0.055, 0.13, 0.42), STRING)       # drawstrings
b.box((0.025, 0.02, 0.16), (0.055, 0.13, 0.42), STRING)
torso = b.finish("P_Torso", (0, 0, 0))
attach(torso, hips)

# ---- head ----
b = B()
b.box((0.31, 0.28, 0.31), (0, 0, 0.155), SKIN)                 # head
b.box((0.33, 0.3, 0.09), (0, -0.005, 0.335), HAIR)             # hair cap
b.box((0.33, 0.05, 0.22), (0, -0.14, 0.22), HAIR)              # back of the hair
b.box((0.34, 0.04, 0.09), (0, 0.15, 0.3), HAIR, rot=(8, 0, 0))   # fringe
b.box((0.035, 0.2, 0.17), (-0.165, -0.025, 0.24), HAIR)        # sideburns
b.box((0.035, 0.2, 0.17), (0.165, -0.025, 0.24), HAIR)
b.box((0.05, 0.02, 0.07), (-0.075, 0.142, 0.17), EYE)          # eyes
b.box((0.05, 0.02, 0.07), (0.075, 0.142, 0.17), EYE)
b.box((0.035, 0.04, 0.05), (0, 0.15, 0.12), SKIN)              # nose
b.box((0.05, 0.02, 0.02), (0, 0.142, 0.06), EYE)               # mouth
head = b.finish("P_Head", (0, 0, 0))
attach(head, head_pv)

# ---- arms (hoodie sleeve, ribbed cuff, hand) ----
for s, n in ((1, "R"), (-1, "L")):
    b = B()
    b.box((0.115, 0.115, 0.2), (0, 0, -0.04), HOODIE)           # shoulder / upper sleeve
    b.box((0.105, 0.105, 0.22), (0, 0, -0.21), HOODIE)          # forearm sleeve
    b.box((0.115, 0.115, 0.04), (0, 0, -0.33), HOODIE_DK)       # cuff
    b.box((0.08, 0.08, 0.1), (0, 0, -0.4), SKIN)                # hand
    arm = b.finish("P_Arm" + n, (0, 0, 0))
    attach(arm, arm_pv[s])

# ---- legs (jeans + white sneakers) ----
for s, n in ((1, "R"), (-1, "L")):
    b = B()
    b.box((0.14, 0.16, 0.68), (0, 0, -0.3), JEANS)              # trouser leg
    b.box((0.15, 0.17, 0.04), (0, 0, -0.58), JEANS)             # turned-up hem
    b.box((0.14, 0.27, 0.11), (0, 0.04, -0.68), SHOE)           # sneaker
    b.box((0.15, 0.28, 0.03), (0, 0.04, -0.735), SOLE)          # sole
    leg = b.finish("P_Leg" + n, (0, 0, 0))
    attach(leg, leg_pv[s])

bpy.context.view_layer.update()
