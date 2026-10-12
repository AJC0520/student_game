exec(open(LIB).read())

# NPC lounging on the Online room's corner sofa: slouched back, one hand on his forehead, a controller in the other.
# Same flat-shaded, outlined toon boxes as the level / player. Built in a local frame (facing +Y, origin on the seat
# cushion), then placed on the east-wall run of the corner sofa (see online_block.py) with a z-rotation.
# Split into rigid parts hung on pivot empties (Sg_*) so Godot can animate him (breathing, fidgeting) without a skeleton;
# exported already in world position (assets/npc_sofa.glb).

old = bpy.data.collections.get("Npc")
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o)
    bpy.data.collections.remove(old)
bpy.data.orphans_purge(do_recursive=True)

nc = bpy.data.collections.new("Npc")
bpy.context.scene.collection.children.link(nc)
def get_coll():
    return nc

SKIN = ("Skin", (0.96, 0.76, 0.62))
HAIR = ("HairLight", (0.62, 0.47, 0.30))
EYE = ("Eye", (0.1, 0.1, 0.14))
HOOD = ("HoodieGrey", (0.74, 0.74, 0.77))
HOOD_DK = ("HoodieGreyDark", (0.58, 0.58, 0.62))
PRINT = ("PrintRed", (0.85, 0.20, 0.28))
JEANS = ("JeansDark", (0.16, 0.23, 0.42))
SHOE = ("ShoeWhite", (0.95, 0.95, 0.97))
SOLE = ("ShoeSole", (0.6, 0.62, 0.7))
PAD = ("CabBlack", (0.10, 0.10, 0.12))
BTN = ("CanRed", (0.85, 0.28, 0.28))

V = Vector
b = B()

def gbox(G, size, loc, mat, rot=(0, 0, 0)):
    """Box in the frame G (a 4x4 matrix), centred at `loc` inside that frame."""
    M = G @ Matrix.Translation(loc) @ Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
    r = bmesh.ops.create_cube(b.bm, size=1.0, matrix=M)
    return b._tag(r['verts'], mat)

def seg(p0, p1, w, d, mat):
    """Box stretched from point p0 to p1 (thickness w x d)."""
    p0, p1 = V(p0), V(p1)
    axis = p1 - p0
    R = V((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    M = Matrix.Translation((p0 + p1) / 2) @ R @ Matrix.Diagonal((w, d, axis.length, 1))
    r = bmesh.ops.create_cube(b.bm, size=1.0, matrix=M)
    return b._tag(r['verts'], mat)

root = bpy.data.objects.new("Npc_Model", None)
nc.objects.link(root)
pivot_pos = {None: V((0, 0, 0))}   # absolute (local-frame) position of every pivot, to offset the part meshes

def pivot(name, parent, pos):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.06
    nc.objects.link(e)
    e.parent = parent if parent else root
    pp = pivot_pos[parent.name if parent else None]
    e.location = V(pos) - pp
    pivot_pos[name] = V(pos)
    return e

def part(name, pv):
    """Finish the current builder as mesh `name`, hung on pivot `pv` (mesh moved so the pivot is its origin)."""
    global b
    ob = b.finish(name, (0, 0, 0))
    ob.data.transform(Matrix.Translation(-pivot_pos[pv.name]))
    ob.parent = pv
    b = B()
    return ob

# ---- skeleton of points (local frame: +Y forward, +X = his right, z up, seat surface at z=0) ----
RECLINE = 50.0
dirT = V((0, -math.sin(math.radians(RECLINE)), math.cos(math.radians(RECLINE))))     # up the spine
hips = V((0, 0.15, 0.10))
Gt = Matrix.Translation(hips + dirT * 0.275) @ Euler((math.radians(RECLINE), 0, 0)).to_matrix().to_4x4()   # torso centre frame
neck = hips + dirT * 0.55
HT = 38.0                                                                              # head tipped back against the sofa
Gh = Matrix.Translation(neck + V((0, -math.sin(math.radians(HT)), math.cos(math.radians(HT)))) * 0.15)      @ Euler((math.radians(HT), math.radians(4), math.radians(8))).to_matrix().to_4x4()
sh_r = Gt @ V((0.27, 0.0, 0.2))
sh_l = Gt @ V((-0.27, 0.0, 0.2))
hand_r = Gh @ V((0.07, 0.15, 0.14))
hand_l = Gt @ V((-0.06, 0.2, -0.04))

sg_hips = pivot("Sg_Hips", None, hips)
sg_torso = pivot("Sg_Torso", sg_hips, hips)
sg_head = pivot("Sg_Head", sg_torso, neck)
sg_arm_r = pivot("Sg_ArmR", sg_torso, sh_r)
sg_arm_l = pivot("Sg_ArmL", sg_torso, sh_l)
sg_pad = pivot("Sg_Pad", sg_arm_l, hand_l)
sg_leg = {s: pivot("Sg_Leg" + n, sg_hips, (s * 0.11, 0.15, 0.10)) for s, n in ((1, "R"), (-1, "L"))}
sg_foot = {s: pivot("Sg_Foot" + n, sg_leg[s], (s * 0.20, 0.80, -0.46)) for s, n in ((1, "R"), (-1, "L"))}

# ---- pelvis ----
b.box((0.42, 0.3, 0.18), tuple(hips), JEANS)
part("S_Pelvis", sg_hips)

# ---- torso: grey hoodie with a red print ----
gbox(Gt, (0.42, 0.27, 0.56), (0, 0, 0), HOOD)
gbox(Gt, (0.44, 0.29, 0.07), (0, 0, -0.27), HOOD_DK)             # hem
gbox(Gt, (0.34, 0.03, 0.15), (0, 0.15, -0.14), HOOD_DK)          # pocket
gbox(Gt, (0.26, 0.02, 0.09), (0, 0.145, 0.1), PRINT)             # red chest print
gbox(Gt, (0.15, 0.021, 0.04), (0, 0.146, 0.1), HOOD)             # a bit of "lettering" in the print
gbox(Gt, (0.3, 0.17, 0.16), (0, -0.15, 0.27), HOOD_DK)           # hood bunched up behind the neck
part("S_Torso", sg_torso)

# ---- legs (baggy dark jeans), stretched out in front ----
for s, n in ((1, "R"), (-1, "L")):
    hip = V((s * 0.11, 0.15, 0.10))
    knee = V((s * 0.17, 0.60, -0.01))
    ankle = V((s * 0.20, 0.80, -0.46))
    seg(hip, knee, 0.20, 0.20, JEANS)
    seg(knee, ankle, 0.19, 0.19, JEANS)
    part("S_Leg" + n, sg_leg[s])
    b.box((0.17, 0.30, 0.10), (s * 0.20, 0.88, -0.50), SHOE)
    b.box((0.18, 0.31, 0.03), (s * 0.20, 0.88, -0.545), SOLE)
    part("S_Foot" + n, sg_foot[s])

# ---- head: eyes closed, light brown hair, slight smile ----
gbox(Gh, (0.31, 0.29, 0.31), (0, 0, 0), SKIN)
gbox(Gh, (0.33, 0.30, 0.09), (0, -0.005, 0.18), HAIR)            # hair cap
gbox(Gh, (0.33, 0.05, 0.23), (0, -0.14, 0.07), HAIR)             # back
gbox(Gh, (0.34, 0.04, 0.09), (0, 0.15, 0.15), HAIR, rot=(8, 0, 0))   # fringe
gbox(Gh, (0.035, 0.2, 0.17), (-0.165, -0.025, 0.09), HAIR)
gbox(Gh, (0.035, 0.2, 0.17), (0.165, -0.025, 0.09), HAIR)
for ex in (-0.075, 0.075):
    gbox(Gh, (0.065, 0.02, 0.014), (ex, 0.147, 0.02), EYE)        # closed eyes (thin lines)
    gbox(Gh, (0.07, 0.02, 0.014), (ex, 0.147, 0.075), HAIR)       # eyebrows
gbox(Gh, (0.035, 0.04, 0.05), (0, 0.155, -0.03), SKIN)            # nose
gbox(Gh, (0.06, 0.02, 0.014), (0, 0.147, -0.095), EYE)            # mouth
part("S_Head", sg_head)

# ---- right arm (+X): bent, hand resting on the forehead ----
elb_r = (sh_r + hand_r) / 2 + V((0.17, 0.03, 0.08))
seg(sh_r, elb_r, 0.125, 0.125, HOOD)
fore = elb_r + (hand_r - elb_r) * 0.78
seg(elb_r, fore, 0.11, 0.11, HOOD)
seg(fore, fore + (hand_r - elb_r) * 0.1, 0.12, 0.12, HOOD_DK)    # cuff
b.box((0.1, 0.1, 0.1), tuple(hand_r), SKIN)
part("S_ArmR", sg_arm_r)

# ---- left arm (-X): resting on his stomach, holding a controller ----
elb_l = sh_l + V((-0.06, 0.22, -0.16))
seg(sh_l, elb_l, 0.125, 0.125, HOOD)
fore_l = elb_l + (hand_l - elb_l) * 0.78
seg(elb_l, fore_l, 0.11, 0.11, HOOD)
seg(fore_l, fore_l + (hand_l - elb_l) * 0.1, 0.12, 0.12, HOOD_DK)
part("S_ArmL", sg_arm_l)
b.box((0.1, 0.1, 0.1), tuple(hand_l), SKIN)
Gp = Matrix.Translation(hand_l + V((0.02, 0.07, 0.03))) @ Euler((math.radians(RECLINE - 35), 0, math.radians(15))).to_matrix().to_4x4()
gbox(Gp, (0.23, 0.1, 0.04), (0, 0, 0), PAD)                       # controller body
gbox(Gp, (0.05, 0.09, 0.06), (-0.09, 0.0, -0.02), PAD)            # grips
gbox(Gp, (0.05, 0.09, 0.06), (0.09, 0.0, -0.02), PAD)
gbox(Gp, (0.025, 0.025, 0.012), (0.06, 0.0, 0.026), BTN)
part("S_Pad", sg_pad)

# place on the east-wall run of the corner sofa, looking towards the TV (seat cushion top z = 0.56)
root.location = (-10.55, 2.9, 0.56)
root.rotation_euler = (0, 0, math.radians(110))
bpy.context.view_layer.update()
