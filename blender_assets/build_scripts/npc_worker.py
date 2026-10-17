exec(open(LIB).read())

# A student working at the group table next to the big west window: black hoodie, jeans, white sneakers, a headset,
# curly blond hair. He sits on the west-side chair of the table that is on the left when you walk in from the corridor, faces the corridor (east),
# types on a laptop and now and then takes a sip from a mug. Includes the props on the table (laptop, A4 papers,
# a coffee can) and the mug as its own object so Godot can pick it up.
# Rig: rigid parts hung on pivot empties (Dw_*), animated procedurally by scripts/desk_worker.gd.
# Built in a local frame (+Y forward, +X his right, origin on the seat), placed with a z-rotation at the end.
# Style note: the character is a stylized game figure with the same boxy look as the others.

old = bpy.data.collections.get("NpcWorker")
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o)
    bpy.data.collections.remove(old)
bpy.data.orphans_purge(do_recursive=True)

wc = bpy.data.collections.new("NpcWorker")
bpy.context.scene.collection.children.link(wc)
def get_coll():
    return wc

SKIN = ("SkinLight", (0.98, 0.82, 0.72))
HAIR = ("HairBlond", (0.93, 0.80, 0.50))
HAIR_DK = ("HairBlondDark", (0.80, 0.64, 0.34))
EYE = ("EyeBlue", (0.35, 0.55, 0.75))
BROW = ("HairBlondDark", (0.80, 0.64, 0.34))
SHIRT = ("HoodieBlack", (0.10, 0.10, 0.12))
SHIRT_SH = ("HoodieBlackDark", (0.06, 0.06, 0.08))
STRINGW = ("Drawstring", (0.95, 0.93, 0.88))
PANTS = ("Jeans", (0.22, 0.32, 0.56))
SHOE = ("ShoeWhite", (0.95, 0.95, 0.97))
HSET = ("HeadsetBlack", (0.12, 0.12, 0.15))
HSET_R = ("HeadsetRing", (0.90, 0.25, 0.30))
SOLE = ("ShoeSole", (0.6, 0.62, 0.7))
TEETH = ("SignWhite", (0.95, 0.95, 0.95))
MOUTH = ("Eye", (0.1, 0.1, 0.14))

V = Vector
b = B()

def gbox(G, size, loc, mat, rot=(0, 0, 0)):
    M = G @ Matrix.Translation(loc) @ Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
    r = bmesh.ops.create_cube(b.bm, size=1.0, matrix=M)
    return b._tag(r['verts'], mat)

def seg(p0, p1, w, d, mat):
    p0, p1 = V(p0), V(p1)
    axis = p1 - p0
    R = V((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    M = Matrix.Translation((p0 + p1) / 2) @ R @ Matrix.Diagonal((w, d, axis.length, 1))
    r = bmesh.ops.create_cube(b.bm, size=1.0, matrix=M)
    return b._tag(r['verts'], mat)

root = bpy.data.objects.new("Dw_Model", None)
wc.objects.link(root)
pivot_pos = {None: V((0, 0, 0))}

def pivot(name, parent, pos):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.05
    wc.objects.link(e)
    e.parent = parent if parent else root
    e.location = V(pos) - pivot_pos[parent.name if parent else None]
    pivot_pos[name] = V(pos)
    return e

def part(name, pv):
    global b
    ob = b.finish(name, (0, 0, 0))
    ob.data.transform(Matrix.Translation(-pivot_pos[pv.name]))
    ob.parent = pv
    b = B()
    return ob

# ---- rig points (local frame, seat surface at z = 0; floor at z = -0.485) ----
LEAN = 8.0
dirT = V((0, math.sin(math.radians(LEAN)), math.cos(math.radians(LEAN))))     # up the spine, leaning forward a little
hips = V((0, 0.02, 0.12))
Gt = Matrix.Translation(hips + dirT * 0.275) @ Euler((math.radians(-LEAN), 0, 0)).to_matrix().to_4x4()
neck = hips + dirT * 0.55
Gh = Matrix.Translation(neck + V((0, 0.02, 0.15))) @ Euler((math.radians(-8), 0, 0)).to_matrix().to_4x4()
sh = {s: Gt @ V((s * 0.27, 0.0, 0.2)) for s in (1, -1)}
elb = {s: sh[s] + V((0, 0, -0.28)) for s in (1, -1)}
hand = {s: elb[s] + V((0, 0, -0.31)) for s in (1, -1)}

dw_hips = pivot("Dw_Hips", None, hips)
dw_torso = pivot("Dw_Torso", dw_hips, hips)
dw_head = pivot("Dw_Head", dw_torso, neck)
dw_upper = {s: pivot("Dw_Upper" + n, dw_torso, sh[s]) for s, n in ((1, "R"), (-1, "L"))}
dw_fore = {s: pivot("Dw_Fore" + n, dw_upper[s], elb[s]) for s, n in ((1, "R"), (-1, "L"))}
dw_handR = pivot("Dw_HandR", dw_fore[1], hand[1])
dw_handL = pivot("Dw_HandL", dw_fore[-1], hand[-1])

# ---- trousers + legs + shoes (static, sitting with the knees under the table) ----
for s in (1, -1):
    hip = V((s * 0.09, 0.02, 0.10))
    knee = V((s * 0.10, 0.46, 0.10))
    ankle = V((s * 0.10, 0.52, -0.42))
    seg(hip, knee, 0.19, 0.19, PANTS)
    seg(knee, ankle, 0.17, 0.17, PANTS)
    b.box((0.15, 0.27, 0.09), (s * 0.10, 0.60, -0.44), SHOE)
    b.box((0.16, 0.28, 0.025), (s * 0.10, 0.60, -0.48), SOLE)
b.box((0.40, 0.30, 0.2), tuple(hips), PANTS)
part("W_Legs", dw_hips)

# ---- torso: black hoodie (hood bunched behind the neck, kangaroo pocket, drawstrings) ----
gbox(Gt, (0.42, 0.26, 0.58), (0, 0, 0), SHIRT)
gbox(Gt, (0.44, 0.28, 0.07), (0, 0, -0.27), SHIRT_SH)                       # ribbed hem
gbox(Gt, (0.32, 0.03, 0.14), (0, 0.145, -0.12), SHIRT_SH)                   # kangaroo pocket
gbox(Gt, (0.30, 0.18, 0.15), (0, -0.15, 0.26), SHIRT_SH)                    # hood behind the neck
gbox(Gt, (0.28, 0.05, 0.07), (0, 0.10, 0.285), SHIRT_SH)                    # hood opening around the neck
gbox(Gt, (0.02, 0.02, 0.17), (-0.05, 0.14, 0.17), STRINGW)                  # drawstrings
gbox(Gt, (0.02, 0.02, 0.17), (0.05, 0.14, 0.17), STRINGW)
part("W_Torso", dw_torso)

# ---- head: curly blond hair, blue eyes, big smile ----
gbox(Gh, (0.31, 0.28, 0.30), (0, 0, 0.15), SKIN)
gbox(Gh, (0.035, 0.05, 0.07), (-0.172, 0.0, 0.14), SKIN)                    # ears
gbox(Gh, (0.035, 0.05, 0.07), (0.172, 0.0, 0.14), SKIN)
gbox(Gh, (0.34, 0.31, 0.10), (0, -0.005, 0.33), HAIR)                       # hair volume on top
gbox(Gh, (0.33, 0.06, 0.2), (0, -0.14, 0.2), HAIR)                          # back
gbox(Gh, (0.04, 0.2, 0.14), (-0.17, -0.03, 0.22), HAIR)                     # sides
gbox(Gh, (0.04, 0.2, 0.14), (0.17, -0.03, 0.22), HAIR)
curls = [(-0.12, 0.13, 0.36, 12, -10), (-0.03, 0.15, 0.37, -8, 8), (0.06, 0.14, 0.36, 10, 14), (0.13, 0.11, 0.35, -6, -12),
         (-0.15, 0.04, 0.38, 14, -6), (0.15, 0.03, 0.38, -10, 10), (0.0, -0.05, 0.40, 8, 0), (-0.08, -0.1, 0.38, -12, 12),
         (0.09, -0.1, 0.38, 10, -14), (-0.17, 0.11, 0.30, 0, 20), (0.17, 0.10, 0.30, 0, -20)]
for (cx, cy, cz, rx, rz) in curls:                                          # a curly fringe + tufts, little tilted cubes
    gbox(Gh, (0.085, 0.085, 0.085), (cx, cy, cz), HAIR if abs(cx) < 0.1 else HAIR_DK, rot=(rx, 0, rz))
for ex in (-0.075, 0.075):
    gbox(Gh, (0.05, 0.02, 0.05), (ex, 0.142, 0.18), EYE)                    # eyes
    gbox(Gh, (0.07, 0.02, 0.015), (ex, 0.145, 0.235), BROW, rot=(0, 0, -6 if ex < 0 else 6))
gbox(Gh, (0.03, 0.04, 0.05), (0, 0.15, 0.13), SKIN)                          # nose
gbox(Gh, (0.11, 0.02, 0.04), (0, 0.142, 0.065), MOUTH)                      # open smile
gbox(Gh, (0.09, 0.022, 0.016), (0, 0.145, 0.078), TEETH)                    # teeth
# headset: band over the curls, big ear cups with a red ring, a boom mic reaching to the corner of his mouth
for sx in (-1, 1):
    gbox(Gh, (0.045, 0.11, 0.13), (sx * 0.19, 0.0, 0.16), HSET)                     # ear cup
    gbox(Gh, (0.012, 0.085, 0.10), (sx * 0.217, 0.0, 0.16), HSET_R)                 # coloured ring on the outside
    gbox(Gh, (0.025, 0.03, 0.26), (sx * 0.185, -0.01, 0.31), HSET)                  # band going up on each side
gbox(Gh, (0.40, 0.03, 0.03), (0, -0.01, 0.46), HSET)                                # band across the top
gbox(Gh, (0.02, 0.018, 0.10), (-0.19, 0.04, 0.085), HSET)                           # mic boom: down from the left cup...
gbox(Gh, (0.02, 0.15, 0.02), (-0.125, 0.13, 0.04), HSET, rot=(0, 0, -25))           # ...forward along the cheek...
gbox(Gh, (0.035, 0.03, 0.03), (-0.06, 0.20, 0.045), HSET_R)                         # ...to the mic tip
part("W_Head", dw_head)

# ---- arms: white sleeves with cuffs, hanging in the rest pose (the pose is set by rotating the pivots) ----
for s, n in ((1, "R"), (-1, "L")):
    seg(sh[s], elb[s], 0.115, 0.115, SHIRT)
    part("W_Upper" + n, dw_upper[s])
    seg(elb[s], elb[s] + V((0, 0, -0.26)), 0.105, 0.105, SHIRT)
    seg(elb[s] + V((0, 0, -0.26)), elb[s] + V((0, 0, -0.295)), 0.115, 0.115, SHIRT_SH)    # ribbed cuff
    b.box((0.08, 0.08, 0.1), tuple(hand[s] + V((0, 0, 0.02))), SKIN)
    part("W_Fore" + n, dw_fore[s])

# ---- table props (local frame; table top is at z = 0.275 above the seat) ----
TZ = 0.275
pr = b
G0 = Matrix.Identity(4)
# laptop in front of him: base + keyboard + trackpad, lid leaning back with a bright screen showing "code"
LX, LY = 0.0, 0.50
gbox(G0, (0.34, 0.24, 0.018), (LX, LY, TZ + 0.009), ("LaptopLid", (0.55, 0.60, 0.70)))
gbox(G0, (0.30, 0.10, 0.006), (LX, LY + 0.02, TZ + 0.02), ("Key", (0.96, 0.94, 0.88)))
gbox(G0, (0.10, 0.05, 0.004), (LX, LY - 0.07, TZ + 0.02), ("DarkFrame", (0.17, 0.17, 0.21)))
Gl = Matrix.Translation((LX, LY + 0.12, TZ + 0.018)) @ Euler((math.radians(-14), 0, 0)).to_matrix().to_4x4()
gbox(Gl, (0.34, 0.012, 0.23), (0, 0, 0.115), ("LaptopLid", (0.55, 0.60, 0.70)))
gbox(Gl, (0.30, 0.006, 0.19), (0, -0.008, 0.115), ("Screen", (0.45, 0.85, 0.9)))
for k, w_ in enumerate((0.20, 0.14, 0.24, 0.10, 0.18)):
    gbox(Gl, (w_, 0.008, 0.012), (-0.14 + w_ / 2, -0.012, 0.19 - k * 0.028), ("DarkFrame", (0.17, 0.17, 0.21)))   # lines of code
# a few A4 sheets, a loose one slightly turned
for k, (px, py, rz) in enumerate(((-0.28, 0.72, 8), (-0.27, 0.73, -5), (-0.29, 0.71, 3))):
    gbox(G0, (0.21, 0.297, 0.004), (px, py, TZ + 0.002 + 0.004 * k), ("Paper", (0.98, 0.97, 0.93)), rot=(0, 0, rz))
gbox(G0, (0.21, 0.297, 0.003), (-0.52, 0.58, TZ + 0.0015), ("PaperW", (0.95, 0.95, 0.92)), rot=(0, 0, 28))
# coffee can
CX, CY = 0.30, 0.72
pr.cyl(0.033, 0.033, 0.125, (CX, CY, TZ + 0.0625), ("CupBrown", (0.62, 0.40, 0.26)), 10)
pr.cyl(0.0345, 0.0345, 0.05, (CX, CY, TZ + 0.06), ("CupText", (0.98, 0.95, 0.88)), 10)
pr.cyl(0.03, 0.03, 0.01, (CX, CY, TZ + 0.13), ("Metal", (0.66, 0.72, 0.80)), 10)
part("W_Props", dw_hips)

# ---- the mug: its own object (origin at the bottom centre), picked up by the script ----
MX, MY = 0.36, 0.48
mug = B()
b = mug
b.cyl(0.042, 0.04, 0.09, (0, 0, 0.045), ("CanBlue", (0.55, 0.80, 0.95)), 10)
b.cyl(0.034, 0.034, 0.006, (0, 0, 0.088), ("CupBrown", (0.62, 0.40, 0.26)), 10)           # coffee
b.box((0.015, 0.05, 0.05), (0.052, 0, 0.05), ("CanBlue", (0.55, 0.80, 0.95)))              # handle
mo = b.finish("Dw_Mug", (MX, MY, TZ), outline=0.008)
mo.parent = root
b = B()

# place him on the south west-side chair of the west window table (the left one when you walk in from the corridor and look west),
# facing east towards the corridor; seat top z = 0.485
root.location = (-30.05, -4.15, 0.485)
root.rotation_euler = (0, 0, math.radians(-90))

# the working pose used by Godot as the rest pose (arms to the keyboard); kept here so previews match the game
POSE_TYPE = {"Dw_UpperR": 0.45, "Dw_ForeR": 1.0, "Dw_UpperL": 0.45, "Dw_ForeL": 1.0}
POSE_DRINK = {"Dw_UpperR": 0.35, "Dw_ForeR": 2.6, "Dw_UpperL": 0.45, "Dw_ForeL": 1.0}
bpy.context.view_layer.update()

# export (the root keeps its z-rotation; the animation pivots stay in their neutral pose)
bpy.ops.object.select_all(action='DESELECT')
for o in wc.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath="C:/Users/asgei/Desktop/student_game/godot_project/assets/npc_worker.glb", export_format='GLB',
    use_selection=True, export_apply=True, export_yup=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
