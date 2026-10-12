exec(open(LIB).read())

# ---- remove previous blockout ----
old = bpy.data.collections.get("Blockout_A4")
if old:
    for o in list(old.objects):
        bpy.data.objects.remove(o)
    bpy.data.collections.remove(old)
# purge leftovers from earlier rebuilds (orphan meshes / curves) so the .blend stays small
bpy.data.orphans_purge(do_recursive=True)

bo = bpy.data.collections.new("Blockout_A4")
bpy.context.scene.collection.children.link(bo)
def get_coll():
    return bo

# All coordinates are metres, axis-aligned. +X = along the main corridor towards the elevators,
# +Y = towards the Online side. Derived from the traced floorplan (px / 40 per metre), then snapped.
WALL = ("Wall", (0.42, 0.46, 0.62))
H, TH = 3.0, 0.2

N = 4.5   # north wall of the rooms row
# curved south wall of A4-124: arc of radius R, lowest point at x=-17, y=-14.4, meeting the west wall at y=-8
SY = -14.4
ARC_R = 18.51
ARC_CX, ARC_CY = -17.0, SY + ARC_R
def arc_y(x):
    return ARC_CY - math.sqrt(ARC_R ** 2 - (x - ARC_CX) ** 2)
ARC = [(ARC_CX - 14.0 * k / 8, arc_y(ARC_CX - 14.0 * k / 8)) for k in range(1, 9)]  # (-18.75..-31)

walls_m = [
    # outer shell
    [(-31, 0), (-29, 0), (-29, N), (-23, N)],
    [(-9.7, N), (-0.9, N), (-0.9, 3.5), (6.5, 3.5), (6.5, -0.5)],
    [(6.5, -4.5), (6.5, -5), (-0.9, -5),
     (-0.9, -9.5), (4, -9.5), (4, SY), (ARC_CX, SY)] + ARC,
    # A4-138 / Online / A4-145 / A4-147 partitions (north-south)
    [(-23, 0), (-23, N)],
    # A4-145 / A4-147: walls only (no room behind them), doors are added on the corridor face
    [(-9.7, 0), (-9.7, N)], [(-3.7, 0), (-3.7, N)], [(-9.7, 0), (-3.7, 0)],
    # south walls of the room row (doorways left open)
    [(-29, 0), (-26.5, 0)], [(-24.5, 0), (-23, 0)],
    # corridor south wall + closed strip behind it
    [(-3, -2.5), (-3, -5), (-23.5, -5), (-23.5, -2.5)],
    [(-23.5, -5), (-23.5, -6.4)],
    # A4-124 | A4-156 divider
    [(-20, -5), (-20, arc_y(-20))],
    # Heis / lift-lobby walls (traced from the screenshot)
    [(-0.9, 0), (-0.15, 0)], [(1.65, 0), (6.5, 0)], [(2.4, 0), (2.4, 3.5)],
    # east cross-corridor wall with doorway to A4-001 (gap -2.7..-1.4) and open lobby (0.5..3.5)
    [(-0.9, 0), (-0.9, 3.5)],
]

walls = B()
for pl in walls_m:
    for (x0, y0), (x1, y1) in zip(pl, pl[1:]):
        L = math.hypot(x1 - x0, y1 - y0)
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        walls.box((L + TH, TH, H), ((x0 + x1) / 2, (y0 + y1) / 2, H / 2), WALL, rot=(0, 0, ang))
walls.box((1.8, 0.2, 0.6), (0.75, 0.0, 2.7), WALL)   # above the cab-1 entrance
LOW = -4.0
for (x0, y0), (x1, y1) in (((-23.5, -5), (-3, -5)), ((-3, -5), (-3, -2.5)), ((-23.5, -5), (-23.5, -2.5))):
    L = math.hypot(x1 - x0, y1 - y0)
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    walls.box((L + TH, TH, -LOW), ((x0 + x1) / 2, (y0 + y1) / 2, LOW / 2), WALL, rot=(0, 0, ang))
walls.finish("Walls", (0, 0, 0), outline=0.03)

# ---- floor slab (rectangles; the shaft behind the glass is a hole) ----
rects = [(-29, 0, -9.7, N), (-3.7, 0, -0.9, N), (-23.5, -2.5, -0.9, 0), (-0.9, -5, 6.5, 3.5), (-3, -5, -0.9, -2.5)]
fl = B()
for x0, y0, x1, y1 in rects:
    fl.box((x1 - x0, y1 - y0, 0.1), ((x0 + x1) / 2, (y0 + y1) / 2, -0.05), ("FloorPolished", (0.56, 0.58, 0.63)))
south = [(-31, 0), (-23.5, 0), (-23.5, -5), (-0.9, -5), (-0.9, -9.5), (4, -9.5), (4, SY), (ARC_CX, SY)] + ARC
fi = fl.mi(("FloorPolished", (0.56, 0.58, 0.63)))
vs = [fl.bm.verts.new((x, y, -0.1)) for x, y in south]
ff = fl.bm.faces.new(vs)
ext = bmesh.ops.extrude_face_region(fl.bm, geom=[ff])
nv = [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]
bmesh.ops.translate(fl.bm, verts=nv, vec=(0, 0, 0.1))
for f2 in fl.bm.faces:
    f2.material_index = fi
floor_ob = fl.finish("Floor", (0, 0, 0), outline=0.0)


# ---- glass wall along the corridor (y = -2.5) ----
GY = -2.5
g = B()
GLASS = ("Glass", (0.65, 0.85, 0.95))
FRAME = ("GlassFrame", (0.22, 0.25, 0.32))
x0, x1 = -23.5, -3.0
g.box((x1 - x0, 0.03, 2.9), ((x0 + x1) / 2, GY, 1.5), GLASS)
g.box((x1 - x0 + 0.1, 0.10, 0.10), ((x0 + x1) / 2, GY, 2.95), FRAME)
g.box((x1 - x0 + 0.1, 0.10, 0.10), ((x0 + x1) / 2, GY, 0.05), FRAME)
n = 7
for k in range(n + 1):
    x = x0 + (x1 - x0) * k / n
    g.box((0.10, 0.10, 3.0), (x, GY, 1.5), FRAME)
# west window (x = -31, y -8..0): same glass, floor to ceiling
WX, WY0, WY1 = -31.0, -8.0, 0.0
g.box((0.03, WY1 - WY0, 2.9), (WX, (WY0 + WY1) / 2, 1.5), GLASS)
g.box((0.10, WY1 - WY0 + 0.1, 0.10), (WX, (WY0 + WY1) / 2, 2.95), FRAME)
g.box((0.10, WY1 - WY0 + 0.1, 0.10), (WX, (WY0 + WY1) / 2, 0.05), FRAME)
for k in range(6):
    g.box((0.10, 0.10, 3.0), (WX, WY0 + (WY1 - WY0) * k / 5, 1.5), FRAME)
# ---- A4-001 west wall (x = -0.9): wired-glass partition, dark frames, open double door (reference photo 2) ----
DFR = ("DarkFrame", (0.17, 0.17, 0.21))
DOT = ("GlassDot", (0.95, 0.95, 0.95))
WXP = -0.9
for (ya, yb) in ((-5.0, -2.7), (-1.4, 0.0)):                       # fixed glass panels
    g.box((0.03, yb - ya, 2.85), (WXP, (ya + yb) / 2, 1.475), GLASS)
    g.box((0.12, yb - ya, 0.10), (WXP, (ya + yb) / 2, 0.05), DFR)    # bottom rail
g.box((0.03, 1.3, 0.85), (WXP, -2.05, 2.525), GLASS)               # transom above the door
g.box((0.12, 1.3, 0.10), (WXP, -2.05, 2.10), DFR)                   # door header rail
g.box((0.12, 5.1, 0.10), (WXP, -2.5, 2.95), DFR)                    # top rail
for yy in (-5.0, -3.85, -2.7, -1.4, -0.7, 0.0):                     # posts
    g.box((0.10, 0.10, 3.0), (WXP, yy, 1.5), DFR)
for (yc_list) in ((-4.5, -3.95, -3.4), (-0.95,)):                   # wired-glass dot clusters (two heights)
    for yc in yc_list:
        for zc in (0.8, 1.5):
            for i in range(3):
                for j in range(3):
                    g.box((0.02, 0.04, 0.04), (WXP + 0.025, yc + 0.06 * (i - 1), zc + 0.06 * (j - 1)), DOT)
for yh in (-2.74, -1.36):                                            # both door leaves swung open into A4-001
    g.box((0.65, 0.05, 0.07), (-0.575, yh, 2.06), DFR)
    g.box((0.65, 0.05, 0.07), (-0.575, yh, 0.10), DFR)
    for xs in (-0.865, -0.285):
        g.box((0.07, 0.05, 2.0), (xs, yh, 1.08), DFR)
    g.box((0.50, 0.02, 1.88), (-0.575, yh, 1.08), GLASS)
# east window of A4-001 (x = 6.5, y -4.5..-0.5)
EXX, EY0, EY1 = 6.5, -4.5, -0.5
g.box((0.03, EY1 - EY0, 2.9), (EXX, (EY0 + EY1) / 2, 1.5), GLASS)
g.box((0.10, EY1 - EY0 + 0.1, 0.10), (EXX, (EY0 + EY1) / 2, 2.95), FRAME)
g.box((0.10, EY1 - EY0 + 0.1, 0.10), (EXX, (EY0 + EY1) / 2, 0.05), FRAME)
for yy in (EY0, (EY0 + EY1) / 2, EY1):
    g.box((0.10, 0.12, 3.0), (EXX, yy, 1.5), FRAME)
# Online room: window wall (north, y = 4.5) and glass partition to the corridor (south, y = 0)
PARTW = ("PartWood", (0.86, 0.66, 0.38))
ox0, ox1 = -23.0, -9.7
g.box((ox1 - ox0, 0.03, 2.9), ((ox0 + ox1) / 2, 4.5, 1.5), GLASS)
g.box((ox1 - ox0 + 0.1, 0.12, 0.10), ((ox0 + ox1) / 2, 4.5, 2.95), FRAME)
g.box((ox1 - ox0 + 0.1, 0.12, 0.10), ((ox0 + ox1) / 2, 4.5, 0.05), FRAME)
for k in range(7):
    g.box((0.10, 0.10, 3.0), (ox0 + (ox1 - ox0) * k / 6, 4.5, 1.5), FRAME)
px0, px1 = -21.0, -9.7
g.box((px1 - px0, 0.03, 2.9), ((px0 + px1) / 2, 0.0, 1.5), GLASS)
g.box((px1 - px0, 0.12, 0.10), ((px0 + px1) / 2, 0.0, 2.95), PARTW)
g.box((px1 - px0, 0.12, 0.10), ((px0 + px1) / 2, 0.0, 0.05), PARTW)
for k in range(9):
    g.box((0.08, 0.10, 3.0), (px0 + (px1 - px0) * k / 8, 0.0, 1.5), PARTW)
g.box((px1 - px0, 0.03, 0.35), ((px0 + px1) / 2, -0.075, 1.1), ("Frost", (0.93, 0.95, 0.97)))   # frosted band
glass_ob = g.finish("Glass_Wall", (0, 0, 0), outline=0.0)
gm = bpy.data.materials["Toon_Glass"]
gm.use_nodes = True
nt = gm.node_tree; nt.nodes.clear()
out = nt.nodes.new('ShaderNodeOutputMaterial')
pb = nt.nodes.new('ShaderNodeBsdfPrincipled')
pb.inputs['Base Color'].default_value = (0.65, 0.85, 0.95, 1)
pb.inputs['Alpha'].default_value = 0.25
pb.inputs['Roughness'].default_value = 0.05
nt.links.new(pb.outputs[0], out.inputs[0])
gm.diffuse_color = (0.65, 0.85, 0.95, 0.25)
try:
    gm.surface_render_method = 'BLENDED'
except Exception:
    pass

# ---- wooden handrails, wall-mounted on the glass mullions (flat rail on small steel brackets, as in the photo) ----
r = B()
WOODR = ("RailWood", (0.78, 0.55, 0.30))
RBRK = ("RailBracket", (0.22, 0.24, 0.30))
RD = 0.10                      # rail centre distance from the glass plane
# corridor glass wall (along x at y = GY); room side is +y; mullions at x0 + (x1 - x0) * k / 7
r.box((x1 - x0, 0.05, 0.06), ((x0 + x1) / 2, GY + RD, 1.0), WOODR)
for k in range(8):
    r.box((0.05, RD, 0.05), (x0 + (x1 - x0) * k / 7, GY + RD / 2, 1.0), RBRK)
# west window (x = WX); room side is +x; mullions at WY0 + (WY1 - WY0) * k / 5
r.box((0.05, WY1 - WY0, 0.06), (WX + RD, (WY0 + WY1) / 2, 1.0), WOODR)
for k in range(6):
    r.box((RD, 0.05, 0.05), (WX + RD / 2, WY0 + (WY1 - WY0) * k / 5, 1.0), RBRK)
# Online window handrail (wall-mounted on the mullions)
r.box((ox1 - ox0, 0.05, 0.06), ((ox0 + ox1) / 2, 4.5 - RD, 1.0), WOODR)
for k in range(7):
    r.box((0.05, RD, 0.05), (ox0 + (ox1 - ox0) * k / 6, 4.5 - RD / 2, 1.0), RBRK)
r.finish("Railing", (0, 0, 0), outline=0.012)

# ---- lower level seen through the shaft (not playable) ----
lo = B()
lo.box((x1 - x0, 2.5, 0.1), ((x0 + x1) / 2, -3.75, -4.05), ("LowerFloor", (0.52, 0.56, 0.68)))
for xx in (-19.0, -13.0, -8.0):
    lo.box((1.6, 0.8, 0.75), (xx, -3.75, -3.625), ("LowerDesk", (0.70, 0.55, 0.40)))
    lo.box((0.45, 0.45, 0.45), (xx, -4.4, -3.775), ("LowerChair", (0.45, 0.5, 0.75)))
lo.finish("Lower_Level", (0, 0, 0), outline=0.012)


# ---- doors for A4-145 / A4-147 (closed, on the corridor face of the solid block) ----
DOOR = ("Door", (0.78, 0.52, 0.30))
DFRAME = ("DoorFrame", (0.30, 0.27, 0.36))
for room, dxc in (("A4-145", -8.0), ("A4-147", -5.2)):
    d = B()
    d.box((1.3, 0.10, 0.10), (dxc, -0.05, 2.15), DFRAME)
    d.box((0.10, 0.10, 2.15), (dxc - 0.6, -0.05, 1.075), DFRAME)
    d.box((0.10, 0.10, 2.15), (dxc + 0.6, -0.05, 1.075), DFRAME)
    d.box((1.1, 0.06, 2.05), (dxc, -0.04, 1.025), DOOR)
    d.box((0.05, 0.08, 0.05), (dxc + 0.4, -0.10, 1.0), ("DoorHandle", (0.80, 0.82, 0.88)))
    dob = d.finish("Door_" + room, (0, -0.1, 0), outline=0.01)
    text_on(dob, room, (dxc, -0.14, 2.5), (90, 0, 0), 0.22, ("LabelInk", (0.15, 0.17, 0.30)), extrude=0.005, name="Sign_" + room)

# ---- room labels ----
labels = {"A4-138": (-26, 2.2),  "A4-024": (-13, -1.25), "A4-025": (-27, -3), "A4-124": (-25.5, -10), "A4-156": (-9, -10),
          "A4-001": (3, -1.5)}
# floor labels disabled (removed from the level on request); re-enable by uncommenting:
# for n, (x, y) in labels.items():
#     text_on(floor_ob, n, (x, y, 0.02), (0, 0, 0), 0.8, ("LabelInk", (0.15, 0.17, 0.30)), extrude=0.005, name="Label_" + n)

# ---- lift 1: the lobby room IS the cab (interior cladding), lift 2: sealed cab (doors only) ----
LWOOD = ("LiftWood", (0.90, 0.60, 0.32))
LPANEL = ("LiftPanel", (0.33, 0.38, 0.35))
LSTEEL = ("LiftSteel", (0.74, 0.74, 0.76))
LFLOOR = ("LiftFloor", (0.28, 0.28, 0.30))
LCEIL = ("LiftCeil", (0.80, 0.52, 0.28))
LLIGHT = ("LiftLight", (1.0, 0.96, 0.80))
LVENT = ("LiftVent", (0.55, 0.57, 0.60))
LRAIL = ("LiftRail", (0.92, 0.62, 0.30))
LCTRL = ("LiftControl", (0.14, 0.15, 0.19))
LBTN = ("LiftBtn", (1.0, 0.8, 0.25))
LLED = ("LiftLED", (0.95, 0.12, 0.12))
X0, X1, Y0, Y1 = -0.8, 2.3, 0.1, 3.4       # inner faces of the cab-1 walls
CW = 0.04
CXM, CYM = (X0 + X1) / 2, (Y0 + Y1) / 2
ENT0, ENT1 = -0.15, 1.65                      # entrance opening along x (1.8 m)

iv = B()
for xf, sx in ((X0 + CW / 2, 1), (X1 - CW / 2, -1)):            # side walls
    iv.box((CW, Y1 - Y0, 0.9), (xf, CYM, 0.45), LPANEL)
    iv.box((CW, Y1 - Y0, 1.5), (xf, CYM, 1.65), LWOOD)
iv.box((X1 - X0, CW, 0.9), (CXM, Y1 - CW / 2, 0.45), LPANEL)    # back wall
iv.box((X1 - X0, CW, 1.5), (CXM, Y1 - CW / 2, 1.65), LSTEEL)
for xa, xb in ((X0, ENT0), (ENT1, X1)):                          # front wall pieces beside the entrance
    L = xb - xa
    iv.box((L, CW, 0.9), ((xa + xb) / 2, Y0 + CW / 2, 0.45), LPANEL)
    iv.box((L, CW, 1.5), ((xa + xb) / 2, Y0 + CW / 2, 1.65), LWOOD)
for z in (0.95, 0.78):                                           # two handrails on the back wall
    iv.box((2.6, 0.07, 0.07), (CXM, Y1 - 0.10, z), LRAIL)
for dx in (-0.8, 0.8):
    iv.box((0.05, 0.10, 0.20), (CXM + dx, Y1 - 0.06, 0.865), LSTEEL)
iv.box((0.35, 0.04, 1.0), (1.98, Y0 + CW + 0.02, 1.3), LCTRL)    # control strip beside the door
for k in range(5):
    iv.box((0.04, 0.02, 0.04), (1.98, Y0 + CW + 0.045, 0.95 + 0.14 * k), LBTN)
iv.box((X1 - X0, Y1 - Y0, 0.02), (CXM, CYM, 0.01), LFLOOR)       # dark floor
iv.box((0.5, 0.04, 0.2), (0.75, 0.145, 2.25), LCTRL)             # LED floor display backing (digits are drawn in Godot)
iv.finish("Lift_Interior", (0, 0, 0), outline=0.01)

ce = B()
ce.box((X1 - X0, Y1 - Y0, 0.1), (CXM, CYM, 2.45), LCEIL)
for yy in (0.9, 2.6):
    ce.box((2.2, 0.14, 0.02), (CXM, yy, 2.39), LLIGHT)
for xx in (-0.4, 1.9):
    for yy in (0.5, 3.0):
        ce.box((0.45, 0.35, 0.02), (xx, yy, 2.39), LVENT)
ce.finish("Lift_Ceiling", (0, 0, 0), outline=0.01)

def lift_frame(b, cx, closed):
    for sx in (-1, 1):
        b.box((0.2, 0.25, 2.4), (cx + sx * 1.0, 0.0, 1.2), LSTEEL)
    b.box((2.2, 0.25, 0.3), (cx, 0.0, 2.25), LSTEEL)
    b.box((1.8, 0.25, 0.03), (cx, 0.0, 0.015), LSTEEL)
    if closed:
        for sx in (-1, 1):
            b.box((0.88, 0.05, 2.1), (cx + sx * 0.45, -0.12, 1.08), LSTEEL)
        b.box((0.02, 0.06, 2.1), (cx, -0.13, 1.08), LCTRL)
    # floor indicator above the door + call button beside it
    b.box((0.5, 0.04, 0.18), (cx, -0.14, 2.25), LCTRL)
    b.box((0.22, 0.05, 0.06), (cx, -0.15, 2.25), LLED)
lf = B()
lift_frame(lf, 0.75, False)   # cab 1: open entrance
lift_frame(lf, 4.4, True)     # cab 2: closed, not accessible
lf.finish("Lift_Doors", (0, 0, 0), outline=0.012)

# cab-1 door leaves as separate objects so Godot can slide them open
for nm, cxl in (("Lift1_Leaf_L", 0.30), ("Lift1_Leaf_R", 1.20)):
    lb = B()
    lb.box((0.88, 0.05, 2.1), (cxl, 0.0, 1.08), LSTEEL)
    lb.finish(nm, (0, 0, 0), outline=0.01)

# ---- A4-001 dressing (from the reference photos) ----
WALLFLAT = ("LiftWallFlat", (0.60, 0.61, 0.64))
DARKF = ("DarkFrame", (0.17, 0.17, 0.21))
DGLASS = ("DoorGlass", (0.16, 0.18, 0.22))
WHITE = ("WhiteBand", (0.95, 0.95, 0.95))
EXITG = ("ExitGreen", (0.10, 0.62, 0.32))
CORK = ("Cork", (0.78, 0.58, 0.36))
SIGNG = ("SignGrey", (0.20, 0.22, 0.27))
CHAIRB = ("ChairBlue", (0.42, 0.60, 0.80))
CONC = ("Concrete", (0.62, 0.63, 0.66))
SLAT = ("WoodSlat", (0.88, 0.74, 0.50))
METALX = ("Metal", (0.66, 0.72, 0.80))
a = B()
# lift bank: stainless header band + cladding panels between/next to the lifts
# the lift wall itself: one flat grey cladding over the whole wall face (openings for the lifts stay clear)
for cxp, wp in ((-0.625, 0.55), (2.575, 1.45), (5.95, 0.9)):
    a.box((wp, 0.06, 3.0), (cxp, -0.13, 1.5), WALLFLAT)
for cxp, wp in ((0.75, 2.2), (4.4, 2.2)):
    a.box((wp, 0.06, 0.6), (cxp, -0.13, 2.7), WALLFLAT)
a.box((0.40, 0.08, 0.40), (2.6, -0.20, 1.85), SIGNG)               # "A" block sign
# single call-button panel between lift 1 and lift 2
a.box((0.16, 0.04, 0.34), (2.575, -0.12, 1.1), LCTRL)
a.box((0.05, 0.05, 0.05), (2.575, -0.15, 1.15), LBTN)
a.box((0.05, 0.05, 0.05), (2.575, -0.15, 1.03), LBTN)
# door A4-010 on the south wall (stairs): dark frame, wired glass with white bands, exit sign above
for x in (1.1, 2.5):
    a.box((0.10, 0.12, 2.2), (x, -4.94, 1.1), DARKF)
a.box((1.5, 0.12, 0.10), (1.8, -4.94, 2.25), DARKF)
a.box((1.3, 0.04, 2.1), (1.8, -4.93, 1.05), DGLASS)          # plain leaf
a.box((0.45, 0.05, 0.20), (1.8, -4.90, 2.6), EXITG)
a.box((0.30, 0.055, 0.03), (1.8, -4.89, 2.6), WHITE)
# notice board + wayfinding sign
a.box((0.96, 0.03, 0.76), (3.4, -4.91, 1.5), METALX)
a.box((0.90, 0.04, 0.70), (3.4, -4.90, 1.5), CORK)
for dx, dz, c in ((-0.3, 0.15, ("PosterY", (0.98, 0.82, 0.28))), (0.0, 0.2, ("PosterR", (0.88, 0.30, 0.28))),
                  (0.28, 0.1, ("PosterB", (0.30, 0.45, 0.85))), (-0.2, -0.18, ("PaperW", (0.95, 0.95, 0.92))),
                  (0.2, -0.2, ("PosterG", (0.35, 0.70, 0.45)))):
    a.box((0.2, 0.01, 0.26), (3.4 + dx, -4.875, 1.5 + dz), c)
a.box((0.55, 0.03, 0.9), (4.4, -4.91, 1.45), SIGNG)
for z in (1.25, 1.45, 1.65):
    a.box((0.40, 0.01, 0.04), (4.4, -4.89, z), ("SignBar", (0.88, 0.55, 0.30)))
# three blue swivel chairs
for x in (3.3, 4.0, 4.7):
    a.cyl(0.2, 0.2, 0.02, (x, -4.3, 0.01), METALX, 8)
    a.cyl(0.025, 0.025, 0.42, (x, -4.3, 0.23), METALX, 6)
    a.box((0.42, 0.40, 0.04), (x, -4.3, 0.46), CHAIRB)
    a.box((0.40, 0.04, 0.30), (x, -4.50, 0.63), CHAIRB, rot=(-8, 0, 0))
# concrete window bench with two wooden slat backrests
a.box((0.50, 3.8, 0.42), (6.2, -2.5, 0.21), CONC)
for yy in (-3.4, -1.6):
    a.box((0.05, 1.7, 0.30), (6.38, yy, 0.62), SLAT)
a1p = a.finish("A4-001_Props", (0, 0, 0), outline=0.010)
text_on(a1p, "A", (2.6, -0.245, 1.85), (90, 0, 0), 0.28, ("SignWhite", (0.95, 0.95, 0.95)), extrude=0.005, name="Sign_A")

# polished dark floor tint for A4-001 (visual only)
ft = B()
ft.box((7.4, 5.0, 0.01), (2.8, -2.5, 0.005), ("FloorPolished", (0.56, 0.58, 0.63)))
ft.finish("A4-001_FloorTint", (0, 0, 0), outline=0.0)

# ribbed metal ceiling with spot lights (separate object so it can be hidden)
cb = B()
cb.box((7.4, 5.0, 0.02), (2.8, -2.5, 2.82), ("CeilPlate", (0.30, 0.33, 0.38)))
nsl = int(7.4 / 0.14)
for k in range(nsl):
    cb.box((0.06, 5.0, 0.05), (-0.9 + 0.07 + k * 0.14, -2.5, 2.80), ("CeilSlat", (0.60, 0.65, 0.70)))
for sx, sy in ((0.3, -1.5), (2.8, -1.5), (5.3, -1.5), (0.3, -3.6), (2.8, -3.6), (5.3, -3.6)):
    cb.box((0.16, 0.16, 0.03), (sx, sy, 2.78), ("CeilSpot", (1.0, 0.97, 0.85)))
cb.finish("Ceil_A4-001", (0, 0, 0), outline=0.0)

# ---- Online committee room (from the reference photos) ----
cx, cy = -12.0, 2.1            # coffee table centre
SOFAD = ("SofaDark", (0.20, 0.22, 0.28))
LEATHER = ("Leather", (0.13, 0.13, 0.16))
CABK = ("CabBlack", (0.10, 0.10, 0.12))
TVBLUE = ("TVGame", (0.40, 0.65, 0.92))
TWOOD = ("TableLight", (0.90, 0.76, 0.54))
PLANTG = ("PlantGreen", (0.20, 0.50, 0.28))
PLANTD = ("PlantDark", (0.14, 0.38, 0.22))
POTG = ("PotGrey", (0.30, 0.32, 0.36))
KBLUE = ("KitchenBlue", (0.12, 0.20, 0.42))
CTOP = ("CounterTop", (0.80, 0.80, 0.83))
CHG = ("OfficeChairGrey", (0.28, 0.32, 0.38))
FRIDGE = ("Fridge", (0.93, 0.94, 0.96))
OBLUE = ("OnlineBlue", (0.10, 0.17, 0.40))
OWHITE = ("OnlineWhite", (0.95, 0.95, 0.95))
ORED = ("CanRed", (0.85, 0.28, 0.28))
PWOOD = ("PartWood", (0.86, 0.66, 0.38))
MTL = ("Metal", (0.66, 0.72, 0.80))
of = B()
# blue accent wall on the east wall (inner face x = -9.8): plain blue, nothing on it
of.box((0.03, 4.3, 2.7), (-9.815, 2.25, 1.5), OBLUE)
# corner sofa: east-wall run + window-side run
of.box((0.95, 2.9, 0.42), (-10.35, 2.35, 0.21), SOFAD)
of.box((0.25, 2.9, 0.50), (-10.0, 2.35, 0.67), SOFAD)
of.box((2.9, 0.95, 0.42), (-11.85, 3.9, 0.21), SOFAD)
of.box((2.9, 0.25, 0.50), (-11.85, 4.27, 0.67), SOFAD)
for yy in (1.3, 2.35, 3.4):
    of.box((0.8, 0.95, 0.14), (-10.4, yy, 0.49), SOFAD)
for xx in (-12.9, -11.85, -10.8):
    of.box((0.95, 0.8, 0.14), (xx, 3.85, 0.49), SOFAD)
# coffee table (empty)
of.box((1.5, 0.8, 0.05), (cx, cy, 0.41), TWOOD)
for sx in (-1, 1):
    for sy in (-1, 1):
        of.box((0.06, 0.06, 0.39), (cx + sx * 0.68, cy + sy * 0.34, 0.195), TWOOD)
# TV on a black cabinet against the corridor-side partition
of.box((2.6, 0.5, 0.7), (-12.6, 0.38, 0.35), CABK)
of.box((1.35, 0.07, 0.80), (-12.6, 0.40, 1.12), CABK)
of.box((1.25, 0.02, 0.70), (-12.6, 0.45, 1.12), TVBLUE)
# plants
of.cyl(0.18, 0.15, 0.30, (-10.15, 0.45, 0.15), POTG, 8)
of.cyl(0.03, 0.03, 1.2, (-10.15, 0.45, 0.9), ("PlantTrunk", (0.45, 0.33, 0.22)), 6)
for dz, dr in ((0.95, 0.38), (1.35, 0.34), (1.7, 0.28)):
    of.ico(dr, (-10.15, 0.45, dz), PLANTG, sub=1)
of.cyl(0.2, 0.17, 0.3, (-14.2, 0.4, 0.15), POTG, 8)
of.ico(0.42, (-14.2, 0.4, 0.75), PLANTD, sub=1, scale=(1.0, 1.0, 0.7))
# black leather sofa + shelf unit along the partition
of.box((2.0, 0.9, 0.42), (-16.4, 0.65, 0.21), LEATHER)
of.box((2.0, 0.22, 0.55), (-16.4, 0.25, 0.66), LEATHER)
for sx in (-1, 1):
    of.box((0.22, 0.9, 0.62), (-16.4 + sx * 1.0, 0.65, 0.31), LEATHER)
for xx in (-18.45, -17.55):
    for yy in (0.25, 0.55):
        of.box((0.03, 0.03, 1.6), (xx, yy, 0.8), CABK)
for z in (0.4, 0.9, 1.4):
    of.box((0.95, 0.35, 0.03), (-18.0, 0.4, z), CABK)
for k in range(6):
    of.cyl(0.03, 0.03, 0.12, (-18.3 + 0.12 * k, 0.4, 0.96), ORED, 6)
of.box((0.3, 0.2, 0.25), (-17.7, 0.4, 0.55), ("Snack", (0.95, 0.75, 0.25)))
# dining table + chairs pushed up against the north window wall (furthest glass wall from the entrance)
DX, DY = -19.2, 3.55
of.box((3.0, 0.95, 0.05), (DX, DY, 0.75), TWOOD)
for sx in (-1, 1):
    for sy in (-1, 1):
        of.box((0.06, 0.06, 0.72), (DX + sx * 1.4, DY + sy * 0.4, 0.36), TWOOD)
def office_chair(xx, yy, back_dx, back_dy):
    of.box((0.42, 0.42, 0.05), (xx, yy, 0.47), CHG)
    if back_dy:
        of.box((0.42, 0.05, 0.45), (xx, yy + back_dy, 0.75), CHG)
    else:
        of.box((0.05, 0.42, 0.45), (xx + back_dx, yy, 0.75), CHG)
    of.cyl(0.03, 0.03, 0.40, (xx, yy, 0.25), MTL, 6)
    of.box((0.5, 0.06, 0.03), (xx, yy, 0.03), MTL)
    of.box((0.06, 0.5, 0.03), (xx, yy, 0.03), MTL)
for dxo in (-0.9, -0.3, 0.3, 0.9):          # south side of the table (the north side is the window)
    office_chair(DX + dxo, DY - 0.82, 0, -0.22)
office_chair(DX - 1.9, DY, -0.22, 0)       # west end
office_chair(DX + 1.9, DY, 0.22, 0)        # east end
# kitchen along the short west wall: counter + coffee machine + microwave + kettle (fridges stand by the shelf)
KX = -22.57
of.box((0.65, 2.3, 0.9), (KX, 2.7, 0.45), KBLUE)
of.box((0.70, 2.35, 0.04), (KX + 0.02, 2.7, 0.92), CTOP)
of.box((0.30, 0.30, 0.40), (KX, 3.3, 1.14), CABK)
of.box((0.35, 0.45, 0.28), (KX, 2.3, 1.08), CABK)
of.cyl(0.07, 0.06, 0.18, (KX, 1.8, 1.05), ("Kettle", (0.75, 0.78, 0.82)), 8)
of.box((0.62, 0.60, 1.85), (-19.05, 0.42, 0.925), FRIDGE)    # in line with the black shelf (x -18.45..-17.55, y 0.4)
of.box((0.62, 0.60, 1.85), (-19.70, 0.42, 0.925), FRIDGE)
# entrance: wooden door frame + blue "online" sign over the corner gap
for xx in (-23.0, -21.0):
    of.box((0.10, 0.12, 2.3), (xx, 0.0, 1.15), PWOOD)
of.box((2.1, 0.12, 0.10), (-22.0, 0.0, 2.3), PWOOD)
# plain wooden door, swung open 90 degrees into the room (hinged on the west side, next to the fixed panel); fixed panel fills the rest of the gap
DOORW = ("DoorWood", (0.82, 0.66, 0.42))
of.box((0.95, 0.10, 2.3), (-22.525, 0.0, 1.15), PWOOD)
of.box((0.04, 1.0, 2.1), (-22.07, 0.55, 1.05), DOORW)
of.box((0.05, 0.10, 0.04), (-22.03, 0.95, 1.0), MTL)
onf = of.finish("Online_Furn", (0, 0, 0), outline=0.012)

# grey linoleum floor tint + ceiling (ducts, concrete beam, pendant lights); ceiling is its own object
ot = B()
ot.box((13.3, 4.5, 0.01), (-16.35, 2.25, 0.005), ("FloorPolished", (0.56, 0.58, 0.63)))
ot.finish("Online_FloorTint", (0, 0, 0), outline=0.0)
oc = B()
DUCT = ("Duct", (0.70, 0.74, 0.78))
oc.box((13.3, 4.5, 0.03), (-16.35, 2.25, 2.99), ("CeilWhite", (0.92, 0.93, 0.96)))
oc.box((13.3, 0.7, 0.5), (-16.35, 3.5, 2.7), ("Concrete", (0.62, 0.63, 0.66)))
oc.cyl(0.28, 0.28, 13.0, (-16.35, 1.6, 2.6), DUCT, 12, rot=(0, 90, 0))
oc.cyl(0.22, 0.22, 13.0, (-16.35, 2.4, 2.65), DUCT, 12, rot=(0, 90, 0))
for px_ in (-12.5, -16.0, -19.5):
    oc.cyl(0.005, 0.005, 0.7, (px_, 2.3, 2.65), CABK, 4)
    oc.cyl(0.45, 0.45, 0.09, (px_, 2.3, 2.28), ("Pendant", (0.86, 0.88, 0.92)), 14)
    oc.cyl(0.41, 0.41, 0.02, (px_, 2.3, 2.235), ("PendantLight", (1.0, 0.95, 0.80)), 14)
oc.finish("Ceil_Online", (0, 0, 0), outline=0.0)

# ---- printer (Ricoh nook) ----
pr = B()
pr.box((0.9, 0.7, 1.1), (-21.8, -5.8, 0.55), ("Printer", (0.82, 0.84, 0.90)))
pr.box((0.8, 0.5, 0.12), (-21.8, -5.8, 1.16), ("PrinterTop", (0.30, 0.32, 0.40)))
pr.finish("Ricoh_Printer", (0, 0, 0), outline=0.015)

# ---- props (linked copies of the prop pack) ----
def dup(name, loc, rotz=0):
    src = bpy.data.objects[name]
    o = src.copy(); o.data = src.data
    bo.objects.link(o)
    o.location = loc
    o.rotation_euler = (0, 0, math.radians(rotz))
    for c in src.children:
        c2 = c.copy(); c2.data = c.data
        bo.objects.link(c2)
        c2.parent = o
        c2.matrix_parent_inverse = c.matrix_parent_inverse.copy()
    return o
dx_, dy_ = -23.0, -12.4
dup("Desk_Cluttered", (dx_, dy_, 0), 180)
dup("Office_Chair", (dx_, dy_ + 1.3, 0), 0)
dup("Computer", (dx_, dy_ - 0.1, 0.76), 180)
dup("Textbook_Pile_Tall", (dx_ - 0.6, dy_ + 0.1, 0.76), 20)
dup("Coffee_Cup_Kjeldsberg", (dx_ + 0.6, dy_ + 0.1, 0.76))
dup("Can_Isbjorn_Lite", (dx_ + 0.75, dy_ - 0.1, 0.76))
dup("Crumpled_Paper_A", (dx_ + 1.2, dy_ + 1.0, 0))
dup("Can_Tipped", (dx_ - 1.4, dy_ + 1.4, 0), 40)
dup("Paper_Sheets", (dx_ - 1.0, dy_ + 2.0, 0), 30)
# (nothing on the coffee table)
# (nothing on the coffee table)
# (nothing on the coffee table)

# ---- markers ----
for nm, loc in (("PlayerSpawn", (0.75, 1.8, 0)), ("DeskTarget", (dx_, dy_ + 1.3, 0))):
    e = bpy.data.objects.new(nm, None)
    e.empty_display_type = 'ARROWS'; e.empty_display_size = 1.0
    e.location = loc
    bo.objects.link(e)
print("ok", len(bo.objects))
