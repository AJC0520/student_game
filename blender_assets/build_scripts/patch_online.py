import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
s = open('blockout4.py', encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:60]
    s = s.replace(a, b, 1)


# --- walls: open the north wall (window) and the corridor wall (glass partition) of the Online room
rep("(-29, N), (-0.9, N),", "(-29, N), (-23, N)],\n    [(-9.7, N), (-0.9, N),")
rep("    [(-21, 0), (-9.7, 0)],\n", "")

# --- window + partition glass (added to the shared glass builder)
rep('glass_ob = g.finish("Glass_Wall"', '''# Online room: window wall (north, y = 4.5) and glass partition to the corridor (south, y = 0)
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
glass_ob = g.finish("Glass_Wall"''')

# --- handrail along the window (inside the room)
rep('r.finish("Railing"', '''# Online window handrail (wall-mounted on the mullions)
r.box((ox1 - ox0, 0.05, 0.06), ((ox0 + ox1) / 2, 4.5 - RD, 1.0), WOODR)
for k in range(7):
    r.box((0.05, RD, 0.05), (ox0 + (ox1 - ox0) * k / 6, 4.5 - RD / 2, 1.0), RBRK)
r.finish("Railing"''')

# --- replace the old lounge
a = s.index("# ---- Online lounge ----")
b = s.index("# ---- printer (Ricoh nook) ----")
online = open('online_block.py', encoding='utf-8').read()
s = s[:a] + online + "\n" + s[b:]

# props on the coffee table follow cx, cy
rep('dup("Coffee_Cup_Kjeldsberg", (cx, cy - 0.3, 0.4))', '# (nothing on the coffee table)')
rep('dup("Can_Dahls_Style", (cx + 0.4, cy - 0.2, 0.4))', '# (nothing on the coffee table)')
rep('dup("Matpakke_Open", (cx - 0.3, cy - 0.4, 0.4))', '# (nothing on the coffee table)')
rep('"Online": (-16, 1.2),', '')  # OnlineLabel: no floor label for the Online room
open('blockout4.py', 'w', encoding='utf-8').write(s)
import ast
ast.parse(s)
print("patched, syntax ok")
