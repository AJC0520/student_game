# A4 blockout build scripts

These Python scripts build the whole level in Blender (walls, floors, glass, lifts, rooms, props). The .blend
(`../a4_blockout.blend`) holds the result, but editing the layout is easiest by changing the scripts and re-running.

| File | What it is |
|------|------------|
| `lib.py` | Helpers: toon + outline materials, the `B` mesh builder (boxes/cylinders/ico-spheres, flat shaded, inverted-hull outline), `text_on`. |
| `blockout4_pre_online2.py` | **Base** build script (everything except the Online room and its glass). Edit this for non-Online changes. |
| `online_block.py` | The Online committee room (furniture, ceiling). Edit this for Online changes. |
| `patch_online.py` | Applies the Online room + its glass/railing edits onto the base and writes `blockout4.py`. |
| `blockout4.py` | **Generated** final script (base + Online). This is what Blender runs. Don't edit by hand. |

## Rebuild

1. Edit the base or `online_block.py`.
2. `python patch_online.py` (run from this folder; it rewrites `blockout4.py` from the base).
3. In Blender (Scripting tab, or via the Blender MCP), with `D` set to this folder:

```python
import bpy, json
D = r"C:\Users\asgei\Desktop\student_game\blender_assets\build_scripts"
LIB = D + r"\lib.py"
exec(open(D + r"\blockout4.py", encoding="utf-8").read())      # rebuilds collection "Blockout_A4"
root = r"C:\Users\asgei\Desktop\student_game"
bpy.ops.object.select_all(action='DESELECT')
for o in bo.objects:
    if o.type != 'EMPTY': o.select_set(True)
bpy.context.view_layer.objects.active = next(o for o in bo.objects if o.name.startswith("Walls"))
bpy.ops.export_scene.gltf(filepath=root + r"\godot_project\assets\a4_blockout.glb", export_format='GLB',
    use_selection=True, export_apply=True, export_yup=True, export_materials='EXPORT',
    export_cameras=False, export_lights=False)
```

Also regenerate `godot_project/scripts/material_colors.gd` from the `Toon_*` materials (name -> `diffuse_color`) after
adding new materials, otherwise they fall back to a default grey in Godot.

Notes: the scripts expect the prop-pack objects (`Desk_Cluttered`, `Office_Chair`, ... in collection `ToonDeskPack`)
to exist in the open .blend; they are copied (linked) into the level. Coordinates: 1 unit = 1 m, +X toward the
elevators, Godot position = (x, z, -y).
