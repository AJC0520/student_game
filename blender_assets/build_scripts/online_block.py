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
