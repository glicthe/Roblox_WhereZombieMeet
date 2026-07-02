"""
Blender Apocalypse Road Details Script
========================================
Generates three apocalypse-themed details over a road slab:
  1. Dirt & debris patches  — dark sandy oval decals
  2. Dead dry bushes        — scraggly branching twig clusters
  3. Scattered leaves       — thin curved flat planes

Pairs with road_crack_generator.py, or run standalone (includes its own slab).

HOW TO USE:
1. Open Blender → Scripting workspace
2. New script → paste → Alt+P (Run Script)
3. Switch to Material Preview (Z → Material Preview)
"""

import bpy
import random
import math
from mathutils import Euler, Matrix, Vector

# ─────────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────────
AREA_SIZE   = 10.0
SEED        = 13

# ── Dirt patches ──────────────────────────
DIRT_COUNT        = 18     # number of patches
DIRT_RADIUS_MIN   = 0.30
DIRT_RADIUS_MAX   = 0.90
DIRT_VERTS        = 14     # polygon resolution

# ── Dead bushes ───────────────────────────
BUSH_COUNT        = 12
BUSH_BRANCH_DEPTH = 4      # recursion depth
BUSH_BRANCH_CHANCE= 0.78
BUSH_HEIGHT_MIN   = 0.20
BUSH_HEIGHT_MAX   = 0.55
BUSH_SPREAD       = 0.22   # base branch spread radius
TWIG_WIDTH        = 0.008  # flat ribbon width for twigs

# ── Leaves ────────────────────────────────
LEAF_COUNT        = 120
LEAF_LENGTH_MIN   = 0.06
LEAF_LENGTH_MAX   = 0.16
LEAF_WIDTH_RATIO  = 0.45   # width as fraction of length
LEAF_CURL         = 0.18   # how much leaf curves upward at tip

# ── Colors ────────────────────────────────
COLOR_ROAD        = (0.08, 0.08, 0.08, 1.0)
COLOR_DIRT        = (0.18, 0.13, 0.08, 1.0)
COLOR_TWIG        = (0.22, 0.17, 0.10, 1.0)
COLOR_LEAF_DRY    = (0.28, 0.20, 0.06, 1.0)
COLOR_LEAF_DARK   = (0.14, 0.09, 0.03, 1.0)
# ─────────────────────────────────────────────


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)


def make_material(name, color, roughness=0.95):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (300, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def lerp_color(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


# ══════════════════════════════════════════════
#  ROAD SLAB
# ══════════════════════════════════════════════

def create_road_slab(col, mat):
    h = AREA_SIZE / 2.0
    verts = [(-h,-h,0),(h,-h,0),(h,h,0),(-h,h,0)]
    mesh = bpy.data.meshes.new("RoadSlab")
    mesh.from_pydata(verts, [], [(0,1,2,3)])
    mesh.update()
    obj = bpy.data.objects.new("RoadSlab", mesh)
    obj.data.materials.append(mat)
    col.objects.link(obj)


# ══════════════════════════════════════════════
#  1. DIRT & DEBRIS PATCHES
# ══════════════════════════════════════════════

def create_dirt_patches(col, mat, rng):
    half = AREA_SIZE / 2.0
    all_verts = []
    all_faces = []
    offset = 0

    for _ in range(DIRT_COUNT):
        cx   = rng.uniform(-half * 0.9, half * 0.9)
        cy   = rng.uniform(-half * 0.9, half * 0.9)
        rx   = rng.uniform(DIRT_RADIUS_MIN, DIRT_RADIUS_MAX)
        ry   = rx * rng.uniform(0.4, 0.9)       # squash into oval
        rot  = rng.uniform(0, math.pi)
        n    = DIRT_VERTS

        verts = []
        for i in range(n):
            a  = 2 * math.pi * i / n
            lx = rx * math.cos(a)
            ly = ry * math.sin(a)
            # rotate oval
            wx = cx + lx * math.cos(rot) - ly * math.sin(rot)
            wy = cy + lx * math.sin(rot) + ly * math.cos(rot)
            verts.append((wx, wy, 0.0))

        # fan triangulation from first vert
        faces = [(0 + offset, i + offset, i + 1 + offset)
                 for i in range(1, n - 1)]
        all_verts.extend(verts)
        all_faces.extend(faces)
        offset += n

    mesh = bpy.data.meshes.new("DirtPatches")
    mesh.from_pydata(all_verts, [], all_faces)
    mesh.update()
    obj = bpy.data.objects.new("DirtPatches", mesh)
    obj.data.materials.append(mat)
    obj.location.z = 0.0005
    col.objects.link(obj)
    print(f"    dirt: {DIRT_COUNT} patches")


# ══════════════════════════════════════════════
#  2. DEAD DRY BUSHES
# ══════════════════════════════════════════════

def _grow_branch(ox, oy, oz, dx, dy, dz, length, depth, rng, segs):
    """Recursively grow twig segments."""
    if depth == 0 or length < 0.02:
        return
    # slight random deviation
    perp_x = -dy
    perp_y  =  dx
    jx = perp_x * rng.uniform(-0.6, 0.6)
    jy = perp_y * rng.uniform(-0.6, 0.6)
    jz = rng.uniform(-0.1, 0.2)

    ndx = dx + jx; ndy = dy + jy; ndz = dz + jz
    mag = math.sqrt(ndx**2 + ndy**2 + ndz**2) or 1
    ndx /= mag; ndy /= mag; ndz /= mag

    ex = ox + ndx * length
    ey = oy + ndy * length
    ez = oz + ndz * length
    ez = max(0.0, ez)

    segs.append((ox, oy, oz, ex, ey, ez))

    child_len = length * rng.uniform(0.55, 0.78)
    _grow_branch(ex, ey, ez, ndx, ndy, ndz, child_len, depth-1, rng, segs)

    if rng.random() < BUSH_BRANCH_CHANCE:
        side = rng.choice([-1, 1])
        bx = ndx + perp_x * side * rng.uniform(0.4, 1.0)
        by = ndy + perp_y * side * rng.uniform(0.4, 1.0)
        bz = ndz + rng.uniform(0.0, 0.3)
        bm = math.sqrt(bx**2 + by**2 + bz**2) or 1
        bx /= bm; by /= bm; bz /= bm
        _grow_branch(ex, ey, ez, bx, by, bz,
                     child_len * rng.uniform(0.4, 0.65),
                     depth-2, rng, segs)


def seg3d_to_flat_ribbon(x1,y1,z1,x2,y2,z2,width):
    """Flat ribbon quad for a 3D segment (perpendicular in XY)."""
    dx = x2-x1; dy = y2-y1
    horiz = math.sqrt(dx**2+dy**2)
    if horiz < 1e-6:
        return [],[]
    nx = -dy/horiz * (width/2)
    ny =  dx/horiz * (width/2)
    v0=(x1+nx,y1+ny,z1); v1=(x1-nx,y1-ny,z1)
    v2=(x2-nx,y2-ny,z2); v3=(x2+nx,y2+ny,z2)
    return [v0,v1,v2,v3],[(0,1,2,3)]


def create_dead_bushes(col, mat, rng):
    half = AREA_SIZE / 2.0
    all_verts = []
    all_faces = []
    offset = 0

    for _ in range(BUSH_COUNT):
        cx = rng.uniform(-half*0.85, half*0.85)
        cy = rng.uniform(-half*0.85, half*0.85)
        height = rng.uniform(BUSH_HEIGHT_MIN, BUSH_HEIGHT_MAX)
        segs   = []

        # Grow 3-5 root stems fanning outward
        n_stems = rng.randint(3, 5)
        for s in range(n_stems):
            base_angle = 2*math.pi * s/n_stems + rng.uniform(-0.3, 0.3)
            spread = rng.uniform(0.0, BUSH_SPREAD)
            sx = cx + math.cos(base_angle) * spread
            sy = cy + math.sin(base_angle) * spread
            dx = math.cos(base_angle) * 0.3
            dy = math.sin(base_angle) * 0.3
            dz = rng.uniform(0.6, 1.0)
            mag = math.sqrt(dx**2+dy**2+dz**2)
            _grow_branch(sx, sy, 0.0, dx/mag, dy/mag, dz/mag,
                         height * rng.uniform(0.6, 1.0),
                         BUSH_BRANCH_DEPTH, rng, segs)

        for (x1,y1,z1,x2,y2,z2) in segs:
            verts, faces = seg3d_to_flat_ribbon(x1,y1,z1,x2,y2,z2,TWIG_WIDTH)
            if not verts:
                continue
            all_verts.extend(verts)
            all_faces.extend(tuple(fi+offset for fi in f) for f in faces)
            offset += len(verts)

    mesh = bpy.data.meshes.new("DeadBushes")
    mesh.from_pydata(all_verts, [], all_faces)
    mesh.update()
    obj = bpy.data.objects.new("DeadBushes", mesh)
    obj.data.materials.append(mat)
    obj.location.z = 0.001
    col.objects.link(obj)
    print(f"    bushes: {BUSH_COUNT} bushes, {len(all_verts)//4} twig ribbons")


# ══════════════════════════════════════════════
#  3. SCATTERED LEAVES
# ══════════════════════════════════════════════

def make_leaf(cx, cy, length, width, curl_z, yaw_deg):
    """
    Leaf = 5-vert shape: base-left, base-right, mid-left, mid-right, tip.
    Tip curls slightly upward.
    Returns (verts, faces).
    """
    yaw = math.radians(yaw_deg)
    cos_y = math.cos(yaw); sin_y = math.sin(yaw)

    def rot(lx, ly):
        return (cx + lx*cos_y - ly*sin_y,
                cy + lx*sin_y + ly*cos_y)

    hw = width / 2.0
    # 5 control points along leaf axis
    p0 = rot(0,  hw);   p1 = rot(0, -hw)          # base
    p2 = rot(length*0.5,  hw*0.7)
    p3 = rot(length*0.5, -hw*0.7)                  # mid
    p4x, p4y = rot(length, 0)                      # tip (curled up)

    verts = [
        (*p0, 0.0),
        (*p1, 0.0),
        (*p3, curl_z * 0.4),
        (*p2, curl_z * 0.4),
        (p4x, p4y, curl_z),
    ]
    faces = [
        (0, 1, 2, 3),   # back half quad
        (3, 2, 4),       # front triangle to tip
    ]
    return verts, faces


def create_leaves(col, mat, rng):
    half = AREA_SIZE / 2.0
    all_verts = []
    all_faces = []
    offset = 0

    for _ in range(LEAF_COUNT):
        cx     = rng.uniform(-half, half)
        cy     = rng.uniform(-half, half)
        length = rng.uniform(LEAF_LENGTH_MIN, LEAF_LENGTH_MAX)
        width  = length * LEAF_WIDTH_RATIO * rng.uniform(0.7, 1.0)
        curl   = rng.uniform(0.0, LEAF_CURL)
        yaw    = rng.uniform(0, 360)

        verts, faces = make_leaf(cx, cy, length, width, curl, yaw)
        all_verts.extend(verts)
        all_faces.extend(tuple(fi+offset for fi in f) for f in faces)
        offset += len(verts)

    # Vertex color for dry variation (reuse single mat, vary via vertex color)
    mesh = bpy.data.meshes.new("Leaves")
    mesh.from_pydata(all_verts, [], all_faces)
    mesh.update()

    vcol = mesh.vertex_colors.new(name="leaf_col")
    for poly in mesh.polygons:
        t = rng.random()
        c = lerp_color(COLOR_LEAF_DARK, COLOR_LEAF_DRY, t)
        for li in poly.loop_indices:
            vcol.data[li].color = c

    obj = bpy.data.objects.new("Leaves", mesh)
    obj.data.materials.append(mat)
    obj.location.z = 0.002
    col.objects.link(obj)
    print(f"    leaves: {LEAF_COUNT} leaves")


def make_leaf_material():
    mat = bpy.data.materials.new("LeafMaterial")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "leaf_col"
    attr.location = (-300, 0)

    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    bsdf.location = (0, 0)

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (300, 0)

    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


# ══════════════════════════════════════════════
#  CAMERA & LIGHT
# ══════════════════════════════════════════════

def setup_scene():
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 10))
    sun = bpy.context.object
    sun.data.energy = 3.5
    sun.rotation_euler = Euler((math.radians(40), 0, math.radians(35)))

    bpy.ops.object.camera_add(location=(0, -15, 12))
    cam = bpy.context.object
    cam.rotation_euler = Euler((math.radians(52), 0, 0))
    bpy.context.scene.camera = cam


# ══════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════

def main():
    print(">>> Apocalypse Road Details starting …")
    clear_scene()

    rng = random.Random(SEED)

    col = bpy.data.collections.new("ApocalypseRoad")
    bpy.context.scene.collection.children.link(col)

    road_mat  = make_material("RoadMaterial",  COLOR_ROAD)
    dirt_mat  = make_material("DirtMaterial",  COLOR_DIRT)
    twig_mat  = make_material("TwigMaterial",  COLOR_TWIG)
    leaf_mat  = make_leaf_material()

    print("  Building road slab …")
    create_road_slab(col, road_mat)

    print("  Building dirt patches …")
    create_dirt_patches(col, dirt_mat, rng)

    print("  Building dead bushes …")
    create_dead_bushes(col, twig_mat, rng)

    print("  Building scattered leaves …")
    create_leaves(col, leaf_mat, rng)

    setup_scene()

    print(f">>> Done! Switch to Material Preview to see the result.")


main()
