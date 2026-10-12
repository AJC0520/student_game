import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler

OUTLINE_RGB = (0.05, 0.04, 0.09)

def get_coll():
    c = bpy.data.collections.get("ToonDeskPack")
    if not c:
        c = bpy.data.collections.new("ToonDeskPack")
        bpy.context.scene.collection.children.link(c)
    return c

def toon_mat(name, rgb):
    name = "Toon_" + name
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    diff = nt.nodes.new('ShaderNodeBsdfDiffuse')
    s2r = nt.nodes.new('ShaderNodeShaderToRGB')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    mix = nt.nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = 1.0
    diff.inputs['Color'].default_value = (1, 1, 1, 1)
    ramp.color_ramp.interpolation = 'CONSTANT'
    e = ramp.color_ramp.elements
    e[0].position = 0.0; e[0].color = (0.62, 0.62, 0.72, 1)
    e[1].position = 0.55; e[1].color = (1, 1, 1, 1)
    mid = e.new(0.3); mid.color = (0.80, 0.80, 0.86, 1)
    mix.inputs[2].default_value = (rgb[0], rgb[1], rgb[2], 1)
    nt.links.new(diff.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], mix.inputs[1])
    nt.links.new(mix.outputs[0], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1)
    return m

def outline_mat():
    name = "Toon_Outline"
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs[0].default_value = (*OUTLINE_RGB, 1)
    nt.links.new(em.outputs[0], out.inputs[0])
    m.use_backface_culling = True
    m.diffuse_color = (*OUTLINE_RGB, 1)
    return m


class B:
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, mat):
        n, rgb = mat
        if n not in self.mats:
            self.mats.append(n)
            toon_mat(n, rgb)
        return self.mats.index(n)

    def _tag(self, verts, mat):
        i = self.mi(mat)
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = i
            f.smooth = False
        return verts

    @staticmethod
    def _xf(loc, rot, scale):
        return (Matrix.Translation(loc) @ Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4()
                @ Matrix.Diagonal((*scale, 1)))

    def box(self, size, loc, mat, rot=(0, 0, 0)):
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._xf(loc, rot, size))
        return self._tag(r['verts'], mat)

    def cyl(self, r1, r2, h, loc, mat, seg=8, rot=(0, 0, 0)):
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                  radius1=r1, radius2=r2, depth=h,
                                  matrix=self._xf(loc, rot, (1, 1, 1)))
        return self._tag(r['verts'], mat)

    def ico(self, radius, loc, mat, sub=1, scale=(1, 1, 1)):
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=radius,
                                       matrix=self._xf(loc, (0, 0, 0), scale))
        return self._tag(r['verts'], mat)

    def finish(self, name, loc, outline=0.012, sharp=True):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        get_coll().objects.link(ob)
        for n in self.mats:
            me.materials.append(bpy.data.materials["Toon_" + n])
        n = len(self.mats)
        if outline:
            om = outline_mat()
            for _ in range(n):
                me.materials.append(om)
            md = ob.modifiers.new("Outline", 'SOLIDIFY')
            md.thickness = outline
            md.offset = 1.0
            md.use_flip_normals = True
            md.use_even_offset = True
            md.material_offset = n
        ob.location = loc
        return ob


def text_on(parent, body, loc, rot, size, mat, extrude=0.002, name="Text"):
    cu = bpy.data.curves.new(name, 'FONT')
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    cu.resolution_u = 1          # coarse curves = low-poly lettering
    ob = bpy.data.objects.new(name, cu)
    get_coll().objects.link(ob)
    ob.location = loc
    ob.rotation_euler = tuple(math.radians(a) for a in rot)
    # convert to mesh
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    ob2 = bpy.data.objects.new(name, me)
    get_coll().objects.link(ob2)
    ob2.location = loc
    ob2.rotation_euler = tuple(math.radians(a) for a in rot)
    toon_mat(*[mat[0], mat[1]])
    me.materials.append(bpy.data.materials["Toon_" + mat[0]])
    for p in me.polygons:
        p.use_smooth = False
    ob2.parent = parent
    ob2.matrix_parent_inverse = parent.matrix_world.inverted()
    return ob2
