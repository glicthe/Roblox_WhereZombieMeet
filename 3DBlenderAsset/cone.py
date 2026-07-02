import bpy
import bmesh
import random
import math

BASE_SEED = 4200
BAKE_TEXTURES_FOR_EXPORT = True

CONE_HEIGHT = 1.10
CONE_TOP_RADIUS = 0.03
CONE_BOTTOM_RADIUS = 0.27
BASE_WIDTH = 0.55
BASE_HEIGHT = 0.085
RADIAL_SEGMENTS = 20
HEIGHT_SEGMENTS = 4

def new_node(node_tree, type_id, location=(0, 0)):
    n = node_tree.nodes.new(type_id)
    n.location = location
    return n

def get_socket(sockets, name, sock_type):
    for s in sockets:
        if s.name == name and s.type == sock_type:
            return s
    for s in sockets:
        if s.name == name:
            return s
    return None

def new_mix(node_tree, location, data_type='RGBA', blend='MIX'):
    n = new_node(node_tree, 'ShaderNodeMix', location)
    n.data_type = data_type
    n.blend_type = blend
    n.clamp_result = True
    sock_type = 'RGBA' if data_type == 'RGBA' else 'VALUE'
    fac = get_socket(n.inputs, 'Factor', 'VALUE')
    a = get_socket(n.inputs, 'A', sock_type)
    b = get_socket(n.inputs, 'B', sock_type)
    result = get_socket(n.outputs, 'Result', sock_type)
    return n, fac, a, b, result

def new_math(node_tree, location, operation='ADD'):
    n = new_node(node_tree, 'ShaderNodeMath', location)
    n.operation = operation
    n.use_clamp = True
    return n

def clear_old_cones():
    for obj in list(bpy.data.objects):
        if obj.name.startswith("ZombieCone"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for mat in list(bpy.data.materials):
        if mat.name.startswith("ZombieCone_Mat"):
            bpy.data.materials.remove(mat)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0 and mesh.name.startswith("ZombieCone"):
            bpy.data.meshes.remove(mesh)

def create_cone_mesh(name):
    bm = bmesh.new()

    cone_geom = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=RADIAL_SEGMENTS,
        radius1=CONE_BOTTOM_RADIUS,
        radius2=CONE_TOP_RADIUS,
        depth=CONE_HEIGHT,
    )
    cone_verts = cone_geom['verts']
    for v in cone_verts:
        v.co.z += CONE_HEIGHT / 2

    vertical_edges = [e for e in bm.edges
                       if abs(e.verts[0].co.z - e.verts[1].co.z) > 1e-6]
    bmesh.ops.subdivide_edges(bm, edges=vertical_edges,
                               cuts=HEIGHT_SEGMENTS, use_grid_fill=True)

    base_geom = bmesh.ops.create_cube(bm, size=1.0)
    base_verts = base_geom['verts']
    bmesh.ops.scale(bm, verts=base_verts, vec=(BASE_WIDTH, BASE_WIDTH, BASE_HEIGHT))
    bmesh.ops.translate(bm, verts=base_verts, vec=(0, 0, -BASE_HEIGHT / 2))

    base_vert_set = set(base_verts)
    base_vertical_edges = [
        e for e in bm.edges
        if e.verts[0] in base_vert_set and e.verts[1] in base_vert_set
        and abs(e.verts[0].co.z - e.verts[1].co.z) > 1e-6
    ]
    bmesh.ops.bevel(bm, geom=base_vertical_edges,
                     offset=BASE_WIDTH * 0.13, segments=4, profile=0.6,
                     affect='EDGES')

    bm.normal_update()
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def finalize_shading(obj, angle_deg=35):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle_deg))
    except Exception:
        try:
            obj.data.use_auto_smooth = True
            obj.data.auto_smooth_angle = math.radians(angle_deg)
        except Exception:
            pass

def create_damaged_material(name, seed):
    random.seed(seed)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = new_node(nt, 'ShaderNodeOutputMaterial', (1700, 0))
    bsdf = new_node(nt, 'ShaderNodeBsdfPrincipled', (1450, 0))
    bsdf.inputs['Metallic'].default_value = 0.0
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

    coord = new_node(nt, 'ShaderNodeTexCoord', (-1800, 0))
    sepxyz = new_node(nt, 'ShaderNodeSeparateXYZ', (-1600, 0))
    nt.links.new(coord.outputs['Object'], sepxyz.inputs['Vector'])

    height = new_node(nt, 'ShaderNodeMapRange', (-1400, 250))
    height.inputs['From Min'].default_value = 0.0
    height.inputs['From Max'].default_value = CONE_HEIGHT
    nt.links.new(sepxyz.outputs['Z'], height.inputs['Value'])

    stripe = new_node(nt, 'ShaderNodeValToRGB', (-1150, 400))
    stripe.color_ramp.interpolation = 'CONSTANT'
    cr = stripe.color_ramp
    orange = (0.55, 0.14, 0.02, 1.0)
    dirty_white = (0.58, 0.55, 0.49, 1.0)
    cr.elements[0].position = 0.0
    cr.elements[0].color = orange
    for pos, col in [(0.42, dirty_white), (0.56, orange),
                      (0.72, dirty_white), (0.86, orange)]:
        e = cr.elements.new(pos)
        e.color = col
    nt.links.new(height.outputs['Result'], stripe.inputs['Fac'])

    n_fade = new_node(nt, 'ShaderNodeTexNoise', (-1150, 650))
    n_fade.noise_dimensions = '4D'
    n_fade.inputs['Scale'].default_value = random.uniform(3.0, 6.0)
    n_fade.inputs['W'].default_value = seed * 0.13
    nt.links.new(coord.outputs['Object'], n_fade.inputs['Vector'])
    fade_map = new_node(nt, 'ShaderNodeMapRange', (-950, 650))
    fade_map.inputs['To Min'].default_value = 0.0
    fade_map.inputs['To Max'].default_value = 0.4
    nt.links.new(n_fade.outputs['Fac'], fade_map.inputs['Value'])

    n_chip = new_node(nt, 'ShaderNodeTexNoise', (-1150, -100))
    n_chip.noise_dimensions = '4D'
    n_chip.inputs['Scale'].default_value = random.uniform(28.0, 42.0)
    n_chip.inputs['W'].default_value = seed * 0.27 + 5.0
    nt.links.new(coord.outputs['Object'], n_chip.inputs['Vector'])
    chip_ramp = new_node(nt, 'ShaderNodeValToRGB', (-950, -100))
    chip_ramp.color_ramp.elements[0].position = 0.55
    chip_ramp.color_ramp.elements[1].position = 0.68
    nt.links.new(n_chip.outputs['Fac'], chip_ramp.inputs['Fac'])

    geo = new_node(nt, 'ShaderNodeNewGeometry', (-1150, -280))
    chip_add = new_math(nt, (-750, -180), 'ADD')
    nt.links.new(chip_ramp.outputs['Color'], chip_add.inputs[0])
    pointiness_mul = new_math(nt, (-950, -280), 'MULTIPLY')
    pointiness_mul.inputs[1].default_value = 0.6
    nt.links.new(geo.outputs['Pointiness'], pointiness_mul.inputs[0])
    nt.links.new(pointiness_mul.outputs['Value'], chip_add.inputs[1])

    n_grime = new_node(nt, 'ShaderNodeTexVoronoi', (-1150, -450))
    n_grime.voronoi_dimensions = '4D'
    n_grime.inputs['Scale'].default_value = random.uniform(4.0, 7.0)
    n_grime.inputs['W'].default_value = seed * 0.41 + 11.0
    nt.links.new(coord.outputs['Object'], n_grime.inputs['Vector'])
    grime_inv_h = new_math(nt, (-950, -560), 'SUBTRACT')
    grime_inv_h.inputs[0].default_value = 1.0
    nt.links.new(height.outputs['Result'], grime_inv_h.inputs[1])
    grime_h_mul = new_math(nt, (-800, -560), 'MULTIPLY')
    grime_h_mul.inputs[1].default_value = 0.55
    nt.links.new(grime_inv_h.outputs['Value'], grime_h_mul.inputs[0])
    grime_add = new_math(nt, (-650, -450), 'ADD')
    nt.links.new(n_grime.outputs['Distance'], grime_add.inputs[0])
    nt.links.new(grime_h_mul.outputs['Value'], grime_add.inputs[1])

    mapping = new_node(nt, 'ShaderNodeMapping', (-1400, -750))
    mapping.inputs['Scale'].default_value = (9.0, 9.0, 1.4)
    nt.links.new(coord.outputs['Object'], mapping.inputs['Vector'])
    n_rust = new_node(nt, 'ShaderNodeTexNoise', (-1150, -750))
    n_rust.noise_dimensions = '4D'
    n_rust.inputs['Scale'].default_value = random.uniform(2.5, 4.0)
    n_rust.inputs['W'].default_value = seed * 0.19 + 21.0
    nt.links.new(mapping.outputs['Vector'], n_rust.inputs['Vector'])
    rust_ramp = new_node(nt, 'ShaderNodeValToRGB', (-950, -750))
    rust_ramp.color_ramp.elements[0].position = 0.5
    rust_ramp.color_ramp.elements[1].position = 0.66
    nt.links.new(n_rust.outputs['Fac'], rust_ramp.inputs['Fac'])
    rust_mul = new_math(nt, (-750, -820), 'MULTIPLY')
    nt.links.new(rust_ramp.outputs['Color'], rust_mul.inputs[0])
    nt.links.new(grime_inv_h.outputs['Value'], rust_mul.inputs[1])

    faded_color = (0.62, 0.42, 0.30, 1.0)
    chip_color = (0.24, 0.23, 0.21, 1.0)
    dirt_color = (0.05, 0.035, 0.02, 1.0)
    rust_color = (0.30, 0.10, 0.02, 1.0)
    rubber_color = (0.035, 0.033, 0.03, 1.0)

    mix1, f1, a1, b1, r1 = new_mix(nt, (-350, 300), 'RGBA', 'MIX')
    nt.links.new(stripe.outputs['Color'], a1)
    b1.default_value = faded_color
    nt.links.new(fade_map.outputs['Result'], f1)

    mix2, f2, a2, b2, r2 = new_mix(nt, (-100, 200), 'RGBA', 'MIX')
    nt.links.new(r1, a2)
    b2.default_value = chip_color
    nt.links.new(chip_add.outputs['Value'], f2)

    mix3, f3, a3, b3, r3 = new_mix(nt, (150, 100), 'RGBA', 'MULTIPLY')
    nt.links.new(r2, a3)
    b3.default_value = dirt_color
    nt.links.new(grime_add.outputs['Value'], f3)

    mix4, f4, a4, b4, r4 = new_mix(nt, (400, 0), 'RGBA', 'MULTIPLY')
    nt.links.new(r3, a4)
    b4.default_value = rust_color
    nt.links.new(rust_mul.outputs['Value'], f4)

    is_base = new_math(nt, (400, -300), 'LESS_THAN')
    nt.links.new(sepxyz.outputs['Z'], is_base.inputs[0])
    is_base.inputs[1].default_value = 0.0

    mix5, f5, a5, b5, r5 = new_mix(nt, (700, -50), 'RGBA', 'MIX')
    nt.links.new(r4, a5)
    b5.default_value = rubber_color
    nt.links.new(is_base.outputs['Value'], f5)
    nt.links.new(r5, bsdf.inputs['Base Color'])

    rough_add = new_math(nt, (400, -450), 'ADD')
    nt.links.new(chip_add.outputs['Value'], rough_add.inputs[0])
    nt.links.new(grime_add.outputs['Value'], rough_add.inputs[1])
    rough_map = new_node(nt, 'ShaderNodeMapRange', (600, -450))
    rough_map.inputs['To Min'].default_value = 0.35
    rough_map.inputs['To Max'].default_value = 0.85
    nt.links.new(rough_add.outputs['Value'], rough_map.inputs['Value'])

    rough_mix, fr, ar, br, rr = new_mix(nt, (850, -450), 'FLOAT', 'MIX')
    nt.links.new(rough_map.outputs['Result'], ar)
    br.default_value = 0.78
    nt.links.new(is_base.outputs['Value'], fr)
    nt.links.new(rr, bsdf.inputs['Roughness'])

    crack = new_node(nt, 'ShaderNodeTexVoronoi', (900, 300))
    crack.voronoi_dimensions = '4D'
    crack.feature = 'DISTANCE_TO_EDGE'
    crack.inputs['Scale'].default_value = random.uniform(10.0, 16.0)
    crack.inputs['W'].default_value = seed * 0.31 + 31.0
    nt.links.new(coord.outputs['Object'], crack.inputs['Vector'])

    bump = new_node(nt, 'ShaderNodeBump', (1150, 300))
    bump.inputs['Strength'].default_value = 0.25
    nt.links.new(crack.outputs['Distance'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

    return mat

def bake_material_to_textures(obj, resolution=1024):
    scene = bpy.context.scene
    old_engine = scene.render.engine
    scene.render.engine = 'CYCLES'

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    if not obj.data.uv_layers:
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=66)
        bpy.ops.object.mode_set(mode='OBJECT')

    mat = obj.active_material
    nt = mat.node_tree

    bake_targets = [
        ("BaseColor", 'DIFFUSE', {'COLOR'}),
        ("Roughness", 'ROUGHNESS', set()),
        ("Normal", 'NORMAL', set()),
    ]

    for i, (tex_name, bake_type, pass_filter) in enumerate(bake_targets):
        img = bpy.data.images.new(f"{obj.name}_{tex_name}", resolution, resolution)
        img_node = new_node(nt, 'ShaderNodeTexImage', (1450, -600 - i * 300))
        img_node.image = img
        nt.nodes.active = img_node

        if bake_type == 'DIFFUSE':
            bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'})
        else:
            bpy.ops.object.bake(type=bake_type)

        img.pack()
        nt.nodes.remove(img_node)

    scene.render.engine = old_engine
    print(f"Bake selesai untuk {obj.name}. Buka Image Editor untuk Save As / export.")

def main():
    clear_old_cones()
    obj = create_cone_mesh("ZombieCone")
    finalize_shading(obj)
    mat = create_damaged_material("ZombieCone_Mat", BASE_SEED)
    obj.data.materials.append(mat)
    
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)

    if BAKE_TEXTURES_FOR_EXPORT:
        bake_material_to_textures(obj)

    print(f"[OK] {obj.name} dibuat (utuh, usang & kotor) dengan seed {BASE_SEED}")

main()