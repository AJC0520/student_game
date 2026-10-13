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
    [(-31, 0), (-29, 0), (-29, N), (-0.9, N), (-0.9, 3.5), (6.5, 3.5), (6.5, -0.5)],
    [(6.5, -4.5), (6.5, -5), (-0.9, -5),
     (-0.9, -9.5), (4, -9.5), (4, SY), (ARC_CX, SY)] + ARC,
    # A4-138 / Online / A4-145 / A4-147 partitions (north-south)
    [(-23, 0), (-23, N)],
    # A4-145 / A4-147: group rooms; the corridor front is a birch + glass wall (below), separated by a partition at x = -6.7
    [(-9.7, 0.1), (-9.7, N)], [(-3.7, 0.1), (-3.7, N)], [(-6.7, 0.1), (-6.7, N)],   # start behind the birch posts
    # south walls of the room row (doorways left open)
    [(-29, 0), (-26.5, 0)], [(-24.5, 0), (-23, 0)],
    [(-21, 0), (-9.7, 0)],
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
rects = [(-29, 0, -9.7, N), (-9.7, 0, -3.7, N), (-3.7, 0, -0.9, N), (-23.5, -2.5, -0.9, 0), (-0.9, -5, 6.5, 3.5), (-3, -5, -0.9, -2.5)]
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
g.box((x1 - x0, 0.03, 3.4), ((x0 + x1) / 2, GY, 1.75), GLASS)          # corridor glass runs floor to the raised ceiling (z = 3.5)
g.box((x1 - x0 + 0.1, 0.10, 0.10), ((x0 + x1) / 2, GY, 3.45), FRAME)
g.box((x1 - x0 + 0.1, 0.10, 0.10), ((x0 + x1) / 2, GY, 0.05), FRAME)
n = 7
for k in range(n + 1):
    x = x0 + (x1 - x0) * k / n
    g.box((0.10, 0.10, 3.5), (x, GY, 1.75), FRAME)
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
# single door (1.0 m) in the gap y -2.45..-1.45 with a fixed side light next to it (y -2.7..-2.5); the door leaf is its own object
g.box((0.10, 0.10, 3.0), (WXP, -2.5, 1.5), DFR)                     # extra post between side light and door
g.box((0.03, 0.2, 2.0), (WXP, -2.6, 1.1), GLASS)                    # side light
g.box((0.12, 0.2, 0.10), (WXP, -2.6, 0.05), DFR)
dl = B()
# origin = hinge (x = -0.9, y = -2.45, z = 0) so Godot can swing it about its own Y axis; leaf runs along +y
dl.box((0.06, 0.98, 0.10), (0, 0.5, 2.0), DFR)                      # top rail
dl.box((0.06, 0.98, 0.14), (0, 0.5, 0.10), DFR)                     # bottom rail
for yy in (0.05, 0.95):
    dl.box((0.06, 0.08, 2.05), (0, yy, 1.025), DFR)                 # stiles
dl.box((0.02, 0.84, 1.78), (0, 0.5, 1.07), GLASS)                   # glass pane
for xs in (-0.06, 0.06):                                            # pull handles on both faces, handle side = +y
    dl.box((0.03, 0.04, 0.5), (xs, 0.86, 1.0), ("DoorHandle", (0.80, 0.82, 0.88)))
dl.finish("Door_A4Entrance", (WXP, -2.45, 0), outline=0.01)
# card readers: lobby side (yellow back plate so it stands out) and corridor side (for whoever has a card)
rd = B()
RDY = -1.12
rd.box((0.02, 0.26, 0.46), (-0.875, RDY, 1.2), ("LiftBtn", (1.0, 0.8, 0.25)))     # yellow back plate
rd.box((0.06, 0.18, 0.34), (-0.835, RDY, 1.2), ("CabBlack", (0.10, 0.10, 0.12)))  # reader body
rd.box((0.01, 0.12, 0.06), (-0.803, RDY, 1.30), ("Screen", (0.45, 0.85, 0.9)))    # screen strip
rd.box((0.01, 0.10, 0.012), (-0.803, RDY, 1.18), ("DarkFrame", (0.17, 0.17, 0.21)))  # card slot
rd.box((0.01, 0.07, 0.045), (-0.803, RDY, 1.08), ("SignWhite", (0.95, 0.95, 0.95)))  # card icon
rd.box((0.02, 0.2, 0.36), (-0.925, RDY, 1.2), ("CabBlack", (0.10, 0.10, 0.12)))   # corridor-side reader
rd.box((0.01, 0.12, 0.06), (-0.945, RDY, 1.30), ("Screen", (0.45, 0.85, 0.9)))
rd.box((0.01, 0.10, 0.012), (-0.945, RDY, 1.18), ("DarkFrame", (0.17, 0.17, 0.21)))
rd.finish("Card_Readers", (0, 0, 0), outline=0.008)
# east window of A4-001 (x = 6.5, y -4.5..-0.5)
EXX, EY0, EY1 = 6.5, -4.5, -0.5
g.box((0.03, EY1 - EY0, 2.9), (EXX, (EY0 + EY1) / 2, 1.5), GLASS)
g.box((0.10, EY1 - EY0 + 0.1, 0.10), (EXX, (EY0 + EY1) / 2, 2.95), FRAME)
g.box((0.10, EY1 - EY0 + 0.1, 0.10), (EXX, (EY0 + EY1) / 2, 0.05), FRAME)
for yy in (EY0, (EY0 + EY1) / 2, EY1):
    g.box((0.10, 0.12, 3.0), (EXX, yy, 1.5), FRAME)
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
r.finish("Railing", (0, 0, 0), outline=0.012)

# ---- lower level seen through the shaft (not playable) ----
lo = B()
lo.box((x1 - x0, 2.5, 0.1), ((x0 + x1) / 2, -3.75, -4.05), ("LowerFloor", (0.52, 0.56, 0.68)))
for xx in (-19.0, -13.0, -8.0):
    lo.box((1.6, 0.8, 0.75), (xx, -3.75, -3.625), ("LowerDesk", (0.70, 0.55, 0.40)))
    lo.box((0.45, 0.45, 0.45), (xx, -4.4, -3.775), ("LowerChair", (0.45, 0.5, 0.75)))
lo.finish("Lower_Level", (0, 0, 0), outline=0.012)


# ---- group rooms A4-145 / A4-147: birch-framed glass fronts onto the corridor (reference photo) + real interiors ----
BIRCH = ("PartWood", (0.86, 0.66, 0.38))
BIRCHD = ("DoorWood", (0.82, 0.66, 0.42))
FROSTG = ("Frost", (0.93, 0.95, 0.97))
TWOOD = ("TableLight", (0.90, 0.76, 0.54))
GR_ROOMS = (("A4-145", -9.7), ("A4-147", -6.7))      # (name, west edge x); each room is 3.0 m wide, y 0..N behind the front
gf = B()
for room, xw in GR_ROOMS:
    for off in (0.0, 0.46, 1.58, 3.0):                                  # birch posts
        gf.box((0.12, 0.12, 2.55), (xw + off, 0.0, 1.275), BIRCH)
    gf.box((3.12, 0.12, 0.12), (xw + 1.5, 0.0, 2.49), BIRCH)            # head rail over strip, door and window
    gf.box((0.34, 0.03, 2.33), (xw + 0.23, 0.0, 1.265), GLASS)           # narrow glass strip beside the door
    gf.box((0.34, 0.12, 0.10), (xw + 0.23, 0.0, 0.05), BIRCH)
    gf.box((1.30, 0.03, 2.33), (xw + 2.29, 0.0, 1.265), GLASS)           # wide glass panel
    gf.box((1.30, 0.12, 0.10), (xw + 2.29, 0.0, 0.05), BIRCH)
    gf.box((1.30, 0.035, 0.42), (xw + 2.29, 0.0, 1.0), FROSTG)          # frosted stripes on the wide panel
    for zz in (1.30, 1.38):
        gf.box((1.30, 0.035, 0.025), (xw + 2.29, 0.0, zz), FROSTG)
    gf.box((0.34, 0.035, 0.42), (xw + 0.23, 0.0, 1.0), FROSTG)
    gf.box((0.08, 0.012, 0.15), (xw + 1.58, -0.066, 1.35), ("CabBlack", (0.10, 0.10, 0.12)))   # small black plate by the handle
    gf.box((0.05, 0.013, 0.02), (xw + 1.58, -0.067, 1.40), ("SignWhite", (0.95, 0.95, 0.95)))
gr_ob = gf.finish("GroupRoom_Fronts", (0, 0, 0), outline=0.012)
for room, xw in GR_ROOMS:
    # (room name labels over the fronts removed on request)
    d = B()     # door leaf, origin = hinge (west edge, x = xw + 0.53); swings out into the corridor
    d.box((0.98, 0.045, 2.43), (0.49, 0.0, 1.215), BIRCHD)
    for sy in (-1, 1):
        d.box((0.12, 0.05, 0.03), (0.86, sy * 0.045, 1.0), ("DoorHandle", (0.80, 0.82, 0.88)))
    d.finish("Door_" + room, (xw + 0.53, 0.0, 0), outline=0.01)
# interiors: pale ceiling over both rooms, a table with four chairs and a whiteboard in each
grc = B()
grc.box((6.0, 4.5, 0.03), (-6.7, 2.25, 2.99), ("CeilWhite", (0.92, 0.93, 0.96)))
grc.finish("Ceil_GroupRooms", (0, 0, 0), outline=0.0)
gi = B()
GRCH = ("OfficeChairGrey", (0.28, 0.32, 0.38))
for room, xw in GR_ROOMS:
    tx_, ty_ = xw + 1.5, 2.7
    gi.box((1.8, 0.9, 0.05), (tx_, ty_, 0.75), TWOOD)
    for sx in (-1, 1):
        for sy in (-1, 1):
            gi.box((0.06, 0.06, 0.72), (tx_ + sx * 0.84, ty_ + sy * 0.39, 0.36), TWOOD)
    for cxo in (-0.5, 0.5):
        for sy in (-1, 1):
            cyy = ty_ + sy * 0.78
            gi.box((0.42, 0.42, 0.05), (tx_ + cxo, cyy, 0.47), GRCH)
            gi.box((0.42, 0.05, 0.45), (tx_ + cxo, cyy + sy * 0.22, 0.75), GRCH)
            gi.cyl(0.03, 0.03, 0.40, (tx_ + cxo, cyy, 0.25), ("Metal", (0.66, 0.72, 0.80)), 6)
            gi.box((0.5, 0.06, 0.03), (tx_ + cxo, cyy, 0.03), ("Metal", (0.66, 0.72, 0.80)))
            gi.box((0.06, 0.5, 0.03), (tx_ + cxo, cyy, 0.03), ("Metal", (0.66, 0.72, 0.80)))
    gi.box((1.9, 0.03, 1.0), (tx_, N - 0.12, 1.55), ("SignWhite", (0.95, 0.95, 0.95)))     # whiteboard on the north wall
    gi.box((2.0, 0.04, 0.05), (tx_, N - 0.12, 1.03), ("Metal", (0.66, 0.72, 0.80)))
gi.finish("GroupRoom_Furn", (0, 0, 0), outline=0.01)

# ---- corridor ceiling: light wooden slats over a dark backing, recessed downlights and speaker discs (reference photo) ----
cc = B()
SLATW = ("SlatWood", (0.80, 0.76, 0.68))
cc.box((22.3, 2.45, 0.05), (-12.15, -1.25, 3.475), ("CeilPlate", (0.30, 0.33, 0.38)))     # dark backing
for k in range(24):
    cc.box((22.3, 0.05, 0.07), (-12.15, -2.42 + k * 0.1, 3.42), SLATW)                   # slats along the corridor
for k, xl in enumerate((-21.5, -18.5, -15.5, -12.5, -9.5, -6.5)):
    yl = -0.8 if k % 2 == 0 else -1.7
    cc.box((0.24, 0.24, 0.05), (xl, yl, 3.4), ("Duct", (0.70, 0.74, 0.78)))               # recessed downlight housing
    cc.cyl(0.08, 0.08, 0.012, (xl, yl, 3.372), ("CeilSpot", (1.0, 0.97, 0.85)), 10)
for xs in (-20.0, -14.0, -8.0):
    cc.cyl(0.075, 0.075, 0.02, (xs, -1.25, 3.38), ("Metal", (0.66, 0.72, 0.80)), 10)       # round speaker discs
for bx in (-3.0, -13.5):
    cc.box((0.55, 2.45, 0.5), (bx, -1.25, 3.22), ("Concrete", (0.62, 0.63, 0.66)))     # hanging concrete beams (as in the photo)
cc.finish("Ceil_Corridor", (0, 0, 0), outline=0.0)

# ---- corridor enclosure up to the raised ceiling (z = CH): white plaster band over the fronts and ends ----
CH = 3.5
PLASTER = ("Plaster", (0.86, 0.86, 0.82))
pb = B()
pb.box((6.0, 0.2, CH - 2.55), (-6.7, 0.0, (2.55 + CH) / 2), PLASTER)                  # above the group-room fronts (frame top 2.55)
pb.box((13.8, 0.2, CH - 2.55), (-16.6, 0.0, (2.55 + CH) / 2), PLASTER)                # above the Online front and entrance (x -23.5..-9.7), level with the group rooms
pb.box((2.0, 0.2, 0.15), (-22.0, 0.0, 2.475), PLASTER)                                 # fills the gap over the Online door frame (top at 2.4)
pb.box((0.2, 2.5, CH - 3.0), (-23.5, -1.25, (3.0 + CH) / 2), PLASTER)                  # west end of the corridor
pb.box((0.2, 2.5, CH - 3.0), (-0.9, -1.25, (3.0 + CH) / 2), PLASTER)                   # east end, above the lobby glass wall
pb.finish("Plaster_Band", (0, 0, 0), outline=0.0)

# ---- room labels ----
labels = {"A4-138": (-26, 2.2), "Online": (-16, 1.2), "A4-024": (-13, -1.25), "A4-025": (-27, -3), "A4-124": (-25.5, -10), "A4-156": (-9, -10),
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

# ---- Online lounge ----
cx, cy = -16.0, 2.2
on = B()
SOFA = ("Sofa", (0.35, 0.40, 0.65))
for dx in (-3.0, 3.0):
    on.box((2.2, 0.9, 0.45), (cx + dx, cy + 1.2, 0.225), SOFA)
    on.box((2.2, 0.2, 0.5), (cx + dx, cy + 1.7, 0.65), SOFA)
on.box((1.4, 0.8, 0.4), (cx, cy - 0.3, 0.2), ("TableWood", (0.86, 0.60, 0.34)))
on.finish("Online_Lounge", (0, 0, 0), outline=0.015)

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
dup("Coffee_Cup_Kjeldsberg", (cx, cy - 0.3, 0.4))
dup("Can_Dahls_Style", (cx + 0.4, cy - 0.2, 0.4))
dup("Matpakke_Open", (cx - 0.3, cy - 0.4, 0.4))

# ---- markers ----
for nm, loc in (("PlayerSpawn", (0.75, 1.8, 0)), ("DeskTarget", (dx_, dy_ + 1.3, 0))):
    e = bpy.data.objects.new(nm, None)
    e.empty_display_type = 'ARROWS'; e.empty_display_size = 1.0
    e.location = loc
    bo.objects.link(e)
print("ok", len(bo.objects))
