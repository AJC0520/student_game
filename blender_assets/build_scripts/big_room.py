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
