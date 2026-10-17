"""The phone the student drops after opening the door (godot_project/assets/phone.glb, used by scripts/phone_pickup.gd).

Run in Blender:  exec(open(path, encoding="utf-8").read())
Builds a low-poly smartphone lying on its back (screen up, +Z), 7.6 x 15.6 x 0.9 cm, exports it and removes the temporary
objects again so the open .blend is left as it was. Objects: Phone_Body (case + camera bump), Phone_Screen (glowing glass).
"""
import bpy, bmesh, math
from mathutils import Matrix

OUT = r"C:\Users\asgei\Desktop\student_game\godot_project\assets\phone.glb"
W, H, T = 0.076, 0.156, 0.009


def mat(name, rgb, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.8
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*rgb, 1.0)
    return m


def box(bm, size, loc, mat_index):
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(loc) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
    for f in {f for v in r["verts"] for f in v.link_faces}:
        f.material_index = mat_index
        f.smooth = False


def cyl(bm, radius, depth, loc, mat_index, seg=10):
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=radius, radius2=radius, depth=depth,
                              matrix=Matrix.Translation(loc))
    for f in {f for v in r["verts"] for f in v.link_faces}:
        f.material_index = mat_index
        f.smooth = False


def make(name, bm, mats, coll):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def run():
    coll = bpy.data.collections.new("Phone_Tmp")
    bpy.context.scene.collection.children.link(coll)
    body_m = mat("Phone_CaseMat", (0.10, 0.10, 0.13))
    bump_m = mat("Phone_BumpMat", (0.04, 0.04, 0.05))
    screen_m = mat("Phone_ScreenMat", (0.30, 0.72, 1.00), emit=1.6)
    bm = bmesh.new()
    box(bm, (W, H, T), (0, 0, T / 2), 0)                                   # case
    box(bm, (0.030, 0.030, 0.004), (-0.017, -0.050, -0.0005 + 0.0), 1)     # camera bump (underside, so it lies flat on the floor it lifts slightly)
    cyl(bm, 0.008, 0.005, (-0.017, -0.050, -0.002), 1)
    body = make("Phone_Body", bm, [body_m, bump_m], coll)
    bm2 = bmesh.new()
    box(bm2, (W - 0.008, H - 0.012, 0.0008), (0, 0, T + 0.0004), 0)         # screen glass
    screen = make("Phone_Screen", bm2, [screen_m], coll)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    screen.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False)
    for o in (body, screen):
        me = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.meshes.remove(me)
    bpy.data.collections.remove(coll)
    for m in (body_m, bump_m, screen_m):
        bpy.data.materials.remove(m)
    print("phone exported to", OUT)


run()
