"""Low-poly assets for the wasteland racer on the Online room TV (godot_project/scripts/wasteland_*.gd).

Run in Blender (Scripting tab or the Blender MCP):  exec(open(path, encoding="utf-8").read())
Builds every asset in a temporary collection, exports one .glb per asset to godot_project/assets/wasteland/ and removes the
temporary objects again, so the open .blend is left as it was.

Conventions (Blender metres, +Z up, exported with Y-up so Blender +Y = Godot -Z = "forward"):
  * wasteland_car            origin at the centre of the car on the ground, nose towards +Y, 2.0 x 4.2 x 1.4 m.
                             Mesh objects: Car_Paint (the body panels, recoloured per driver in Godot) and Car_Details.
  * wasteland_track_straight origin at the middle of the road at the entry, runs 24 m along +Y, road 19 m wide, yellow guardrails at +-9 m.
  * wasteland_track_curve    a LEFT 90 degree curve, centre line radius 24 m: enters at the origin heading +Y, leaves at (-24, 24) heading -X.
  * wasteland_track_curve_right  the same curve built mirrored (a real mirrored mesh, not a negative scale), leaves at (+24, 24) heading +X.
  * props                    rusted car, shipping container, barrel, rock, pickups (ammo, rocket, repair).
"""
import bpy, bmesh, math
from mathutils import Matrix, Euler

OUT_DIR = r"C:\Users\asgei\Desktop\student_game\godot_project\assets\wasteland"
TILE_LENGTH = 24.0
CURVE_RADIUS = 24.0
ROAD_HALF = 9.5
RAIL_OFFSET = 9.0

PAL = {
    "Dirt": (0.52, 0.37, 0.22), "DirtDark": (0.38, 0.26, 0.15), "DirtLight": (0.62, 0.47, 0.30),
    "Yellow": (0.96, 0.74, 0.08), "Black": (0.06, 0.06, 0.07), "PostGrey": (0.24, 0.25, 0.27),
    "Paint": (0.85, 0.30, 0.12), "Steel": (0.46, 0.48, 0.50), "SteelDark": (0.24, 0.25, 0.28),
    "Glass": (0.18, 0.30, 0.34), "Tire": (0.08, 0.08, 0.09), "LampY": (1.0, 0.86, 0.35), "LampR": (0.9, 0.12, 0.08),
    "Rust": (0.55, 0.27, 0.12), "RustDark": (0.34, 0.18, 0.10), "Bone": (0.78, 0.72, 0.60),
    "ContRed": (0.62, 0.20, 0.14), "ContBlue": (0.18, 0.34, 0.52), "ContGreen": (0.24, 0.44, 0.28), "ContOrange": (0.78, 0.45, 0.12),
    "Rock": (0.45, 0.38, 0.32), "RockDark": (0.32, 0.27, 0.24),
    "AmmoGreen": (0.28, 0.40, 0.20), "Brass": (0.88, 0.68, 0.22), "RocketRed": (0.78, 0.16, 0.12), "White": (0.92, 0.92, 0.90),
    "Cross": (0.85, 0.10, 0.10), "OilBlack": (0.12, 0.11, 0.11),
}


def get_mat(name):
    full = "WL_" + name
    m = bpy.data.materials.get(full)
    if m:
        return m
    m = bpy.data.materials.new(full)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    r, g, b = PAL[name]
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    m.diffuse_color = (r, g, b, 1.0)
    return m


class Mesher:
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def _index(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def _tag(self, verts, name):
        i = self._index(name)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = i
            f.smooth = False

    @staticmethod
    def _xf(loc, rot, size):
        return (Matrix.Translation(loc) @ Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4()
                @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))

    def box(self, size, loc, mat, rot=(0, 0, 0)):
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._xf(loc, rot, size))
        self._tag(r["verts"], mat)

    def cyl(self, radius, depth, loc, mat, seg=8, rot=(0, 0, 0), radius2=None):
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=radius,
                                  radius2=radius if radius2 is None else radius2, depth=depth,
                                  matrix=self._xf(loc, rot, (1, 1, 1)))
        self._tag(r["verts"], mat)

    def ico(self, radius, loc, mat, scale=(1, 1, 1), sub=1):
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=radius, matrix=self._xf(loc, (0, 0, 0), scale))
        self._tag(r["verts"], mat)

    def quad(self, pts, mat):
        verts = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(verts)
        f.material_index = self._index(mat)
        f.smooth = False

    def finish(self, name, coll):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = False
        for n in self.mats:
            me.materials.append(get_mat(n))
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        return ob


# ---------------------------------------------------------------------------------------------- car

def build_car(coll):
    paint, det = Mesher(), Mesher()
    # body shell (paint): lower tub, hood, cab, rear deck, fenders, armour spikes
    paint.box((1.9, 3.6, 0.55), (0, 0, 0.62), "Paint")
    paint.box((1.7, 1.2, 0.30), (0, 1.35, 0.97), "Paint")             # hood
    paint.box((1.6, 1.5, 0.62), (0, -0.2, 1.15), "Paint")             # cab
    paint.box((1.9, 1.0, 0.35), (0, -1.45, 0.92), "Paint")            # rear deck
    for sx in (-1, 1):
        paint.box((0.28, 1.2, 0.34), (sx * 1.0, 1.25, 0.72), "Paint")     # front fenders
        paint.box((0.28, 1.2, 0.34), (sx * 1.0, -1.2, 0.72), "Paint")     # rear fenders
    # details: wheels, glass, bumpers, lamps, exhaust, roof gun
    for sx in (-1, 1):
        for sy in (-1.3, 1.35):
            det.cyl(0.45, 0.38, (sx * 1.0, sy, 0.45), "Tire", seg=8, rot=(0, 90, 0))
            det.cyl(0.22, 0.40, (sx * 1.0, sy, 0.45), "Steel", seg=6, rot=(0, 90, 0))
    det.box((1.5, 0.08, 0.42), (0, 0.55, 1.2), "Glass")               # windscreen
    det.box((1.5, 0.08, 0.38), (0, -0.95, 1.2), "Glass")              # rear window
    det.box((0.08, 1.2, 0.34), (-0.82, -0.2, 1.2), "Glass")
    det.box((0.08, 1.2, 0.34), (0.82, -0.2, 1.2), "Glass")
    det.box((2.1, 0.35, 0.30), (0, 2.05, 0.42), "SteelDark")          # front bumper / ram
    det.box((2.0, 0.30, 0.28), (0, -2.05, 0.45), "SteelDark")         # rear bumper
    for sx in (-1, 1):
        det.box((0.35, 0.10, 0.18), (sx * 0.65, 2.14, 0.78), "LampY")
        det.box((0.30, 0.10, 0.16), (sx * 0.70, -2.14, 0.80), "LampR")
        det.cyl(0.07, 0.8, (sx * 0.55, -2.05, 0.95), "SteelDark", seg=6, rot=(90, 0, 0))   # exhausts
    for sx in (-1, 1):
        det.box((0.14, 0.14, 0.45), (sx * 0.95, 2.18, 0.45), "Steel", rot=(0, 0, 0))     # ram spikes
    det.box((0.55, 0.55, 0.14), (0, -0.7, 1.56), "SteelDark")         # roof turret base
    det.box((0.16, 0.9, 0.16), (0, -0.2, 1.66), "Steel")              # roof gun barrel pointing forward
    det.box((0.2, 0.3, 0.2), (0, -0.7, 1.66), "SteelDark")
    pa = paint.finish("Car_Paint", coll)
    de = det.finish("Car_Details", coll)
    return [pa, de]


# ---------------------------------------------------------------------------------------------- track

def add_rail_post(m, x, y, rot_z=0.0):
    m.box((0.22, 0.22, 1.0), (x, y, 0.5), "PostGrey", rot=(0, 0, rot_z))


def build_straight(coll):
    m = Mesher()
    m.box((ROAD_HALF * 2, TILE_LENGTH, 0.3), (0, TILE_LENGTH / 2, -0.15), "Dirt")
    for sx in (-3.2, 3.2):                                                  # darker wheel ruts
        m.box((1.5, TILE_LENGTH - 0.4, 0.04), (sx, TILE_LENGTH / 2, 0.01), "DirtDark")
    m.box((1.2, TILE_LENGTH - 0.4, 0.03), (0, TILE_LENGTH / 2, 0.01), "DirtLight")
    for sx in (-1, 1):
        x = sx * RAIL_OFFSET
        m.box((0.16, TILE_LENGTH, 0.42), (x, TILE_LENGTH / 2, 0.72), "Yellow")
        for k in range(8):                                                  # black hazard blocks on the rail
            if k % 2 == 0:
                m.box((0.18, 1.5, 0.43), (x, 1.5 + k * 3.0, 0.72), "Black")
        for k in range(9):
            add_rail_post(m, x, k * 3.0)
    return [m.finish("Track_Straight", coll)]


def build_curve(coll, segments=12, mirror=False):
    m = Mesher()
    R = CURVE_RADIUS
    inner, outer = R - ROAD_HALF, R + ROAD_HALF
    cx, cy = -R, 0.0

    def pt(radius, phi, z):
        x = cx + radius * math.cos(phi)
        return (-x if mirror else x, cy + radius * math.sin(phi), z)

    def quad(pts, mat):
        m.quad(list(reversed(pts)) if mirror else pts, mat)

    for i in range(segments):
        a0 = (math.pi / 2) * i / segments
        a1 = (math.pi / 2) * (i + 1) / segments
        quad([pt(inner, a0, 0.0), pt(outer, a0, 0.0), pt(outer, a1, 0.0), pt(inner, a1, 0.0)], "Dirt")
        quad([pt(R - 4.0, a0, 0.01), pt(R - 2.4, a0, 0.01), pt(R - 2.4, a1, 0.01), pt(R - 4.0, a1, 0.01)], "DirtDark")
        quad([pt(R + 2.4, a0, 0.01), pt(R + 4.0, a0, 0.01), pt(R + 4.0, a1, 0.01), pt(R + 2.4, a1, 0.01)], "DirtDark")
        quad([pt(inner, a0, -0.3), pt(inner, a1, -0.3), pt(outer, a1, -0.3), pt(outer, a0, -0.3)], "DirtDark")
        for rail_r in (R - RAIL_OFFSET, R + RAIL_OFFSET):
            p0, p1 = pt(rail_r, a0, 0.72), pt(rail_r, a1, 0.72)
            mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 0.72)
            ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
            length = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 0.05
            m.box((length, 0.16, 0.42), mid, "Black" if i % 2 == 0 else "Yellow", rot=(0, 0, math.degrees(ang)))
            px, py, _ = pt(rail_r, a0, 0.0)
            m.box((0.22, 0.22, 1.0), (px, py, 0.5), "PostGrey")
    return [m.finish("Track_CurveRight" if mirror else "Track_Curve", coll)]


# ---------------------------------------------------------------------------------------------- props

def build_rusted_car(coll):
    m = Mesher()
    m.box((1.9, 3.4, 0.5), (0, 0, 0.55), "Rust")
    m.box((1.6, 1.4, 0.55), (0.05, -0.3, 1.08), "RustDark")
    m.box((1.7, 1.0, 0.18), (0, 1.35, 0.9), "Rust", rot=(-8, 0, 0))           # buckled hood
    m.box((1.5, 0.08, 0.40), (0, 0.42, 1.1), "Glass")
    for sx in (-1, 1):
        m.cyl(0.42, 0.34, (sx * 0.98, 1.2, 0.36), "Tire", seg=7, rot=(0, 90, 0))
    m.cyl(0.42, 0.34, (-0.98, -1.2, 0.30), "Tire", seg=7, rot=(0, 90, 0))
    m.box((0.5, 0.6, 0.25), (0.9, -1.2, 0.18), "OilBlack")                      # missing wheel -> axle stump
    m.box((1.8, 0.2, 0.4), (0, -1.75, 0.55), "SteelDark", rot=(0, 0, 4))
    return [m.finish("Prop_RustedCar", coll)]


def build_container(coll):
    out = []
    for name, col in (("Prop_ContainerRed", "ContRed"), ("Prop_ContainerBlue", "ContBlue"),
                      ("Prop_ContainerGreen", "ContGreen"), ("Prop_ContainerOrange", "ContOrange")):
        m = Mesher()
        m.box((2.44, 6.0, 2.5), (0, 0, 1.25), col)
        for k in range(-5, 6):                                                    # corrugation ribs
            for sx in (-1, 1):
                m.box((0.08, 0.16, 2.3), (sx * 1.24, k * 0.5, 1.25), "RustDark")
        m.box((2.5, 0.2, 2.6), (0, 3.0, 1.25), "SteelDark")                       # door frame end
        m.box((2.5, 0.2, 0.15), (0, 0, 2.55), "RustDark")
        out.append(m.finish(name, coll))
    return out


def build_barrel(coll):
    m = Mesher()
    m.cyl(0.42, 1.0, (0, 0, 0.5), "Rust", seg=8)
    for z in (0.25, 0.75):
        m.cyl(0.44, 0.08, (0, 0, z), "RustDark", seg=8)
    m.cyl(0.30, 0.04, (0, 0, 1.02), "OilBlack", seg=8)
    return [m.finish("Prop_Barrel", coll)]


def build_rock(coll):
    m = Mesher()
    m.ico(1.6, (0, 0, 0.7), "Rock", scale=(1.3, 1.0, 0.85), sub=1)
    m.ico(0.9, (1.4, 0.5, 0.35), "RockDark", scale=(1.0, 1.1, 0.8), sub=1)
    return [m.finish("Prop_Rock", coll)]


def build_pickups(coll):
    out = []
    m = Mesher()
    m.box((1.0, 0.7, 0.6), (0, 0, 0.4), "AmmoGreen")
    m.box((1.04, 0.74, 0.08), (0, 0, 0.72), "SteelDark")
    for k in range(4):
        m.cyl(0.07, 0.4, (-0.3 + k * 0.2, 0, 0.8), "Brass", seg=6)
    out.append(m.finish("Pickup_Ammo", coll))
    m = Mesher()
    m.box((1.1, 0.8, 0.55), (0, 0, 0.35), "SteelDark")
    for sx in (-0.25, 0.25):
        m.cyl(0.14, 0.9, (sx, 0, 0.78), "RocketRed", seg=6, rot=(90, 0, 0))
    out.append(m.finish("Pickup_Rocket", coll))
    m = Mesher()
    m.box((0.9, 0.9, 0.5), (0, 0, 0.35), "White")
    m.box((0.62, 0.16, 0.08), (0, 0, 0.62), "Cross")
    m.box((0.16, 0.62, 0.08), (0, 0, 0.62), "Cross")
    out.append(m.finish("Pickup_Repair", coll))
    return out


# ---------------------------------------------------------------------------------------------- export

def export(objs, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "\\" + filename, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False)


def run():
    import os
    os.makedirs(OUT_DIR, exist_ok=True)
    coll = bpy.data.collections.new("Wasteland_Tmp")
    bpy.context.scene.collection.children.link(coll)
    made = []
    jobs = [("wasteland_car.glb", build_car), ("wasteland_track_straight.glb", build_straight),
            ("wasteland_track_curve.glb", build_curve),
            ("wasteland_track_curve_right.glb", lambda c: build_curve(c, mirror=True)), ("wasteland_rusted_car.glb", build_rusted_car),
            ("wasteland_barrel.glb", build_barrel), ("wasteland_rock.glb", build_rock)]
    for filename, fn in jobs:
        objs = fn(coll)
        export(objs, filename)
        made += objs
    for objs, names in ((build_container(coll), ["wasteland_container_red.glb", "wasteland_container_blue.glb",
                                                  "wasteland_container_green.glb", "wasteland_container_orange.glb"]),
                        (build_pickups(coll), ["wasteland_pickup_ammo.glb", "wasteland_pickup_rocket.glb",
                                                "wasteland_pickup_repair.glb"])):
        for o, n in zip(objs, names):
            export([o], n)
            made.append(o)
    # tidy up: the temporary objects, meshes, materials and collection are removed again
    for o in made:
        me = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if me.users == 0:
            bpy.data.meshes.remove(me)
    bpy.data.collections.remove(coll)
    for mat in [m for m in bpy.data.materials if m.name.startswith("WL_")]:
        bpy.data.materials.remove(mat)
    print("wasteland assets exported to", OUT_DIR)


run()
