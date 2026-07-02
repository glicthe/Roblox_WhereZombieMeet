"""
Blender Grass Generator Script  — Cluster Edition
===================================================
Each spawn point grows a CLUSTER of 3–9 blades fanned out around it,
giving a natural tuft/bunch look. Clusters are randomly distributed
across a square area.

HOW TO USE:
1. Open Blender
2. Go to the Scripting workspace (top menu)
3. Click "New" to create a new script
4. Paste this entire script
5. Click "Run Script" (or press Alt+P)
6. Switch viewport shading to Material Preview (Z → Material Preview)

CUSTOMIZATION (edit the CONFIG section below).
"""

import bpy
import random
import math
from mathutils import Euler

# ─────────────────────────────────────────────
#  CONFIG  ← tweak these values
# ─────────────────────────────────────────────
AREA_SIZE        = 10.0   # Square side length (Blender units)
CLUSTER_COUNT    = 80     # Number of grass clusters (spawn points)
SEED             = 42     # Change for a different random layout

# Blades per cluster: random int in [CLUSTER_MIN, CLUSTER_MAX]
CLUSTER_MIN      = 3
CLUSTER_MAX      = 9

# How far blades spread from the cluster centre
CLUSTER_SPREAD   = 0.12   # radius in Blender units

BLADE_HEIGHT_MIN = 0.25
BLADE_HEIGHT_MAX = 0.60
BLADE_WIDTH      = 0.045
BLADE_SEGMENTS   = 5

LEAN_MAX_DEG     = 32     # Max lean from vertical
TWIST_MAX_DEG    = 360    # Full twist randomisation

# Colour range: dark root → bright tip
COLOR_DARK   = (0.03, 0.15, 0.02, 1.0)
COLOR_BRIGHT = (0.22, 0.42, 0.05, 1.0)
# ─────────────────────────────────────────────


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)


def lerp(a, b, t):
    return a + (b - a) * t


def lerp_color(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(4))


def create_grass_material(name="GrassMaterial"):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "blade_color"
    attr.location = (-400, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (-100, 0)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.05

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (300, 0)

    links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def make_blade_mesh(height, width, segments, lean_deg, twist_deg):
    """
    Returns (verts, faces, brightness_per_vert).
    All coordinates are local to the blade base at origin.
    """
    verts  = []
    faces  = []
    colors = []

    lean  = math.radians(lean_deg)
    twist = math.radians(twist_deg)

    for seg in range(segments + 1):
        t      = seg / segments
        taper  = (1.0 - t) ** 1.4
        half_w = (width / 2.0) * taper

        curve_lean = lean * (t ** 1.5)
        seg_h      = height * t
        x_off      = math.sin(curve_lean) * seg_h * 0.6
        z          = math.cos(curve_lean) * seg_h

        lx = x_off - half_w * math.cos(twist)
        ly = -half_w * math.sin(twist)
        rx = x_off + half_w * math.cos(twist)
        ry =  half_w * math.sin(twist)

        verts.append((lx, ly, z))
        verts.append((rx, ry, z))
        colors.append(t)
        colors.append(t)

    # Tip vertex
    tip_lean = lean * (1.0 ** 1.5)
    tip_z    = math.cos(tip_lean) * height
    tip_x    = math.sin(tip_lean) * height * 0.6
    verts.append((tip_x, 0.0, tip_z))
    colors.append(1.0)
    tip_idx = len(verts) - 1

    for seg in range(segments):
        b = seg * 2
        faces.append((b, b + 1, b + 3, b + 2))

    last_l = segments * 2
    faces.append((last_l, last_l + 1, tip_idx))

    return verts, faces, colors


def create_grass_patch(collection, material):
    """
    For each cluster spawn point, generate 3–9 blades fanned around it,
    then merge everything into one mesh object.
    """
    random.seed(SEED)

    half = AREA_SIZE / 2.0

    all_verts  = []
    all_faces  = []
    all_colors = []
    vert_offset = 0

    total_blades = 0

    for cluster_idx in range(CLUSTER_COUNT):
        # Cluster centre
        cx = random.uniform(-half, half)
        cy = random.uniform(-half, half)

        # Number of blades in this cluster: 3–9
        blade_count = random.randint(CLUSTER_MIN, CLUSTER_MAX)

        # Shared cluster colour tint (blades in same cluster look related)
        cluster_color_t = random.random()

        for b in range(blade_count):
            # Spread blade around cluster centre
            angle  = random.uniform(0, math.pi * 2)
            radius = random.uniform(0, CLUSTER_SPREAD)
            px = cx + math.cos(angle) * radius
            py = cy + math.sin(angle) * radius

            # Slight per-blade colour variation inside cluster
            color_t   = min(1.0, max(0.0, cluster_color_t + random.uniform(-0.15, 0.15)))
            height    = random.uniform(BLADE_HEIGHT_MIN, BLADE_HEIGHT_MAX)
            lean_deg  = random.uniform(0, LEAN_MAX_DEG)
            # Outward lean bias: blades lean away from cluster centre
            lean_dir  = angle + random.uniform(-0.4, 0.4)
            twist_deg = math.degrees(lean_dir)

            verts, faces, brt = make_blade_mesh(
                height, BLADE_WIDTH, BLADE_SEGMENTS, lean_deg, twist_deg
            )

            world_verts = [(v[0] + px, v[1] + py, v[2]) for v in verts]
            world_faces = [tuple(fi + vert_offset for fi in f) for f in faces]

            blade_color = lerp_color(COLOR_DARK, COLOR_BRIGHT, color_t)[:3]

            all_verts.extend(world_verts)
            all_faces.extend(world_faces)
            all_colors.extend(blade_color for _ in brt)
            vert_offset += len(verts)
            total_blades += 1

    # Build single merged mesh
    mesh = bpy.data.meshes.new("GrassMesh")
    mesh.from_pydata(all_verts, [], all_faces)
    mesh.update()

    color_layer = mesh.vertex_colors.new(name="blade_color")
    loop_colors = color_layer.data

    for poly in mesh.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            c = all_colors[vi]
            loop_colors[li].color = (*c, 1.0)

    obj = bpy.data.objects.new("Grass", mesh)
    obj.data.materials.append(material)
    collection.objects.link(obj)

    print(f">>> {CLUSTER_COUNT} clusters × avg {total_blades/CLUSTER_COUNT:.1f} blades "
          f"= {total_blades} total blades")
    return obj


def setup_camera_and_light():
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 10))
    sun = bpy.context.object
    sun.data.energy = 3.0
    sun.rotation_euler = Euler((math.radians(45), 0, math.radians(45)))

    bpy.ops.object.camera_add(location=(14, -14, 10))
    cam = bpy.context.object
    cam.rotation_euler = Euler((math.radians(58), 0, math.radians(45)))
    bpy.context.scene.camera = cam


# ─────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────
def main():
    print(">>> Grass Cluster Generator starting …")
    clear_scene()

    col = bpy.data.collections.new("GrassPatch")
    bpy.context.scene.collection.children.link(col)

    mat = create_grass_material()
    obj = create_grass_patch(col, mat)

    setup_camera_and_light()

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    print(f">>> Done! {CLUSTER_COUNT} clusters in a "
          f"{AREA_SIZE}×{AREA_SIZE} unit square.")
    print(">>> Switch to Material Preview (Z → Material Preview) to see colours.")


main()
