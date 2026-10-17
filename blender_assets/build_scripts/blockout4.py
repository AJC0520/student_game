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
    # A4-145 / A4-147: group rooms; the corridor front is a birch + glass wall (below), separated by a partition at x = -6.7
    [(-9.7, 0.1), (-9.7, N)], [(-3.7, 0.1), (-3.7, N)], [(-6.7, 0.1), (-6.7, N)],   # start behind the birch posts
    # south walls of the room row (doorways left open)
    [(-29, 0), (-23, 0)],      # the doorway to A4-138 is walled up (that room is not modelled)
    # corridor south wall + closed strip behind it
    # the shaft's west (x = -23.5), south (y = -5) and east (x = -3) sides are glass, built in big_room.py
    [(-23.5, -5), (-23.5, -6.4)],
    # A4-124 | A4-156 divider
    [(-20, -5), (-20, arc_y(-20))],
    # Heis / lift-lobby walls (traced from the screenshot)
    [(-0.9, 0), (-0.15, 0)], [(1.65, 0), (6.5, 0)], [(2.4, 0), (2.4, 3.5)],
    # east cross-corridor wall with doorway to A4-001 (gap -2.7..-1.4) and open lobby (0.5..3.5)
    [(-0.9, 0), (-0.9, 3.5)],
]

RIBBON = []     # curved south wall segments that get a ribbon window (see big_room.py)
ARCSET = set(ARC) | {(ARC_CX, SY), (4, SY), (4, -9.5)}
walls = B()
for pl in walls_m:
    for (x0, y0), (x1, y1) in zip(pl, pl[1:]):
        L = math.hypot(x1 - x0, y1 - y0)
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        if (x0, y0) in ARCSET and (x1, y1) in ARCSET:
            # ribbon window: solid sill below 0.95 and header above 2.45, glass is added by big_room.py
            walls.box((L + TH, TH, 0.95), ((x0 + x1) / 2, (y0 + y1) / 2, 0.475), WALL, rot=(0, 0, ang))
            walls.box((L + TH, TH, H - 2.45), ((x0 + x1) / 2, (y0 + y1) / 2, (2.45 + H) / 2), WALL, rot=(0, 0, ang))
            RIBBON.append(((x0 + x1) / 2, (y0 + y1) / 2, L, ang))
        else:
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
for xs in (-0.06, 0.06):                                            # pull handles on both faces, handle side = +y
    dl.box((0.03, 0.04, 0.5), (xs, 0.86, 1.0), ("DoorHandle", (0.80, 0.82, 0.88)))
dlo = dl.finish("Door_A4Entrance", (WXP, -2.45, 0), outline=0.01)
dg = B()                                                            # glass pane: its own child object, no outline shell (that would show as a dark sheet)
dg.box((0.02, 0.84, 1.78), (0, 0.5, 1.07), GLASS)
dgo = dg.finish("Door_A4Entrance_Glass", (0, 0, 0), outline=0.0)
dgo.parent = dlo
# card readers: lobby side (yellow back plate so it stands out) and corridor side (for whoever has a card)
rd = B()
# Mirror the paired readers to the other side of the entrance along the lobby wall.
RDY = -3.00
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


# ---- group rooms A4-145 / A4-147: birch-framed glass fronts onto the corridor (reference photo) + real interiors ----
BIRCH = ("PartWood", (0.86, 0.66, 0.38))
BIRCHD = ("DoorWood", (0.82, 0.66, 0.42))
FROSTG = ("Frost", (0.93, 0.95, 0.97))
TWOOD = ("TableLight", (0.90, 0.76, 0.54))
GR_ROOMS = (("A4-145", -9.7), ("A4-147", -6.7))      # (name, west edge x); each room is 3.0 m wide, y 0..N behind the front
gf = B()
gg = B()     # frosted panes, finished without outline (opaque on purpose: you cannot see into the rooms)
FROSTP = ("FrostPane", (0.78, 0.83, 0.86))
for room, xw in GR_ROOMS:
    for off in (0.0, 0.46, 1.58, 3.0):                                  # birch posts
        gf.box((0.12, 0.12, 2.55), (xw + off, 0.0, 1.275), BIRCH)
    gf.box((3.12, 0.12, 0.12), (xw + 1.5, 0.0, 2.49), BIRCH)            # head rail over strip, door and window
    gg.box((0.34, 0.03, 2.33), (xw + 0.23, 0.0, 1.265), FROSTP)           # narrow glass strip beside the door
    gf.box((0.34, 0.12, 0.10), (xw + 0.23, 0.0, 0.05), BIRCH)
    gg.box((1.30, 0.03, 2.33), (xw + 2.29, 0.0, 1.265), FROSTP)           # wide glass panel
    gf.box((1.30, 0.12, 0.10), (xw + 2.29, 0.0, 0.05), BIRCH)
    gf.box((1.30, 0.035, 0.42), (xw + 2.29, 0.0, 1.0), FROSTG)          # frosted stripes on the wide panel
    for zz in (1.30, 1.38):
        gf.box((1.30, 0.035, 0.025), (xw + 2.29, 0.0, zz), FROSTG)
    gf.box((0.34, 0.035, 0.42), (xw + 0.23, 0.0, 1.0), FROSTG)
    gf.box((0.08, 0.012, 0.15), (xw + 1.58, -0.066, 1.35), ("CabBlack", (0.10, 0.10, 0.12)))   # small black plate by the handle
    gf.box((0.05, 0.013, 0.02), (xw + 1.58, -0.067, 1.40), ("SignWhite", (0.95, 0.95, 0.95)))
gr_ob = gf.finish("GroupRoom_Fronts", (0, 0, 0), outline=0.012)
gg.finish("GroupRoom_FrontsGlass", (0, 0, 0), outline=0.0)
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
# (group-room furniture removed: the rooms are not visible from outside, saves triangles)

# ---- corridor ceiling: light wooden slats over a dark backing, recessed downlights and speaker discs (reference photo) ----
cc = B()
SLATW = ("SlatWood", (0.80, 0.76, 0.68))
cc.box((22.5, 2.45, 0.05), (-12.25, -1.25, 3.475), ("CeilPlate", (0.30, 0.33, 0.38)))     # dark backing
for k in range(24):
    cc.box((22.5, 0.05, 0.07), (-12.25, -2.42 + k * 0.1, 3.42), SLATW)                   # slats along the corridor
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
# red bell pepper on the coffee table (own object so it can be moved / removed easily)
PEP_RED = ("PepperRed", (0.88, 0.12, 0.14))
PEP_GRN = ("PepperGreen", (0.22, 0.55, 0.20))
pp = B()
PX, PY, PZ = cx + 0.55, cy + 0.2, 0.435               # on the table top (table top is at z 0.435)
pp.ico(0.062, (PX, PY, PZ + 0.060), PEP_RED, sub=1, scale=(1.0, 1.0, 0.95))          # the body
for ang in (0, 120, 240):                                                             # three rounded lobes at the bottom
    pp.ico(0.034, (PX + 0.036 * math.cos(math.radians(ang)), PY + 0.036 * math.sin(math.radians(ang)), PZ + 0.026), PEP_RED, sub=1)
pp.cyl(0.026, 0.020, 0.016, (PX, PY, PZ + 0.116), PEP_GRN, 6)                        # green cap
pp.cyl(0.011, 0.009, 0.040, (PX + 0.004, PY, PZ + 0.142), PEP_GRN, 6, rot=(0, 10, 0))  # stalk
pp.finish("Prop_Pepper", (0, 0, 0), outline=0.006)

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
# (removed: desk props, the big room is now the study hall) dup("Desk_Cluttered", (dx_, dy_, 0), 180)
# (removed: desk props, the big room is now the study hall) dup("Office_Chair", (dx_, dy_ + 1.3, 0), 0)
# (removed: desk props, the big room is now the study hall) dup("Computer", (dx_, dy_ - 0.1, 0.76), 180)
# (removed: desk props, the big room is now the study hall) dup("Textbook_Pile_Tall", (dx_ - 0.6, dy_ + 0.1, 0.76), 20)
# (removed: desk props, the big room is now the study hall) dup("Coffee_Cup_Kjeldsberg", (dx_ + 0.6, dy_ + 0.1, 0.76))
# (removed: desk props, the big room is now the study hall) dup("Can_Isbjorn_Lite", (dx_ + 0.75, dy_ - 0.1, 0.76))
# (removed: desk props, the big room is now the study hall) dup("Crumpled_Paper_A", (dx_ + 1.2, dy_ + 1.0, 0))
# (removed: desk props, the big room is now the study hall) dup("Can_Tipped", (dx_ - 1.4, dy_ + 1.4, 0), 40)
# (removed: desk props, the big room is now the study hall) dup("Paper_Sheets", (dx_ - 1.0, dy_ + 2.0, 0), 30)
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

# ---- the big open study hall (A4-124 + the west end of the corridor), from the reference photos ----
# Appended to the end of the level scripts (blockout4*.py) by the patch; uses their builder B, materials and helpers.
# Contents: slat + concrete ceiling with a lowered white soffit over the ribbon window, ribbon window with a long desk
# and chairs along the curved south wall, round and long black tables with chairs, a teal sofa, a book-stuffed birch
# shelf, concrete columns, a cream radiator tube and handrail along the big west window, and the birch-panelled divider
# wall (cork board, fire extinguisher, door, vents) between A4-124 and A4-156.

CHAIRB = ("ChairBlack", (0.12, 0.12, 0.15))
TABLEB = ("TableBlack", (0.10, 0.10, 0.12))
TEALS = ("TealSofa", (0.28, 0.50, 0.58))
BIRCHP = ("BirchPanel", (0.90, 0.74, 0.46))
SOFFIT = ("Soffit", (0.84, 0.87, 0.90))
CREAM = ("Cream", (0.88, 0.82, 0.62))
BMETAL = ("Metal", (0.66, 0.72, 0.80))
BCONC = ("Concrete", (0.62, 0.63, 0.66))
BWOOD = ("PartWood", (0.86, 0.66, 0.38))
BOOKS = [("Red", (0.88, 0.25, 0.25)), ("Blue", (0.28, 0.45, 0.85)), ("Green", (0.30, 0.68, 0.40)), ("Purple", (0.58, 0.40, 0.80)),
         ("Pink", (1.0, 0.55, 0.65)), ("Teal", (0.20, 0.62, 0.62)), ("Orange", (0.98, 0.58, 0.20)), ("Yellow", (1.0, 0.82, 0.25)),
         ("Paper", (0.98, 0.97, 0.93))]

def _gb(bld, G, size, loc, mat, rot=(0, 0, 0)):
    """Box of `size` centred at `loc` inside the frame G (4x4 matrix)."""
    M = G @ Matrix.Translation(loc) @ Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
    r = bmesh.ops.create_cube(bld.bm, size=1.0, matrix=M)
    return bld._tag(r['verts'], mat)

def _frame(x, y, yaw_deg=0.0, z=0.0):
    return Matrix.Translation((x, y, z)) @ Euler((0, 0, math.radians(yaw_deg))).to_matrix().to_4x4()

def _chair(bld, x, y, yaw, mat=CHAIRB):
    """School chair seen from above at (x, y); +Y of the frame is the direction it faces."""
    G = _frame(x, y, yaw)
    _gb(bld, G, (0.42, 0.42, 0.05), (0, 0, 0.46), mat)
    _gb(bld, G, (0.40, 0.05, 0.40), (0, -0.20, 0.73), mat)
    for sx in (-0.17, 0.17):
        for sy in (-0.17, 0.17):
            _gb(bld, G, (0.03, 0.03, 0.44), (sx, sy, 0.22), BMETAL)

def _round_table(bld, x, y, with_chairs=True):
    bld.cyl(0.48, 0.48, 0.04, (x, y, 0.74), TABLEB, 16)
    bld.cyl(0.04, 0.04, 0.70, (x, y, 0.37), BMETAL, 8)
    bld.cyl(0.28, 0.28, 0.025, (x, y, 0.0125), TABLEB, 12)
    if with_chairs:
        for th in (20, 110, 200, 290):
            a = math.radians(th)
            _chair(bld, x + 0.78 * math.cos(a), y + 0.78 * math.sin(a), th + 90)

def _long_table(bld, x, y, length=2.8, width=0.9, chairs_per_side=3, sides=(-1, 1)):
    """Long black table running along Y with chairs on both long sides."""
    bld.box((width, length, 0.04), (x, y, 0.74), TABLEB)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bld.box((0.05, 0.05, 0.72), (x + sx * (width / 2 - 0.05), y + sy * (length / 2 - 0.08), 0.36), TABLEB)
    for k in range(chairs_per_side):
        yy = y - length / 2 + (k + 0.5) * length / chairs_per_side
        if -1 in sides:
            _chair(bld, x - width / 2 - 0.3, yy, -90)
        if 1 in sides:
            _chair(bld, x + width / 2 + 0.3, yy, 90)

# ================================================================ furniture
bf = B()
# two group tables: the long black one in front of the atrium glass bay (teal sofa behind it) and one along the west window
_long_table(bf, -24.9, -3.75, 2.4, 0.9, 2, sides=(-1,))                              # black table in front of the atrium glass bay
_long_table(bf, -29.3, -3.75, 1.6, 0.9, 2)                                       # second group table along the big west window, 4 chairs around it
# teal sofa against the atrium glass bay, facing west (the table stands in front of it)
G = _frame(-23.95, -3.75, 90)
_gb(bf, G, (2.2, 0.85, 0.44), (0, 0, 0.22), TEALS)
_gb(bf, G, (2.2, 0.20, 0.42), (0, -0.33, 0.65), TEALS)
for sx in (-1.0, 1.0):
    _gb(bf, G, (0.2, 0.85, 0.55), (sx * 1.1, 0, 0.45), TEALS)
# a second sofa group against the birch-panelled divider wall (west face x = -20.12), centred on the wall
G = _frame(-20.55, -9.5, 90)
_gb(bf, G, (2.1, 0.85, 0.44), (0, 0, 0.22), TEALS)
_gb(bf, G, (2.1, 0.20, 0.42), (0, -0.33, 0.65), TEALS)
for sx in (-1.0, 1.0):
    _gb(bf, G, (0.2, 0.85, 0.55), (sx * 1.05, 0, 0.45), TEALS)
_long_table(bf, -21.5, -9.5, 2.1, 0.9, 2, sides=(-1,))                    # table in front of it with two chairs
# birch bookshelf stuffed with books against the concrete column (west face), a stack of papers on top
G = _frame(-24.45, -5.75, 90)
for sx in (-0.45, 0.45):
    _gb(bf, G, (0.03, 0.3, 1.8), (sx, 0, 0.9), BWOOD)
for z in (0.05, 0.42, 0.78, 1.14, 1.5, 1.79):
    _gb(bf, G, (0.93, 0.3, 0.03), (0, 0, z), BWOOD)
_gb(bf, G, (0.9, 0.02, 1.8), (0, -0.14, 0.9), BWOOD)
rnd = random.Random(7)
for zs in (0.07, 0.44, 0.80, 1.16, 1.52):
    xx = -0.41
    while True:
        w = rnd.uniform(0.04, 0.065)
        if xx + w > 0.41:
            break
        h = rnd.uniform(0.20, 0.27)
        mat = BOOKS[rnd.randrange(len(BOOKS))]
        _gb(bf, G, (w, 0.2, h), (xx + w / 2, 0.0, zs + 0.02 + h / 2), mat)
        xx += w + 0.008
for k in range(4):                                                         # a loose stack of papers / books on top, neatly offset
    _gb(bf, G, (0.34 - 0.03 * k, 0.24, 0.035), (-0.1 + 0.03 * k, 0.0, 1.835 + 0.04 * k), BOOKS[(k * 3) % len(BOOKS)])
bf.finish("BigRoom_Furn", (0, 0, 0), outline=0.01)

# ribbon window along the curved south wall: long birch desk + a row of chairs
RW = [(ARC_CX, SY)] + ARC
CORNER_COL = (-30.35, -7.85)     # round concrete column in the corner where the west window meets the curved wall
CORNER_R = 0.32
br = B()
for seg_i, ((xa, ya), (xb, yb)) in enumerate(zip(RW, RW[1:])):
    if seg_i == len(RW) - 2:
        # last piece: trim it so the desk ends flush against the corner column instead of running into it
        ux, uy = xb - xa, yb - ya
        ul = math.hypot(ux, uy)
        ux, uy = ux / ul, uy / ul
        s_end = (CORNER_COL[0] - xa) * ux + (CORNER_COL[1] - ya) * uy - CORNER_R
        xb, yb = xa + ux * s_end, ya + uy * s_end
    mx, my = (xa + xb) / 2, (ya + yb) / 2
    L = math.hypot(xb - xa, yb - ya)
    ang = math.degrees(math.atan2(yb - ya, xb - xa))
    nx, ny = ARC_CX - mx, ARC_CY - my
    nl = math.hypot(nx, ny)
    nx, ny = nx / nl, ny / nl                                              # inward normal (towards the arc's centre)
    G = _frame(mx + nx * 0.42, my + ny * 0.42, ang)
    _gb(br, G, (L + 0.02, 0.6, 0.04), (0, 0, 0.74), BWOOD)                 # desk top
    _gb(br, G, (0.04, 0.5, 0.70), (L / 2, 0, 0.35), BWOOD)                 # support panels at the joints
    yaw = math.degrees(math.atan2(nx, -ny))
    cnt = max(1, int(L / 1.3))
    for k in range(cnt):
        t = (k + 0.5) / cnt - 0.5
        _chair(br, mx + nx * 1.0 + (xb - xa) * t, my + ny * 1.0 + (yb - ya) * t, yaw)

# ---- A4-156 (the larger room east of the divider): the ribbon window continues along the straight south wall and round
# the east wall, with the same long birch built-in desk and a row of chairs; group tables fill the middle of the room.
S_RUN = [(ARC_CX, SY, 4.0 - 0.72, SY, 0.0, 1.0)]                    # (x0, y0, x1, y1, inward normal x, y): south wall, desk ends where the east desk starts
E_RUN = [(4.0, SY + 0.72, 4.0, -9.5 - 0.15, -1.0, 0.0)]            # east wall, from the south-east corner up to the stub wall
N_RUN = [(-19.7, -5.0, -3.4, -5.0, 0.0, -1.0)]                      # the glass wall towards the hall (the shaft behind it): the same desk and chairs
for (xa, ya, xb, yb, nx, ny) in S_RUN + E_RUN + N_RUN:
    mx, my = (xa + xb) / 2, (ya + yb) / 2
    L = math.hypot(xb - xa, yb - ya)
    ang = math.degrees(math.atan2(yb - ya, xb - xa))
    G = _frame(mx + nx * 0.42, my + ny * 0.42, ang)
    _gb(br, G, (L, 0.6, 0.04), (0, 0, 0.74), BWOOD)                      # desk top
    for k in range(int(L / 3.0) + 2):                                   # support panels every ~3 m, like the curved run
        t = -L / 2 + 0.02 + k * (L - 0.04) / max(1, int(L / 3.0) + 1)
        _gb(br, G, (0.04, 0.5, 0.70), (t, 0, 0.35), BWOOD)
    yaw = math.degrees(math.atan2(nx, -ny))
    cnt = max(1, int(L / 1.5))
    for k in range(cnt):
        if k % 4 == 3:                                                  # leave a gap here and there
            continue
        t = (k + 0.5) / cnt - 0.5
        _chair(br, mx + nx * 1.0 + (xb - xa) * t, my + ny * 1.0 + (yb - ya) * t, yaw)
br.finish("BigRoom_Desk", (0, 0, 0), outline=0.01)


# group tables in the middle of A4-156: two rows, long black tables with chairs on both sides and round tables with four
bt = B()
for tx in (-17.5, -13.5, -9.5, -5.5):
    _long_table(bt, tx, -8.4, 2.4, 0.9, 2)
_long_table(bt, -13.0, -11.4, 2.4, 0.9, 2)
_long_table(bt, -5.0, -11.4, 2.4, 0.9, 2)
for (tx, ty) in ((-16.8, -11.4), (-9.0, -11.4), (-1.0, -11.4), (1.4, -11.4)):
    _round_table(bt, tx, ty)
bt.finish("Scenery_GroupTables", (0, 0, 0), outline=0.01)          # not playable: no collider (name does not start with BigRoom_)

# ================================================================ walls, window dressing
bw = B()
# birch-panelled divider wall (west face of x = -20): panels with seams, plaster band above, board, extinguisher, door, vents
DX = -20.12
y0_, y1_ = -5.2, -13.8
bw.box((0.03, y0_ - y1_, 2.4), (DX, (y0_ + y1_) / 2, 1.2), BIRCHP)
for yy in (-6.9, -8.7, -10.5, -12.0):
    bw.box((0.035, 0.012, 2.4), (DX - 0.002, yy, 1.2), ("PanelSeam", (0.62, 0.45, 0.25)))
bw.box((0.03, y0_ - y1_, 0.65), (DX, (y0_ + y1_) / 2, 2.725), ("Plaster", (0.86, 0.86, 0.82)))
bw.box((0.04, y0_ - y1_, 0.04), (DX - 0.005, (y0_ + y1_) / 2, 2.4), BWOOD)
# (cork board, posters, fire extinguisher, door, room plate and vents removed on request; the bare panelled wall stays)
# cream radiator tube + wooden handrail along the big west window (x = -31, y -8..0), concrete columns
bw.cyl(0.10, 0.10, 7.7, (-30.8, -4.0, 0.12), CREAM, 10, rot=(90, 0, 0))
bw.box((0.05, 7.8, 0.06), (-30.9, -4.0, 1.0), BWOOD)
for yy in (-7.8, -4.0, -0.2):
    bw.box((0.1, 0.05, 0.05), (-30.85, yy, 1.0), BMETAL)
for (cx_, cy_) in (CORNER_COL, (-23.8, -12.2)):
    bw.cyl(CORNER_R, CORNER_R, 3.0, (cx_, cy_, 1.5), BCONC, 16)
bw.finish("BigRoom_Wall", (0, 0, 0), outline=0.01)

# the north wall of the hall (y = 0): the doorway to the unmodelled room A4-138 is walled up (see the wall list in the level script);
# it gets the panelled wall from the reference photo: birch panelling, plaster band, vents, cork board, fire extinguisher and a closed door
bn = B()
NX0, NX1 = -30.85, -23.05          # up to the Online door frame post, so no blue wall shows in between
NY = -0.1 - 0.015
bn.box((NX1 - NX0, 0.03, 2.55), ((NX0 + NX1) / 2, NY, 1.275), BIRCHP)                      # same height as the Online / group-room fronts (2.55)
for xx in (-29.5, -28.3, -26.5, -25.2, -23.9):
    bn.box((0.012, 0.035, 2.4), (xx, NY - 0.002, 1.2), ("PanelSeam", (0.62, 0.45, 0.25)))
bn.box((NX1 - NX0, 0.03, 0.47), ((NX0 + NX1) / 2, NY, 2.785), ("Plaster", (0.86, 0.86, 0.82)))
bn.box((NX1 - NX0, 0.04, 0.04), ((NX0 + NX1) / 2, NY - 0.005, 2.55), BWOOD)
for vx in (-29.6, -26.8):
    bn.box((0.5, 0.02, 0.25), (vx, NY - 0.015, 2.78), BMETAL)
    for i_ in range(4):
        for j_ in range(2):
            bn.box((0.05, 0.022, 0.05), (vx - 0.18 + i_ * 0.12, NY - 0.025, 2.73 + j_ * 0.1), ("Dark", (0.2, 0.22, 0.3)))
bn.box((1.3, 0.025, 0.8), (-28.2, NY - 0.02, 1.5), ("Cork", (0.78, 0.58, 0.36)))                         # cork board with posters
bn.box((1.36, 0.03, 0.04), (-28.2, NY - 0.022, 1.92), BMETAL)
bn.box((1.36, 0.03, 0.04), (-28.2, NY - 0.022, 1.08), BMETAL)
for (px_, pz_, ph_, pc_) in ((-28.65, 1.62, 0.3, BOOKS[1]), (-28.2, 1.45, 0.34, BOOKS[7]), (-27.75, 1.65, 0.28, BOOKS[0]), (-28.55, 1.28, 0.22, BOOKS[4]), (-27.85, 1.25, 0.26, BOOKS[3])):
    bn.box((0.24, 0.012, ph_), (px_, NY - 0.037, pz_), pc_)
bn.cyl(0.07, 0.07, 0.42, (-26.9, NY - 0.1, 0.3), ("Red", (0.88, 0.25, 0.25)), 8)                         # fire extinguisher + sign
bn.cyl(0.03, 0.03, 0.05, (-26.9, NY - 0.1, 0.55), ("Dark", (0.2, 0.22, 0.3)), 6)
bn.box((0.18, 0.012, 0.18), (-26.9, NY - 0.03, 0.95), ("Red", (0.88, 0.25, 0.25)))
bn.box((1.0, 0.03, 2.1), (-25.6, NY - 0.02, 1.05), ("DoorWood", (0.82, 0.66, 0.42)))                       # closed door
bn.box((1.08, 0.04, 0.05), (-25.6, NY - 0.022, 2.13), BWOOD)
bn.box((0.12, 0.05, 0.025), (-25.2, NY - 0.05, 1.0), ("DoorHandle", (0.80, 0.82, 0.88)))
bn.box((0.12, 0.012, 0.16), (-24.85, NY - 0.03, 1.4), ("CabBlack", (0.10, 0.10, 0.12)))                   # room plate
bn.finish("BigRoom_WallN", (0, 0, 0), outline=0.01)

# the corridor's west end seen from the hall: board-formed concrete column + lintel and a dark-framed glass bay with a handrail (atrium shaft)
ba = B()
CDARK = ("ConcDark", (0.50, 0.51, 0.54))
ba.box((0.8, 1.5, 3.0), (-23.9, -5.75, 1.5), BCONC)                        # rectangular column, west face at x = -24.3
for zz in (0.9, 1.9, 2.6):
    ba.box((0.02, 1.5, 0.012), (-24.305, -5.75, zz), CDARK)                  # form-work seams
ba.box((0.012, 0.012, 3.0), (-24.305, -5.75, 1.5), CDARK)
ba.box((0.7, 2.6, 0.55), (-23.85, -3.75, 2.725), BCONC)                    # concrete lintel over the glass bay
ba.finish("BigRoom_Column", (0, 0, 0), outline=0.01)
ag = B()
GF = ("GlassFrame", (0.22, 0.25, 0.32))
ag.box((0.03, 2.5, 2.45), (-23.5, -3.75, 1.275), GLASS)
for yy in (-5.0, -3.75, -2.5):
    ag.box((0.10, 0.10, 2.45), (-23.5, yy, 1.275), GF)
ag.box((0.10, 2.6, 0.08), (-23.5, -3.75, 2.45), GF)
ag.box((0.10, 2.6, 0.08), (-23.5, -3.75, 0.04), GF)
ag.box((0.05, 2.5, 0.06), (-23.58, -3.75, 1.0), BWOOD)                      # wooden handrail
for yy in (-4.9, -3.75, -2.6):
    ag.box((0.08, 0.06, 0.12), (-23.57, yy, 1.0), BMETAL)
ag.finish("Glass_Wall_Atrium", (0, 0, 0), outline=0.0)       # no outline shell on glass: it would show up as a dark sheet behind the pane
# the shaft behind it: its south wall (y = -5) is glazed like the corridor wall around the corner, with a concrete ceiling at z = 3.5
sg = B()
sx0, sx1 = -23.5, -3.0
sg.box((sx1 - sx0, 0.03, 3.4), ((sx0 + sx1) / 2, -5.0, 1.75), GLASS)
sg.box((sx1 - sx0 + 0.1, 0.10, 0.10), ((sx0 + sx1) / 2, -5.0, 3.45), GF)
sg.box((sx1 - sx0 + 0.1, 0.10, 0.10), ((sx0 + sx1) / 2, -5.0, 0.05), GF)
for k in range(8):
    sg.box((0.10, 0.10, 3.5), (sx0 + (sx1 - sx0) * k / 7, -5.0, 1.75), GF)
# east end of the shaft (x = -3) is glass too, so you can see all the way through to the lobby and A4-001
sg.box((0.03, 2.5, 3.4), (-3.0, -3.75, 1.75), GLASS)
for yy in (-5.0, -3.75, -2.5):
    sg.box((0.10, 0.10, 3.5), (-3.0, yy, 1.75), GF)
sg.box((0.10, 2.6, 0.10), (-3.0, -3.75, 3.45), GF)
sg.box((0.10, 2.6, 0.10), (-3.0, -3.75, 0.05), GF)
sg.finish("Glass_Wall_Shaft", (0, 0, 0), outline=0.0)
sc_ = B()
sc_.box((sx1 - sx0, 2.5, 0.03), ((sx0 + sx1) / 2, -3.75, 3.515), BCONC)
sc_.finish("Ceil_Shaft", (0, 0, 0), outline=0.0)

# ribbon window glass (the walls were cut open between z 0.95 and 2.45 by the wall loop)
rg = B()
for (mx, my, L, ang) in RIBBON:
    rg.box((L + 0.02, 0.03, 1.5), (mx, my, 1.7), GLASS, rot=(0, 0, ang))
    rg.box((L + 0.02, 0.10, 0.06), (mx, my, 0.97), ("GlassFrame", (0.22, 0.25, 0.32)), rot=(0, 0, ang))
    rg.box((L + 0.02, 0.10, 0.06), (mx, my, 2.43), ("GlassFrame", (0.22, 0.25, 0.32)), rot=(0, 0, ang))
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    for t in (-0.5, 0.0):
        rg.box((0.06, 0.10, 1.5), (mx + ca * L * t, my + sa * L * t, 1.7), ("GlassFrame", (0.22, 0.25, 0.32)), rot=(0, 0, ang))
rg.finish("Glass_Wall_Ribbon", (0, 0, 0), outline=0.0)

# ================================================================ ceiling
bc = B()
BPLATE = ("CeilPlate", (0.30, 0.33, 0.38))
bc.box((7.5, 14.4, 0.03), (-27.25, -7.2, 2.985), BPLATE)                       # dark backing over the west hall
bc.box((3.5, 9.4, 0.03), (-21.75, -9.7, 2.985), BPLATE)                        # ... and south of the corridor end
# wooden slats over the whole hall, running along X like the corridor's, trimmed to the room outline
SLAT_PITCH = 0.1
n_slats = int(14.2 / SLAT_PITCH)
for k in range(n_slats):
    ys = -0.05 - k * SLAT_PITCH
    if ys > -8.0:
        x_w = -30.95                                                              # west window
    else:
        d2 = ARC_R ** 2 - (ARC_CY - ys) ** 2
        if d2 <= 0:
            continue
        x_w = ARC_CX - math.sqrt(d2)                                              # where the curved south wall is at this y
    x_e = -23.55 if ys > -5.0 else -20.05                                        # corridor end / divider wall
    if x_e - x_w < 0.2:
        continue
    bc.box((x_e - x_w, 0.05, 0.06), ((x_e + x_w) / 2, ys, 2.93), ("SlatWood", (0.80, 0.76, 0.68)))
for (xa, ya), (xb, yb) in zip(RW, RW[1:]):                                       # lowered white soffit over the ribbon desk
    mx, my = (xa + xb) / 2, (ya + yb) / 2
    L = math.hypot(xb - xa, yb - ya)
    ang = math.degrees(math.atan2(yb - ya, xb - xa))
    nx, ny = ARC_CX - mx, ARC_CY - my
    nl = math.hypot(nx, ny)
    nx, ny = nx / nl, ny / nl
    G = _frame(mx + nx * 0.85, my + ny * 0.85, ang)
    _gb(bc, G, (L + 0.05, 1.7, 0.45), (0, 0, 2.775), SOFFIT)
    _gb(bc, G, (L * 0.8, 0.07, 0.04), (0, -0.2, 2.53), ("CeilSpot", (1.0, 0.97, 0.85)))   # linear LED fixture under the soffit

for (xa, ya, xb, yb, nx, ny) in S_RUN + E_RUN:                              # the same lowered white soffit over the new window desks
    mx, my = (xa + xb) / 2, (ya + yb) / 2
    L = math.hypot(xb - xa, yb - ya)
    ang = math.degrees(math.atan2(yb - ya, xb - xa))
    G = _frame(mx + nx * 0.85, my + ny * 0.85, ang)
    _gb(bc, G, (L + 0.3, 1.7, 0.45), (0, 0, 2.775), SOFFIT)
    _gb(bc, G, (L * 0.8, 0.07, 0.04), (0, -0.2, 2.53), ("CeilSpot", (1.0, 0.97, 0.85)))
for (lx, ly) in ((-29.0, -2.5), (-29.0, -6.5), (-25.5, -1.5), (-25.5, -5.5), (-24.5, -9.5), (-22.0, -7.0), (-22.0, -11.5), (-27.0, -9.5)):
    bc.box((0.24, 0.24, 0.05), (lx, ly, 2.95), ("Duct", (0.70, 0.74, 0.78)))                 # round downlights in square housings
    bc.cyl(0.08, 0.08, 0.012, (lx, ly, 2.92), ("CeilSpot", (1.0, 0.97, 0.85)), 10)
bc.finish("Ceil_BigRoom", (0, 0, 0), outline=0.0)

# ================================================================ A4-156: ceiling to match the study hall + the door into the room
# ceiling like the hall's: dark backing plate, wooden slats along X at z = 2.93, round downlights in square housings;
# the lowered white soffits over the window desks were added above with the desks.
b56 = B()
PLATE56 = ("CeilPlate", (0.30, 0.33, 0.38))
b56.box((16.05, 9.4, 0.03), (-9.025, -9.7, 2.985), PLATE56)                 # x -17 .. -0.95, y -14.4 .. -5
b56.box((3.0, 9.0, 0.03), (-18.55, -9.65, 2.985), PLATE56)                   # x -20.05 .. -17 (up to the curved wall)
b56.box((4.9, 4.9, 0.03), (1.5, -11.95, 2.985), PLATE56)                      # the bay east of x = -0.95 (y -14.4 .. -9.5)
for k in range(int(9.4 / 0.1)):
    ys = -5.05 - k * 0.1
    if ys > -14.1:
        x_w = -20.05
    else:
        d2 = ARC_R ** 2 - (ARC_CY - ys) ** 2
        if d2 <= 0:
            continue
        x_w = max(-20.05, ARC_CX - math.sqrt(d2))
    x_e = -0.95 if ys > -9.5 else 3.95
    if x_e - x_w < 0.2:
        continue
    b56.box((x_e - x_w, 0.05, 0.06), ((x_e + x_w) / 2, ys, 2.93), ("SlatWood", (0.80, 0.76, 0.68)))
for ly in (-6.9, -10.0, -12.5):
    for lx in (-18.0, -14.0, -10.0, -6.0, -2.2, 1.8):
        if lx > -0.95 and ly > -9.5:
            continue
        b56.box((0.24, 0.24, 0.05), (lx, ly, 2.95), ("Duct", (0.70, 0.74, 0.78)))
        b56.cyl(0.08, 0.08, 0.012, (lx, ly, 2.92), ("CeilSpot", (1.0, 0.97, 0.85)), 10)
b56.finish("Scenery_Ceil156", (0, 0, 0), outline=0.0)

# the door into A4-156: the passage at the north-east corner (x -3 .. -0.9, y = -5) gets a wall with a 1.0 m doorway. The door
# is built like the glass door from the lift room into A4-001: dark frame, glass leaf with dark rails / stiles and pull
# handles on both faces, a glass transom over it. The leaf stands open (hinged on the east jamb, swung 90 degrees into the room).
DOOR56_X0, DOOR56_X1 = -2.45, -1.45
DOOR56_MID = (DOOR56_X0 + DOOR56_X1) / 2
bdw = B()
bdw.box((DOOR56_X0 - (-3.0), 0.2, 3.0), ((-3.0 + DOOR56_X0) / 2, -5.0, 1.5), WALL)            # wall left of the doorway
bdw.box((-0.9 - DOOR56_X1, 0.2, 3.0), ((DOOR56_X1 - 0.9) / 2, -5.0, 1.5), WALL)                # wall right of the doorway
bdw.finish("BigRoom_DoorWall", (0, 0, 0), outline=0.03)
bdf = B()
for xx in (DOOR56_X0, DOOR56_X1):
    bdf.box((0.12, 0.24, 3.0), (xx, -5.0, 1.5), DFR)                                           # posts, floor to ceiling
bdf.box((DOOR56_X1 - DOOR56_X0 + 0.12, 0.24, 0.10), (DOOR56_MID, -5.0, 2.25), DFR)             # door header rail
bdf.box((DOOR56_X1 - DOOR56_X0 + 0.12, 0.24, 0.10), (DOOR56_MID, -5.0, 2.95), DFR)             # top rail
bdf.finish("BigRoom_DoorFrame", (0, 0, 0), outline=0.01)
tg = B()                                                                                         # transom glass above the door (no outline shell on glass)
tg.box((DOOR56_X1 - DOOR56_X0 - 0.06, 0.03, 0.64), (DOOR56_MID, -5.0, 2.60), GLASS)
tg.finish("Glass_Wall_Door156", (0, 0, 0), outline=0.0)
dl56 = B()          # leaf: origin = the hinge (east jamb), the leaf runs along +y until it is rotated open
dl56.box((0.06, 0.98, 0.10), (0, 0.5, 2.0), DFR)                                                # top rail
dl56.box((0.06, 0.98, 0.14), (0, 0.5, 0.10), DFR)                                               # bottom rail
for yy in (0.05, 0.95):
    dl56.box((0.06, 0.08, 2.05), (0, yy, 1.025), DFR)                                           # stiles
for xs in (-0.06, 0.06):                                                                         # pull handles on both faces, handle side = +y
    dl56.box((0.03, 0.04, 0.5), (xs, 0.86, 1.0), ("DoorHandle", (0.80, 0.82, 0.88)))
leaf56 = dl56.finish("Door_A4-156", (DOOR56_X1 - 0.06, -5.0, 0), outline=0.01)
dg56 = B()                                                                                       # glass pane: its own child object, no outline shell
dg56.box((0.02, 0.84, 1.78), (0, 0.5, 1.07), GLASS)
dg56o = dg56.finish("Door_A4-156_Glass", (0, 0, 0), outline=0.0)
dg56o.parent = leaf56
leaf56.rotation_euler = (0, 0, math.radians(90))                                               # closed: the room is scenery only (use 180 to swing it open into the room)
