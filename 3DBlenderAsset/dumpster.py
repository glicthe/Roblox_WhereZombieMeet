import bpy
import bmesh
import math
import os
import sys
from pathlib import Path

TEXTURE_RES = 1024
BAKE_SAMPLES = 32

BODY_WIDTH = 1.8
BODY_DEPTH = 1.3
BODY_HEIGHT = 1.05
BODY_TOP_TAPER = 0.07

LID_HEIGHT = 0.28
LID_OVERHANG = 0.04
LID_GAP = 0.05
LID_THICKNESS = 0.025

RIB_COUNT_FRONT = 5
RIB_COUNT_SIDE = 3
RIB_WIDTH = 0.035
RIB_PROTRUSION = 0.018
CORNER_POST_SIZE = 0.035

HINGE_COUNT = 3
HINGE_RADIUS = 0.028
HINGE_LEN = 0.09

WHEEL_RADIUS = 0.075
WHEEL_HEIGHT = 0.09

LABEL_W = 0.22
LABEL_H = 0.14
LABEL_THICKNESS = 0.012
LABEL_X_OFFSET = 0.30
LABEL_Z_CENTER = BODY_HEIGHT * 0.45

FORK_BAR_H = 0.05
FORK_BAR_Z = (BODY_HEIGHT * 0.16, BODY_HEIGHT * 0.38)

BEVEL_WIDTH = 0.006
BEVEL_SEGMENTS = 2

if bpy.data.filepath:
    OUTPUT_DIR = os.path.join(os.path.dirname(bpy.data.filepath), "Dumpster_Roblox_Export")
else:
    OUTPUT_DIR = os.path.join(str(Path.home()), "Documents", "Dumpster_Roblox_Export")
TEXTURE_DIR = os.path.join(OUTPUT_DIR, "textures")
FINAL_OBJECT_NAME = "Dumpster_PostApocalyptic"


def log(msg):
    print(f"[DUMPSTER] {msg}")
    sys.stdout.flush()


def clear_scene():
    log("Membersihkan scene...")
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in list(bpy.data.images):
        if block.users == 0:
            bpy.data.images.remove(block)


def recalc_normals(bm):
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def bm_to_object(bm, name):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def create_box(cx, cy, cz, sx, sy, sz, name):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = v.co.x * sx + cx
        v.co.y = v.co.y * sy + cy
        v.co.z = v.co.z * sz + cz
    recalc_normals(bm)
    return bm_to_object(bm, name)


def create_cylinder_x(cx, cy, cz, radius, length, name, segments=10):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segments,
        radius1=radius, radius2=radius, depth=length
    )
    for v in bm.verts:
        z_orig = v.co.z
        v.co.z = v.co.x + cz
        v.co.x = z_orig + cx
        v.co.y += cy
    recalc_normals(bm)
    return bm_to_object(bm, name)


def create_wheel(x, y, name):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=10,
        radius1=WHEEL_RADIUS, radius2=WHEEL_RADIUS, depth=WHEEL_HEIGHT
    )
    for v in bm.verts:
        vz = v.co.z
        v.co.z = WHEEL_RADIUS
        v.co.y += vz
    for v in bm.verts:
        v.co.x += x
        v.co.y += y
    recalc_normals(bm)
    return bm_to_object(bm, name)


def create_body():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= BODY_WIDTH
        v.co.y *= BODY_DEPTH
        v.co.z = (v.co.z + 0.5) * BODY_HEIGHT
    for v in bm.verts:
        if v.co.z > BODY_HEIGHT * 0.9:
            v.co.x += math.copysign(BODY_TOP_TAPER, v.co.x)
            v.co.y += math.copysign(BODY_TOP_TAPER, v.co.y)
    recalc_normals(bm)
    return bm_to_object(bm, "Body")


def create_corner_posts():
    parts = []
    hw = BODY_WIDTH / 2 + 0.008
    hd = BODY_DEPTH / 2 + 0.008
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(create_box(
                sx * hw, sy * hd, BODY_HEIGHT / 2 - 0.01,
                CORNER_POST_SIZE, CORNER_POST_SIZE, BODY_HEIGHT + 0.015,
                "CornerPost"
            ))
    return parts


def create_ribs():
    parts = []
    rib_h = BODY_HEIGHT - 0.12
    rib_cz = BODY_HEIGHT / 2

    usable_w = BODY_WIDTH - CORNER_POST_SIZE * 3
    for sy, name in ((-1, "RibFront"), (1, "RibBack")):
        y = sy * (BODY_DEPTH / 2 + RIB_PROTRUSION / 2)
        for i in range(RIB_COUNT_FRONT):
            t = (i + 0.5) / RIB_COUNT_FRONT - 0.5
            x = t * usable_w
            parts.append(create_box(x, y, rib_cz, RIB_WIDTH, RIB_PROTRUSION, rib_h, name))

    usable_d = BODY_DEPTH - CORNER_POST_SIZE * 3
    for sx, name in ((-1, "RibLeft"), (1, "RibRight")):
        x = sx * (BODY_WIDTH / 2 + RIB_PROTRUSION / 2)
        for i in range(RIB_COUNT_SIDE):
            t = (i + 0.5) / RIB_COUNT_SIDE - 0.5
            y = t * usable_d
            parts.append(create_box(x, y, rib_cz, RIB_PROTRUSION, RIB_WIDTH, rib_h, name))
    return parts


def create_forklift_bars():
    parts = []
    y = -(BODY_DEPTH / 2 + 0.03)
    for z in FORK_BAR_Z:
        parts.append(create_box(0, y, z, BODY_WIDTH * 0.92, 0.06, FORK_BAR_H, "ForkBar"))
    return parts


def create_label_plates():
    parts = []
    y = -(BODY_DEPTH / 2 + LABEL_THICKNESS / 2 + RIB_PROTRUSION * 0.6)
    for sx in (-1, 1):
        parts.append(create_box(
            sx * LABEL_X_OFFSET, y, LABEL_Z_CENTER,
            LABEL_W, LABEL_THICKNESS, LABEL_H, "LabelPlate"
        ))
    return parts


def create_lid_panel(sign):
    hw = BODY_WIDTH / 2 + LID_OVERHANG
    hd = BODY_DEPTH / 2 + LID_OVERHANG
    y_inner = sign * (LID_GAP / 2)
    y_outer = sign * hd
    z_inner = BODY_HEIGHT + LID_HEIGHT
    z_outer = BODY_HEIGHT - 0.005

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        lx, ly, lz = v.co.x, v.co.y, v.co.z
        x = lx * (BODY_WIDTH + LID_OVERHANG * 2)
        if ly < 0:
            y, z_top = y_inner, z_inner
        else:
            y, z_top = y_outer, z_outer
        z = z_top if lz > 0 else (z_top - LID_THICKNESS)
        v.co.x, v.co.y, v.co.z = x, y, z
    recalc_normals(bm)
    return bm_to_object(bm, f"LidPanel_{'Front' if sign < 0 else 'Back'}")


def create_lid_handle():
    return create_cylinder_x(
        0, 0, BODY_HEIGHT + LID_HEIGHT + 0.015,
        0.022, BODY_WIDTH * 0.85, "LidHandle"
    )


def create_hinges():
    parts = []
    hd = BODY_DEPTH / 2 + LID_OVERHANG
    for i in range(HINGE_COUNT):
        t = (i + 0.5) / HINGE_COUNT - 0.5
        x = t * (BODY_WIDTH * 0.8)
        parts.append(create_cylinder_x(
            x, hd - 0.02, BODY_HEIGHT + 0.01,
            HINGE_RADIUS, HINGE_LEN, "Hinge"
        ))
    return parts


def create_wheels():
    parts = []
    wx = BODY_WIDTH / 2 - WHEEL_RADIUS * 1.3
    wy = BODY_DEPTH / 2 - WHEEL_RADIUS * 1.3
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(create_wheel(sx * wx, sy * wy, "Wheel"))
    return parts


def build_dumpster_mesh():
    log("Membangun mesh dumpster (detail lengkap)...")
    parts = [create_body()]
    parts += create_corner_posts()
    parts += create_ribs()
    parts += create_forklift_bars()
    parts += create_label_plates()
    parts.append(create_lid_panel(-1))
    parts.append(create_lid_panel(1))
    parts.append(create_lid_handle())
    parts += create_hinges()
    parts += create_wheels()

    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()

    obj = bpy.context.view_layer.objects.active
    obj.name = FINAL_OBJECT_NAME
    obj.data.name = FINAL_OBJECT_NAME + "_Mesh"

    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

    bev = obj.modifiers.new("EdgeBevel", 'BEVEL')
    bev.width = BEVEL_WIDTH
    bev.segments = BEVEL_SEGMENTS
    bev.limit_method = 'ANGLE'
    bev.angle_limit = math.radians(35)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bev.name)

    bpy.ops.object.shade_flat()

    log(f"Mesh selesai: {len(obj.data.polygons)} face "
        f"(~{sum(len(p.vertices) - 2 for p in obj.data.polygons)} tris).")
    return obj


def uv_unwrap(obj):
    log("UV unwrap (Smart UV Project)...")
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.035)
    bpy.ops.object.mode_set(mode='OBJECT')


def _mix(nt, name, fac_socket, color1, color2, x, y, fac_default=None):
    n = nt.nodes.new("ShaderNodeMixRGB")
    n.name = n.label = name
    n.location = (x, y)
    n.blend_type = 'MIX'
    n.use_clamp = True
    if isinstance(color1, tuple):
        n.inputs['Color1'].default_value = color1
    else:
        nt.links.new(color1, n.inputs['Color1'])
    if isinstance(color2, tuple):
        n.inputs['Color2'].default_value = color2
    else:
        nt.links.new(color2, n.inputs['Color2'])
    if fac_socket is not None:
        nt.links.new(fac_socket, n.inputs['Fac'])
    elif fac_default is not None:
        n.inputs['Fac'].default_value = fac_default
    return n


def _ramp(nt, name, x, y, stops):
    n = nt.nodes.new("ShaderNodeValToRGB")
    n.name = n.label = name
    n.location = (x, y)
    ramp = n.color_ramp
    while len(ramp.elements) > 1:
        ramp.elements.remove(ramp.elements[-1])
    ramp.elements[0].position = stops[0][0]
    ramp.elements[0].color = (stops[0][1],) * 3 + (1.0,)
    for pos, val in stops[1:]:
        e = ramp.elements.new(pos)
        e.color = (val,) * 3 + (1.0,)
    return n


def _math(nt, op, a, b, x, y, label=""):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.location = (x, y)
    if label:
        n.label = label
    if isinstance(a, tuple):
        n.inputs[0].default_value = a[0]
    else:
        nt.links.new(a, n.inputs[0])
    if isinstance(b, tuple):
        n.inputs[1].default_value = b[0]
    elif b is not None:
        nt.links.new(b, n.inputs[1])
    return n.outputs[0]


def _rect_mask(nt, sep_xyz, x_min, x_max, z_min, z_max, x, y, tag):
    gx1 = _math(nt, 'GREATER_THAN', sep_xyz.outputs['X'], (x_min,), x, y, tag + "_gx1")
    gx2 = _math(nt, 'LESS_THAN', sep_xyz.outputs['X'], (x_max,), x, y - 60, tag + "_gx2")
    gz1 = _math(nt, 'GREATER_THAN', sep_xyz.outputs['Z'], (z_min,), x, y - 120, tag + "_gz1")
    gz2 = _math(nt, 'LESS_THAN', sep_xyz.outputs['Z'], (z_max,), x, y - 180, tag + "_gz2")
    gy = _math(nt, 'LESS_THAN', sep_xyz.outputs['Y'], (0.0,), x, y - 240, tag + "_gy")
    m1 = _math(nt, 'MULTIPLY', gx1, gx2, x + 200, y - 30)
    m2 = _math(nt, 'MULTIPLY', gz1, gz2, x + 200, y - 150)
    m3 = _math(nt, 'MULTIPLY', m1, m2, x + 400, y - 90)
    m4 = _math(nt, 'MULTIPLY', m3, gy, x + 600, y - 150, tag + "_final")
    return m4


def build_material():
    log("Membangun material prosedural (rust streak, dirt organik, bump 2-layer)...")
    mat = bpy.data.materials.new("Dumpster_PostApocalyptic_Mat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial"); out.location = (1800, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled"); bsdf.location = (1550, 0)
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

    tex_coord = nt.nodes.new("ShaderNodeTexCoord"); tex_coord.location = (-1800, 0)
    sep_xyz = nt.nodes.new("ShaderNodeSeparateXYZ"); sep_xyz.location = (-1600, -400)
    nt.links.new(tex_coord.outputs['Object'], sep_xyz.inputs['Vector'])

    map_range_top = nt.nodes.new("ShaderNodeMapRange"); map_range_top.location = (-1400, -550)
    map_range_top.inputs['From Min'].default_value = 0.0
    map_range_top.inputs['From Max'].default_value = BODY_HEIGHT
    nt.links.new(sep_xyz.outputs['Z'], map_range_top.inputs['Value'])
    ramp_topgrad = _ramp(nt, "RampTopGrad", -1200, -550, [(0.35, 0.1), (0.85, 1.0)])
    nt.links.new(map_range_top.outputs['Result'], ramp_topgrad.inputs['Fac'])

    noise_paintvar = nt.nodes.new("ShaderNodeTexNoise"); noise_paintvar.location = (-1600, 650)
    noise_paintvar.inputs['Scale'].default_value = 1.4
    nt.links.new(tex_coord.outputs['Generated'], noise_paintvar.inputs['Vector'])
    ramp_paintvar = _ramp(nt, "RampPaintVar", -1400, 650, [(0.42, 0.0), (0.58, 1.0)])
    nt.links.new(noise_paintvar.outputs['Fac'], ramp_paintvar.inputs['Fac'])

    noise_dirt = nt.nodes.new("ShaderNodeTexNoise"); noise_dirt.location = (-1600, 450)
    noise_dirt.inputs['Scale'].default_value = 3.2
    noise_dirt.inputs['Detail'].default_value = 4.0
    nt.links.new(tex_coord.outputs['Generated'], noise_dirt.inputs['Vector'])
    ramp_dirt = _ramp(nt, "RampDirt", -1400, 450, [(0.35, 0.0), (0.62, 1.0)])
    nt.links.new(noise_dirt.outputs['Fac'], ramp_dirt.inputs['Fac'])

    voronoi_dirt = nt.nodes.new("ShaderNodeTexVoronoi"); voronoi_dirt.location = (-1600, 300)
    voronoi_dirt.inputs['Scale'].default_value = 2.3
    nt.links.new(tex_coord.outputs['Generated'], voronoi_dirt.inputs['Vector'])
    ramp_dirt2 = _ramp(nt, "RampDirt2", -1400, 300, [(0.15, 1.0), (0.45, 0.0)])
    nt.links.new(voronoi_dirt.outputs['Distance'], ramp_dirt2.inputs['Fac'])
    dirt_mask = _math(nt, 'MAXIMUM', ramp_dirt.outputs['Color'], ramp_dirt2.outputs['Color'], -1150, 380, "DirtMaskFinal")

    noise_rust = nt.nodes.new("ShaderNodeTexNoise"); noise_rust.location = (-1600, 150)
    noise_rust.inputs['Scale'].default_value = 9.0
    noise_rust.inputs['Detail'].default_value = 8.0
    nt.links.new(tex_coord.outputs['Generated'], noise_rust.inputs['Vector'])
    ramp_rust = _ramp(nt, "RampRust", -1400, 150, [(0.45, 0.0), (0.7, 1.0)])
    nt.links.new(noise_rust.outputs['Fac'], ramp_rust.inputs['Fac'])

    mapping_streak = nt.nodes.new("ShaderNodeMapping"); mapping_streak.location = (-1600, -50)
    mapping_streak.inputs['Scale'].default_value = (1.0, 1.0, 0.12)
    nt.links.new(tex_coord.outputs['Generated'], mapping_streak.inputs['Vector'])
    noise_streak = nt.nodes.new("ShaderNodeTexNoise"); noise_streak.location = (-1400, -50)
    noise_streak.inputs['Scale'].default_value = 6.0
    noise_streak.inputs['Detail'].default_value = 3.0
    nt.links.new(mapping_streak.outputs['Vector'], noise_streak.inputs['Vector'])
    ramp_streak = _ramp(nt, "RampStreak", -1200, -50, [(0.4, 0.0), (0.58, 1.0)])
    nt.links.new(noise_streak.outputs['Fac'], ramp_streak.inputs['Fac'])
    streak_top = _math(nt, 'MULTIPLY', ramp_streak.outputs['Color'], ramp_topgrad.outputs['Color'], -1000, -200, "StreakTop")
    rust_mask = _math(nt, 'MAXIMUM', ramp_rust.outputs['Color'], streak_top, -800, 100, "RustMaskFinal")

    voronoi_scratch = nt.nodes.new("ShaderNodeTexVoronoi"); voronoi_scratch.location = (-1600, -250)
    voronoi_scratch.inputs['Scale'].default_value = 45.0
    nt.links.new(tex_coord.outputs['Generated'], voronoi_scratch.inputs['Vector'])
    ramp_scratch = _ramp(nt, "RampScratch", -1400, -250, [(0.0, 1.0), (0.06, 0.0)])
    nt.links.new(voronoi_scratch.outputs['Distance'], ramp_scratch.inputs['Fac'])

    noise_bump_fine = nt.nodes.new("ShaderNodeTexNoise"); noise_bump_fine.location = (-1600, -700)
    noise_bump_fine.inputs['Scale'].default_value = 60.0
    noise_bump_fine.inputs['Detail'].default_value = 6.0
    nt.links.new(tex_coord.outputs['Generated'], noise_bump_fine.inputs['Vector'])

    noise_bump_coarse = nt.nodes.new("ShaderNodeTexNoise"); noise_bump_coarse.location = (-1600, -850)
    noise_bump_coarse.inputs['Scale'].default_value = 12.0
    noise_bump_coarse.inputs['Detail'].default_value = 6.0
    nt.links.new(tex_coord.outputs['Generated'], noise_bump_coarse.inputs['Vector'])

    geometry = nt.nodes.new("ShaderNodeNewGeometry"); geometry.location = (-1600, -350)
    ramp_edge = _ramp(nt, "RampEdge", -1400, -350, [(0.45, 0.0), (0.75, 1.0)])
    nt.links.new(geometry.outputs['Pointiness'], ramp_edge.inputs['Fac'])

    ao_node = nt.nodes.new("ShaderNodeAmbientOcclusion"); ao_node.location = (-1600, -450)
    ao_node.samples = 8
    ao_node.inputs['Distance'].default_value = 0.15
    ramp_ao = _ramp(nt, "RampAO", -1400, -450, [(0.0, 1.0), (0.85, 0.0)])
    nt.links.new(ao_node.outputs['AO'], ramp_ao.inputs['Fac'])

    label_mask_1 = _rect_mask(
        nt, sep_xyz,
        x_min=-LABEL_X_OFFSET - LABEL_W / 2, x_max=-LABEL_X_OFFSET + LABEL_W / 2,
        z_min=LABEL_Z_CENTER - LABEL_H / 2, z_max=LABEL_Z_CENTER + LABEL_H / 2,
        x=-1400, y=-950, tag="Label1"
    )
    label_mask_2 = _rect_mask(
        nt, sep_xyz,
        x_min=LABEL_X_OFFSET - LABEL_W / 2, x_max=LABEL_X_OFFSET + LABEL_W / 2,
        z_min=LABEL_Z_CENTER - LABEL_H / 2, z_max=LABEL_Z_CENTER + LABEL_H / 2,
        x=-1400, y=-1250, tag="Label2"
    )
    label_mask = _math(nt, 'MAXIMUM', label_mask_1, label_mask_2, -600, -1100, "LabelMaskFinal")

    COL_PAINT = (0.045, 0.10, 0.045, 1.0)
    COL_PAINT_ALT = (0.06, 0.125, 0.06, 1.0)
    COL_RUST = (0.28, 0.115, 0.032, 1.0)
    COL_DIRT = (0.05, 0.045, 0.038, 1.0)
    COL_SCRATCH = (0.5, 0.5, 0.53, 1.0)
    COL_EDGEWEAR = (0.55, 0.52, 0.45, 1.0)
    COL_GRIME = (0.018, 0.016, 0.013, 1.0)
    COL_LABEL = (0.55, 0.42, 0.08, 1.0)

    mix0 = _mix(nt, "MixPaintVar", ramp_paintvar.outputs['Color'], COL_PAINT, COL_PAINT_ALT, -400, 700)
    mix1 = _mix(nt, "MixRust", rust_mask, mix0.outputs['Color'], COL_RUST, -150, 700)
    mix2 = _mix(nt, "MixDirt", dirt_mask, mix1.outputs['Color'], COL_DIRT, 100, 700)
    mix3 = _mix(nt, "MixScratch", ramp_scratch.outputs['Color'], mix2.outputs['Color'], COL_SCRATCH, 350, 700)
    mix4 = _mix(nt, "MixEdgeWear", ramp_edge.outputs['Color'], mix3.outputs['Color'], COL_EDGEWEAR, 600, 700)
    mix5 = _mix(nt, "MixLabel", label_mask, mix4.outputs['Color'], COL_LABEL, 850, 700)
    mix6 = _mix(nt, "MixGrimeAO", ramp_ao.outputs['Color'], mix5.outputs['Color'], COL_GRIME, 1100, 700)
    nt.links.new(mix6.outputs['Color'], bsdf.inputs['Base Color'])

    r1 = _mix(nt, "RoughRust", rust_mask, (0.5,) * 3 + (1,), (0.8,) * 3 + (1,), -150, 350)
    r2 = _mix(nt, "RoughDirt", dirt_mask, r1.outputs['Color'], (0.9,) * 3 + (1,), 100, 350)
    r3 = _mix(nt, "RoughScratch", ramp_scratch.outputs['Color'], r2.outputs['Color'], (0.25,) * 3 + (1,), 350, 350)
    nt.links.new(r3.outputs['Color'], bsdf.inputs['Roughness'])

    m1_ = _mix(nt, "MetalRust", rust_mask, (0.05,) * 3 + (1,), (0.08,) * 3 + (1,), -150, 150)
    m2_ = _mix(nt, "MetalScratch", ramp_scratch.outputs['Color'], m1_.outputs['Color'], (0.75,) * 3 + (1,), 100, 150)
    nt.links.new(m2_.outputs['Color'], bsdf.inputs['Metallic'])

    bump_coarse_src = _mix(nt, "BumpCoarseSrc", rust_mask, noise_bump_coarse.outputs['Fac'],
                            ramp_scratch.outputs['Color'], -150, -50, fac_default=0.5)

    bump_fine = nt.nodes.new("ShaderNodeBump"); bump_fine.location = (350, -50)
    bump_fine.inputs['Strength'].default_value = 0.15
    nt.links.new(noise_bump_fine.outputs['Fac'], bump_fine.inputs['Height'])

    bump_coarse = nt.nodes.new("ShaderNodeBump"); bump_coarse.location = (650, -50)
    bump_coarse.inputs['Strength'].default_value = 0.4
    nt.links.new(bump_coarse_src.outputs['Color'], bump_coarse.inputs['Height'])
    nt.links.new(bump_fine.outputs['Normal'], bump_coarse.inputs['Normal'])
    nt.links.new(bump_coarse.outputs['Normal'], bsdf.inputs['Normal'])

    return mat


def setup_render_for_baking():
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = BAKE_SAMPLES
    scene.cycles.use_denoising = False
    try:
        scene.cycles.device = 'GPU'
        bpy.context.preferences.addons['cycles'].preferences.get_devices()
        has_gpu = any(d.use for d in bpy.context.preferences.addons['cycles'].preferences.devices)
        if not has_gpu:
            scene.cycles.device = 'CPU'
            log("GPU tidak terdeteksi/aktif, pakai CPU untuk bake.")
        else:
            log("Memakai GPU untuk bake.")
    except Exception:
        scene.cycles.device = 'CPU'
        log("GPU tidak tersedia, pakai CPU untuk bake.")


def new_bake_image(name, is_data=False):
    img = bpy.data.images.new(name, width=TEXTURE_RES, height=TEXTURE_RES, alpha=False)
    img.colorspace_settings.name = 'Non-Color' if is_data else 'sRGB'
    return img


def bake_pass(obj, mat, image, bake_type, pass_filter=None):
    nt = mat.node_tree
    img_node = nt.nodes.new("ShaderNodeTexImage")
    img_node.image = image
    img_node.location = (1800, -700)
    for n in nt.nodes:
        n.select = False
    img_node.select = True
    nt.nodes.active = img_node

    kwargs = dict(type=bake_type, margin=8, use_clear=True)
    if pass_filter:
        kwargs['pass_filter'] = pass_filter
    bpy.ops.object.bake(**kwargs)

    nt.nodes.remove(img_node)


def bake_metallic_via_emission(obj, mat, image):
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')

    original_link = None
    if out.inputs['Surface'].links:
        original_link = out.inputs['Surface'].links[0].from_socket

    emit = nt.nodes.new("ShaderNodeEmission")
    emit.location = (1550, -900)
    metallic_input = bsdf.inputs['Metallic']
    if metallic_input.links:
        nt.links.new(metallic_input.links[0].from_socket, emit.inputs['Color'])
    else:
        v = metallic_input.default_value
        emit.inputs['Color'].default_value = (v, v, v, 1.0)
    nt.links.new(emit.outputs['Emission'], out.inputs['Surface'])

    bake_pass(obj, mat, image, 'EMIT')

    if original_link:
        nt.links.new(original_link, out.inputs['Surface'])
    nt.nodes.remove(emit)


def bake_all_textures(obj, mat):
    os.makedirs(TEXTURE_DIR, exist_ok=True)
    setup_render_for_baking()

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    log("Baking ColorMap...")
    img_color = new_bake_image(FINAL_OBJECT_NAME + "_ColorMap", is_data=False)
    bake_pass(obj, mat, img_color, 'DIFFUSE', pass_filter={'COLOR'})
    img_color.filepath_raw = os.path.join(TEXTURE_DIR, "ColorMap.png")
    img_color.file_format = 'PNG'
    img_color.save()

    log("Baking RoughnessMap...")
    img_rough = new_bake_image(FINAL_OBJECT_NAME + "_RoughnessMap", is_data=True)
    bake_pass(obj, mat, img_rough, 'ROUGHNESS')
    img_rough.filepath_raw = os.path.join(TEXTURE_DIR, "RoughnessMap.png")
    img_rough.file_format = 'PNG'
    img_rough.save()

    log("Baking MetalnessMap...")
    img_metal = new_bake_image(FINAL_OBJECT_NAME + "_MetalnessMap", is_data=True)
    bake_metallic_via_emission(obj, mat, img_metal)
    img_metal.filepath_raw = os.path.join(TEXTURE_DIR, "MetalnessMap.png")
    img_metal.file_format = 'PNG'
    img_metal.save()

    log("Baking NormalMap...")
    img_normal = new_bake_image(FINAL_OBJECT_NAME + "_NormalMap", is_data=True)
    bake_pass(obj, mat, img_normal, 'NORMAL')
    img_normal.filepath_raw = os.path.join(TEXTURE_DIR, "NormalMap.png")
    img_normal.file_format = 'PNG'
    img_normal.save()

    log(f"Semua texture tersimpan di: {TEXTURE_DIR}")


def export_fbx(obj):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    fbx_path = os.path.join(OUTPUT_DIR, FINAL_OBJECT_NAME + ".fbx")
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        object_types={'MESH'},
        mesh_smooth_type='FACE',
        path_mode='COPY',
        embed_textures=True,
        add_leaf_bones=False,
    )
    log(f"FBX diexport ke: {fbx_path}")
    return fbx_path


def main():
    log("=== MULAI: Dumpster Post-Apocalypse Generator v2 ===")
    log(f"Output folder: {OUTPUT_DIR}")

    bpy.context.preferences.edit.use_global_undo = False
    try:
        clear_scene()
        obj = build_dumpster_mesh()
        uv_unwrap(obj)

        mat = build_material()
        obj.data.materials.clear()
        obj.data.materials.append(mat)

        bake_all_textures(obj, mat)
        export_fbx(obj)

        blend_path = os.path.join(OUTPUT_DIR, FINAL_OBJECT_NAME + ".blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend_path, copy=True)
        log(f".blend arsip disimpan di: {blend_path}")
    finally:
        bpy.context.preferences.edit.use_global_undo = True

    log("=== SELESAI ===")
    log("Langkah selanjutnya di Roblox Studio:")
    log("1. File > Import (3D Importer) -> pilih Dumpster_PostApocalyptic.fbx")
    log("2. Kalau mesh muncul abu-abu polos, upload 4 PNG di folder /textures")
    log("   lewat Asset Manager, lalu tambahkan objek 'SurfaceAppearance' di")
    log("   bawah MeshPart-nya, dan pasang: ColorMap, MetalnessMap,")
    log("   RoughnessMap, NormalMap sesuai nama filenya.")
    log("3. Kalau ukurannya kurang pas, atur scale di dialog 3D Importer.")


if __name__ == "__main__":
    main()