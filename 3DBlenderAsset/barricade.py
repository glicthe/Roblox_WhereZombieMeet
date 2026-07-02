import bpy
import bmesh
import random
import math
from mathutils import Vector

SEED = 42               
ROWS = 5                  
BAGS_PER_ROW = 12         
BAG_LENGTH = 0.55         
BAG_RADIUS = 0.16          
BAG_WIDTH_FACTOR = 1.55   
BAG_HEIGHT_FACTOR = 1.25   
ROW_OVERLAP = 0.78       
SUBDIV_LEVEL = 2        
NOISE_STRENGTH = 0
PYRAMID_TAPER_PER_ROW = 2
PYRAMID_MIN_BAGS = 4
PYRAMID_BATTER = 0.05       
METERS_TO_STUDS = 1 / 0.28

CLEAR_PREVIOUS = True     
EXPORT_FBX = True        
EXPORT_FOLDER = "//"    
BAKE_TEXTURE = True
TEXTURE_SIZE = 1024       


def get_or_create_collection(name):
    if name in bpy.data.collections:
        return bpy.data.collections[name]
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def clear_collection(coll):
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def create_realistic_sandbag_material():
    mat_name = "SandbagMaterial_Military"
    if mat_name in bpy.data.materials:
        return bpy.data.materials[mat_name]

    mat = bpy.data.materials.new(mat_name)
    mat.use_nodes = True

    try:
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        nodes.clear()

        output = nodes.new('ShaderNodeOutputMaterial')
        output.location = (700, 0)

        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.location = (400, 0)
        bsdf.inputs["Roughness"].default_value = 0.95

        tex_coord = nodes.new('ShaderNodeTexCoord')
        tex_coord.location = (-1100, 0)

        mapping = nodes.new('ShaderNodeMapping')
        mapping.location = (-900, 0)
        mapping.inputs['Scale'].default_value = (3.0, 3.0, 3.0)
        links.new(tex_coord.outputs['Generated'], mapping.inputs['Vector'])

        noise_large = nodes.new('ShaderNodeTexNoise')
        noise_large.location = (-650, 350)
        noise_large.inputs['Scale'].default_value = 3.5
        noise_large.inputs['Detail'].default_value = 4.0
        links.new(mapping.outputs['Vector'], noise_large.inputs['Vector'])

        ramp_large = nodes.new('ShaderNodeValToRGB')
        ramp_large.location = (-420, 350)
        ramp_large.color_ramp.elements[0].position = 0.3
        ramp_large.color_ramp.elements[0].color = (0.06, 0.09, 0.045, 1.0)
        ramp_large.color_ramp.elements[1].position = 0.7
        ramp_large.color_ramp.elements[1].color = (0.19, 0.22, 0.12, 1.0)
        links.new(noise_large.outputs['Fac'], ramp_large.inputs['Fac'])

        noise_small = nodes.new('ShaderNodeTexNoise')
        noise_small.location = (-650, 0)
        noise_small.inputs['Scale'].default_value = 28.0
        noise_small.inputs['Detail'].default_value = 6.0
        links.new(mapping.outputs['Vector'], noise_small.inputs['Vector'])

        ramp_dirt = nodes.new('ShaderNodeValToRGB')
        ramp_dirt.location = (-420, -150)
        ramp_dirt.color_ramp.elements[0].position = 0.35
        ramp_dirt.color_ramp.elements[0].color = (0.035, 0.03, 0.02, 1.0)
        ramp_dirt.color_ramp.elements[1].position = 0.65
        ramp_dirt.color_ramp.elements[1].color = (1, 1, 1, 1)
        links.new(noise_small.outputs['Fac'], ramp_dirt.inputs['Fac'])

        mix_dirt = nodes.new('ShaderNodeMixRGB')
        mix_dirt.location = (-150, 200)
        mix_dirt.blend_type = 'MULTIPLY'
        mix_dirt.inputs['Fac'].default_value = 0.55
        links.new(ramp_large.outputs['Color'], mix_dirt.inputs['Color1'])
        links.new(ramp_dirt.outputs['Color'], mix_dirt.inputs['Color2'])

        voronoi = nodes.new('ShaderNodeTexVoronoi')
        voronoi.location = (-650, -400)
        voronoi.inputs['Scale'].default_value = 9.0
        links.new(mapping.outputs['Vector'], voronoi.inputs['Vector'])

        ramp_scorch = nodes.new('ShaderNodeValToRGB')
        ramp_scorch.location = (-420, -400)
        ramp_scorch.color_ramp.elements[0].position = 0.0
        ramp_scorch.color_ramp.elements[0].color = (0.015, 0.015, 0.015, 1.0)
        ramp_scorch.color_ramp.elements[1].position = 0.10
        ramp_scorch.color_ramp.elements[1].color = (1, 1, 1, 1)
        links.new(voronoi.outputs['Distance'], ramp_scorch.inputs['Fac'])

        mix_scorch = nodes.new('ShaderNodeMixRGB')
        mix_scorch.location = (150, 100)
        mix_scorch.blend_type = 'MULTIPLY'
        mix_scorch.inputs['Fac'].default_value = 0.85
        links.new(mix_dirt.outputs['Color'], mix_scorch.inputs['Color1'])
        links.new(ramp_scorch.outputs['Color'], mix_scorch.inputs['Color2'])

        links.new(mix_scorch.outputs['Color'], bsdf.inputs['Base Color'])

        ramp_rough = nodes.new('ShaderNodeValToRGB')
        ramp_rough.location = (-420, -600)
        ramp_rough.color_ramp.elements[0].position = 0.2
        ramp_rough.color_ramp.elements[0].color = (0.7, 0.7, 0.7, 1)
        ramp_rough.color_ramp.elements[1].position = 0.8
        ramp_rough.color_ramp.elements[1].color = (1, 1, 1, 1)
        links.new(noise_small.outputs['Fac'], ramp_rough.inputs['Fac'])
        links.new(ramp_rough.outputs['Color'], bsdf.inputs['Roughness'])

        bump = nodes.new('ShaderNodeBump')
        bump.location = (150, -300)
        bump.inputs['Strength'].default_value = 0.15
        links.new(noise_small.outputs['Fac'], bump.inputs['Height'])
        links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

        links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    except Exception as e:
        print("Node graph prosedural gagal dibuat (kemungkinan beda versi Blender):", e)
        print("Fallback ke warna solid hijau tua usang.")
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (0.10, 0.13, 0.07, 1.0)
            bsdf.inputs["Roughness"].default_value = 0.95

    return mat


def bake_material_to_texture(obj, mat, filename, size=TEXTURE_SIZE):
    try:
        scene = bpy.context.scene
        original_engine = scene.render.engine
        scene.render.engine = 'CYCLES'

        image = bpy.data.images.new(filename, width=size, height=size)

        nodes = mat.node_tree.nodes
        img_node = nodes.new('ShaderNodeTexImage')
        img_node.image = image
        img_node.location = (-1100, -700)
        for n in nodes:
            n.select = False
        img_node.select = True
        nodes.active = img_node

        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj

        bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=4)

        filepath = bpy.path.abspath(EXPORT_FOLDER + filename + ".png")
        image.filepath_raw = filepath
        image.file_format = 'PNG'
        image.save()
        print(f"Texture di-bake ke: {filepath}")

        bsdf = nodes.get("Principled BSDF")
        if bsdf:
            mat.node_tree.links.new(img_node.outputs['Color'], bsdf.inputs['Base Color'])

        scene.render.engine = original_engine
        return image

    except Exception as e:
        print("Bake texture gagal (cek: engine render, GPU/CPU, atau versi Blender):", e)
        print("Material prosedural tetap dipakai apa adanya (mungkin tidak ikut export FBX dengan benar).")
        return None


def apply_smart_shading(obj, angle_deg=42):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle_deg))
    except Exception:
        try:
            bpy.ops.object.shade_smooth()
            obj.data.use_auto_smooth = True
            obj.data.auto_smooth_angle = math.radians(angle_deg)
        except Exception:
            bpy.ops.object.shade_smooth()


def set_origin_to_base(obj):
    bbox_world = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_z = min(v.z for v in bbox_world)
    center_x = sum(v.x for v in bbox_world) / 8
    center_y = sum(v.y for v in bbox_world) / 8

    cursor = bpy.context.scene.cursor
    prev_cursor_loc = cursor.location.copy()
    cursor.location = (center_x, center_y, min_z)

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

    cursor.location = prev_cursor_loc


def create_sandbag_mesh(name, bag_seed, coll):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=SUBDIV_LEVEL, use_grid_fill=True)

    for v in bm.verts:
        x = v.co.x
        if x > 0:
            pinch = max(0.06, 1.0 - (x ** 1.5) * 1.4)
            v.co.y *= pinch
            v.co.z *= pinch
            twist = x * 2.2
            y0, z0 = v.co.y, v.co.z
            v.co.y = y0 * math.cos(twist) - z0 * math.sin(twist)
            v.co.z = y0 * math.sin(twist) + z0 * math.cos(twist)
        else:
            taper = 1.0 - (abs(x) ** 2) * 0.4
            v.co.y *= taper
            v.co.z *= taper

    mesh = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    coll.objects.link(obj)

    variety = random.uniform(0.9, 1.1)
    obj.scale = (BAG_LENGTH * variety, BAG_RADIUS * 2, BAG_RADIUS * 1.7)

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(scale=True)

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.transform.vertex_random(offset=NOISE_STRENGTH, seed=bag_seed, normal=0.7)
    bpy.ops.object.mode_set(mode='OBJECT')

    bpy.ops.object.shade_smooth()
    return obj


def create_spilled_sand(location, severity, rng, coll):
    radius = BAG_RADIUS * rng.uniform(0.5, 0.9) * (0.5 + severity)
    height = radius * rng.uniform(0.35, 0.55)

    bpy.ops.mesh.primitive_cone_add(
        radius1=radius, radius2=radius * 0.1, depth=height,
        location=(location.x + rng.uniform(-0.05, 0.05),
                   location.y + rng.uniform(-0.05, 0.05),
                   height / 2)
    )
    pile = bpy.context.active_object
    pile.name = "SpilledSand"

    for c in list(pile.users_collection):
        c.objects.unlink(pile)
    coll.objects.link(pile)

    pile.scale.x *= rng.uniform(0.8, 1.3)
    pile.scale.y *= rng.uniform(0.8, 1.3)

    bpy.ops.object.select_all(action='DESELECT')
    pile.select_set(True)
    bpy.context.view_layer.objects.active = pile
    bpy.ops.object.transform_apply(scale=True, rotation=False, location=False)
    bpy.ops.object.shade_smooth()
    return pile


def displace_damaged_bag(obj, severity, rng):
    obj.location.y += rng.uniform(0.05, 0.35) * severity
    obj.location.z -= rng.uniform(0.0, obj.location.z * 0.6) * severity
    obj.location.z = max(obj.location.z, BAG_RADIUS * 0.7)

    obj.rotation_euler.x += math.radians(rng.uniform(-70, 70) * severity)
    obj.rotation_euler.y += math.radians(rng.uniform(-40, 40) * severity)

    if severity > 0.75:
        obj.rotation_euler = (
            math.radians(90),
            math.radians(rng.uniform(0, 360)),
            math.radians(rng.uniform(0, 360)),
        )
        obj.location.z = BAG_RADIUS * 0.75


def build_barricade_variant(variant_name, damage_level, origin_offset, seed, coll):
    rng = random.Random(seed)
    created_objects = []

    bag_height = BAG_RADIUS * 1.7
    bag_step = BAG_LENGTH * ROW_OVERLAP

    for row in range(ROWS):
        row_count = max(PYRAMID_MIN_BAGS, BAGS_PER_ROW - row * PYRAMID_TAPER_PER_ROW)
        stagger = (bag_step / 2) if row % 2 == 1 else 0.0
        batter = row * PYRAMID_BATTER

        full_width = BAGS_PER_ROW * bag_step
        row_width = row_count * bag_step
        center_offset = (full_width - row_width) / 2

        for i in range(row_count):
            bag_seed = seed * 1000 + row * 100 + i
            bag_name = f"{variant_name}_bag_r{row}_i{i}"
            bag = create_sandbag_mesh(bag_name, bag_seed, coll)

            base_x = origin_offset.x + center_offset + i * bag_step + stagger
            base_y = origin_offset.y + batter
            base_z = origin_offset.z + row * bag_height + bag_height / 2

            jitter_x = rng.uniform(-0.02, 0.02)
            jitter_y = rng.uniform(-0.02, 0.02)
            jitter_z = rng.uniform(-0.008, 0.008)

            rot_y = math.radians(rng.uniform(-8, 8))
            rot_z = math.radians(rng.uniform(-12, 12))

            if rng.random() < 0.15:
                rot_z += math.radians(90)

            bag.location = (base_x + jitter_x, base_y + jitter_y, base_z + jitter_z)
            bag.rotation_euler = (rot_x, rot_y, rot_z)

            is_damaged = rng.random() < damage_level
            if is_damaged:
                severity = rng.uniform(0.3, 1.0) * damage_level
                displace_damaged_bag(bag, severity, rng)
                if rng.random() < 0.5 * damage_level:
                    pile = create_spilled_sand(bag.location, severity, rng, coll)
                    created_objects.append(pile)

            created_objects.append(bag)

    if damage_level > 0.5:
        extra_count = int(BAGS_PER_ROW * damage_level * 0.4)
        for j in range(extra_count):
            bag_seed = seed * 5000 + j
            bag = create_sandbag_mesh(f"{variant_name}_scattered_{j}", bag_seed, coll)
            scatter_x = origin_offset.x + rng.uniform(-0.5, BAGS_PER_ROW * bag_step + 0.5)
            scatter_y = origin_offset.y + rng.uniform(0.4, 1.4)
            scatter_z = origin_offset.z + BAG_RADIUS * 0.8
            bag.location = (scatter_x, scatter_y, scatter_z)
            bag.rotation_euler = (
                math.radians(rng.uniform(0, 360)),
                math.radians(rng.uniform(0, 360)),
                math.radians(rng.uniform(0, 360)),
            )
            created_objects.append(bag)
            if rng.random() < 0.4:
                pile = create_spilled_sand(bag.location, 0.7, rng, coll)
                created_objects.append(pile)

    return created_objects


def finalize_variant(objects, variant_name, material):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    merged = bpy.context.active_object
    merged.name = variant_name

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

    if material is not None:
        merged.data.materials.append(material)
        if BAKE_TEXTURE:
            bake_material_to_texture(merged, material, f"{variant_name}_texture", size=TEXTURE_SIZE)

    set_origin_to_base(merged)

    merged.location = (0, 0, 0)

    merged.scale = (
        merged.scale[0] * METERS_TO_STUDS,
        merged.scale[1] * METERS_TO_STUDS,
        merged.scale[2] * METERS_TO_STUDS,
    )

    bpy.ops.object.select_all(action='DESELECT')
    merged.select_set(True)
    bpy.context.view_layer.objects.active = merged
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    poly_count = len(merged.data.polygons)
    print(f"[{variant_name}] jumlah polygon: {poly_count}")

    if EXPORT_FBX:
        filepath = bpy.path.abspath(EXPORT_FOLDER + variant_name + ".fbx")
        bpy.ops.export_scene.fbx(
            filepath=filepath,
            use_selection=True,
            apply_unit_scale=True,
            apply_scale_options='FBX_SCALE_ALL',
            object_types={'MESH'},
            use_mesh_modifiers=True,
            mesh_smooth_type='FACE',
            add_leaf_bones=False,
            bake_anim=False,
            axis_forward='-Z',
            axis_up='Y',
        )
        print(f"[{variant_name}] diexport ke: {filepath}")

    return merged


def main():
    random.seed(SEED)
    coll = get_or_create_collection("SandbagBarricades")
    if CLEAR_PREVIOUS:
        clear_collection(coll)

    material_template = create_realistic_sandbag_material()

    variants = [
        ("SandbagBarrier_Full",      0.0,  Vector((0, 0, 0))),
        ("SandbagBarrier_Damaged",   0.45, Vector((0, 6, 0))),
        ("SandbagBarrier_Destroyed", 0.85, Vector((0, 12, 0))),
    ]

    for name, damage_level, offset in variants:
        objs = build_barricade_variant(name, damage_level, offset, SEED, coll)

        variant_material.name = f"Mat_{name}"
        finalize_variant(objs, name, variant_material)

    print("=" * 60)
    print("SELESAI! 3 varian barikade karung pasir berhasil dibuat:")
    print("  1. SandbagBarrier_Full       (utuh/rapi)")
    print("  2. SandbagBarrier_Damaged    (rusak sebagian)")
    print("  3. SandbagBarrier_Destroyed  (hancur total/berantakan)")
    print("File .fbx (dan .png texture hasil bake) tersimpan di folder yang")
    print("sama dengan file .blend")
    print("=" * 60)


main()