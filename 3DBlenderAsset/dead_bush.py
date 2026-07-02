"""
Blender Dead Bush Generator
=============================
Generates a single dead dry bush at the scene origin using
recursive branching. Each branch is a tapered flat ribbon.

HOW TO USE:
1. Open Blender → Scripting workspace
2. New script → paste → Alt+P
3. Switch to Material Preview (Z → Material Preview)
"""

import bpy
import random
import math
from mathutils import Euler

# ─────────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────────
SEED              = 5

STEM_COUNT        = 6       # Root stems sprouting from base
BRANCH_DEPTH      = 5       # Recursion depth
BRANCH_CHANCE     = 0.82    # Probability of spawning a child branch
BRANCH_SPLIT      = 2       # Max children per node

BUSH_HEIGHT       = 0.85    # Approx max height
BUSH_SPREAD       = 0.55    # Horizontal spread radius

STEM_WIDTH_BASE   = 0.028   # Ribbon width at root
STEM_WIDTH_TIP    = 0.006   # Ribbon width at deepest tip
LEAN_OUT          = 0.55    # How much stems lean outward (0=straight up, 1=flat)

COLOR_BARK_DARK   = (0.12, 0.08, 0.04, 1.0)
COLOR_BARK_LIGHT  = (0.28, 0.20, 0.11, 1.0)
# ─────────────────────────────────────────────


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)


def lerp_color(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


# ── Branch data structure ──────────────────────────────────────────────────

class Segment:
    def __init__(self, x1, y1, z1, x2, y2, z2, depth):
        self.x1, self.y1, self.z1 = x1, y1, z1
        self.x2, self.y2, self.z2 = x2, y2, z2
        self.depth = depth  # higher depth = thicker (closer to root)


def grow(ox, oy, oz, dx, dy, dz, length, depth, max_depth, rng, out):
    if depth == 0 or length < 0.015:
        return

    # Wiggle direction
    perp_x = -dy
    perp_y  =  dx
    wx = perp_x * rng.uniform(-0.5, 0.5)
    wy = perp_y * rng.uniform(-0.5, 0.5)
    wz = rng.uniform(-0.15, 0.25)

    ndx = dx + wx; ndy = dy + wy; ndz = dz + wz
    mag = math.sqrt(ndx**2 + ndy**2 + ndz**2) or 1
    ndx /= mag; ndy /= mag; ndz /= mag

    seg_len = length * rng.uniform(0.75, 1.05)
    ex = ox + ndx * seg_len
    ey = oy + ndy * seg_len
    ez = max(0.0, oz + ndz * seg_len)

    out.append(Segment(ox, oy, oz, ex, ey, ez, depth))

    child_len = length * rng.uniform(0.58, 0.78)

    # Continue forward
    grow(ex, ey, ez, ndx, ndy, ndz, child_len, depth - 1, max_depth, rng, out)

    # Spawn side branches
    n_splits = rng.randint(1, BRANCH_SPLIT) if rng.random() < BRANCH_CHANCE else 0
    for _ in range(n_splits):
        side = rng.choice([-1, 1])
        bx = ndx + perp_x * side * rng.uniform(0.5, 1.2) + rng.uniform(-0.2, 0.2)
        by = ndy + perp_y * side * rng.uniform(0.5, 1.2) + rng.uniform(-0.2, 0.2)
        bz = ndz + rng.uniform(0.1, 0.5)
        bm = math.sqrt(bx**2 + by**2 + bz**2) or 1
        bx /= bm; by /= bm; bz /= bm
        grow(ex, ey, ez, bx, by, bz,
             child_len * rng.uniform(0.45, 0.68),
             depth - 2, max_depth, rng, out)


def build_bush(rng):
    segments = []
    for i in range(STEM_COUNT):
        angle  = 2 * math.pi * i / STEM_COUNT + rng.uniform(-0.25, 0.25)
        spread = rng.uniform(0.0, BUSH_SPREAD * 0.3)
        sx = math.cos(angle) * spread
        sy = math.sin(angle) * spread

        # Direction: lean outward + upward
        dx = math.cos(angle) * LEAN_OUT
        dy = math.sin(angle) * LEAN_OUT
        dz = 1.0
        mag = math.sqrt(dx**2 + dy**2 + dz**2)
        dx /= mag; dy /= mag; dz /= mag

        stem_length = BUSH_HEIGHT * rng.uniform(0.55, 1.0)
        grow(sx, sy, 0.0, dx, dy, dz,
             stem_length, BRANCH_DEPTH, BRANCH_DEPTH, rng, segments)

    return segments


# ── Mesh builder ───────────────────────────────────────────────────────────

def ribbon(x1, y1, z1, x2, y2, z2, w1, w2):
    """
    Tapered flat ribbon between two 3D points.
    Width tapers from w1 (start) to w2 (end).
    Perpendicular computed in XY; ribbon faces upward.
    """
    dx = x2 - x1; dy = y2 - y1
    horiz = math.sqrt(dx**2 + dy**2)
    if horiz < 1e-7:
        # Vertical segment — use fixed perpendicular
        nx, ny = 1.0, 0.0
    else:
        nx = -dy / horiz
        ny =  dx / horiz

    h1 = w1 / 2; h2 = w2 / 2
    v0 = (x1 + nx*h1, y1 + ny*h1, z1)
    v1 = (x1 - nx*h1, y1 - ny*h1, z1)
    v2 = (x2 - nx*h2, y2 - ny*h2, z2)
    v3 = (x2 + nx*h2, y2 + ny*h2, z2)
    return [v0, v1, v2, v3], [(0, 1, 2, 3)]


def build_mesh(segments, max_depth):
    all_verts  = []
    all_faces  = []
    all_colors = []
    offset     = 0

    for seg in segments:
        # Taper: root segments are thick, tip segments are thin
        t      = 1.0 - (seg.depth / max_depth)   # 0=root, 1=tip
        t      = max(0.0, min(1.0, t))
        w_start = STEM_WIDTH_BASE + (STEM_WIDTH_TIP - STEM_WIDTH_BASE) * t
        w_end   = STEM_WIDTH_BASE + (STEM_WIDTH_TIP - STEM_WIDTH_BASE) * min(1.0, t + 0.15)

        verts, faces = ribbon(
            seg.x1, seg.y1, seg.z1,
            seg.x2, seg.y2, seg.z2,
            w_start, w_end
        )
        color_t = t   # dark at root, lighter at tips
        col     = lerp_color(COLOR_BARK_DARK, COLOR_BARK_LIGHT, color_t)[:3]

        all_verts.extend(verts)
        all_faces.extend(tuple(fi + offset for fi in f) for f in faces)
        all_colors.extend([col] * len(verts))
        offset += len(verts)

    mesh = bpy.data.meshes.new("BushMesh")
    mesh.from_pydata(all_verts, [], all_faces)
    mesh.update()

    vcol = mesh.vertex_colors.new(name="bark_col")
    for poly in mesh.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            vcol.data[li].color = (*all_colors[vi], 1.0)

    return mesh


def create_material():
    mat = bpy.data.materials.new("BushMaterial")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "bark_col"
    attr.location = (-300, 0)

    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.92
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    bsdf.location = (0, 0)

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (300, 0)

    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def setup_scene():
    # 3-point lighting for a nice bush preview
    bpy.ops.object.light_add(type='SUN', location=(3, -3, 6))
    sun = bpy.context.object
    sun.data.energy = 3.0
    sun.rotation_euler = Euler((math.radians(50), 0, math.radians(30)))

    bpy.ops.object.light_add(type='POINT', location=(-2, 2, 2))
    fill = bpy.context.object
    fill.data.energy = 8.0
    fill.data.color  = (0.8, 0.85, 1.0)

    bpy.ops.object.camera_add(location=(2.2, -2.2, 1.2))
    cam = bpy.context.object
    cam.rotation_euler = Euler((math.radians(72), 0, math.radians(45)))
    bpy.context.scene.camera = cam


# ─────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────
def main():
    print(">>> Dead Bush Generator starting …")
    clear_scene()

    rng = random.Random(SEED)

    col = bpy.data.collections.new("DeadBush")
    bpy.context.scene.collection.children.link(col)

    segments = build_bush(rng)
    print(f">>> {len(segments)} branch segments generated")

    mesh = build_mesh(segments, BRANCH_DEPTH)
    mat  = create_material()
    mesh.materials.append(mat)

    obj = bpy.data.objects.new("DeadBush", mesh)
    col.objects.link(obj)

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    setup_scene()

    print(f">>> Done! Change SEED (currently {SEED}) for a different bush shape.")
    print(">>> Switch to Material Preview (Z → Material Preview) to see colors.")


main()
