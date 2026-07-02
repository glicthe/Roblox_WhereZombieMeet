import bpy
import bmesh
import math
import random

for obj in list(bpy.context.scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

def deselect_all():
    for obj in bpy.context.selected_objects:
        obj.select_set(False)

def create_mat(name, c_base, m_type):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    out = nodes.new('ShaderNodeOutputMaterial')
    out.location = (300, 0)
    
    if m_type == "SLIME":
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.location = (0, 0)
        bsdf.inputs['Roughness'].default_value = 0.05
        bsdf.inputs['Metallic'].default_value = 0.0
        
        noise = nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 4.5
        noise.inputs['Detail'].default_value = 12.0
        
        ramp = nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = 0.2
        ramp.color_ramp.elements[0].color = (0.01, 0.04, 0.01, 1)
        ramp.color_ramp.elements[1].position = 0.6
        ramp.color_ramp.elements[1].color = (0.15, 0.8, 0.0, 1)
        
        ramp.color_ramp.elements.new(0.85)
        ramp.color_ramp.elements[2].color = (0.6, 0.9, 0.0, 1)
        
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.5
        
        voronoi = nodes.new('ShaderNodeTexVoronoi')
        voronoi.inputs['Scale'].default_value = 18.0
        
        links.new(noise.outputs[0], ramp.inputs[0])
        links.new(ramp.outputs[0], bsdf.inputs['Base Color'])
        links.new(voronoi.outputs['Distance'], bump.inputs['Height'])
        links.new(bump.outputs[0], bsdf.inputs['Normal'])
        links.new(bsdf.outputs[0], out.inputs[0])
        return mat

    mix_shader = nodes.new('ShaderNodeMixShader')
    mix_shader.location = (100, 0)
    
    bsdf_clean = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf_clean.location = (-150, 150)
    bsdf_clean.inputs['Base Color'].default_value = c_base
    bsdf_clean.inputs['Roughness'].default_value = 0.65
    bsdf_clean.inputs['Metallic'].default_value = 0.0
        
    bsdf_rust = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf_rust.location = (-150, -150)
    bsdf_rust.inputs['Base Color'].default_value = (0.25, 0.1, 0.02, 1)
    bsdf_rust.inputs['Roughness'].default_value = 0.95
    bsdf_rust.inputs['Metallic'].default_value = 0.0
    
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 3.5
    noise.inputs['Detail'].default_value = 15.0
    
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.4
    ramp.color_ramp.elements[1].position = 0.6
    
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.8
    
    links.new(noise.outputs[0], ramp.inputs[0])
    links.new(ramp.outputs[0], mix_shader.inputs[0])
    links.new(bsdf_clean.outputs[0], mix_shader.inputs[1])
    links.new(bsdf_rust.outputs[0], mix_shader.inputs[2])
    links.new(mix_shader.outputs[0], out.inputs[0])
    links.new(noise.outputs[0], bump.inputs['Height'])
    links.new(bump.outputs[0], bsdf_rust.inputs['Normal'])
    
    return mat

mat_barrel = create_mat("M_Barrel_Yellow", (0.7, 0.5, 0.05, 1), "BODY")
mat_metal = create_mat("M_Dark_Metal", (0.1, 0.1, 0.1, 1), "BODY")
mat_slime = create_mat("M_Toxic_Slime", (0,0,0,0), "SLIME")

parts = []

bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.6, depth=1.8, location=(0,0,0))
body = bpy.context.active_object
body.data.materials.append(mat_barrel)

bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(body.data)
edges_to_cut = []
for e in bm.edges:
    v1, v2 = e.verts
    if abs(v1.co.z - v2.co.z) > 0.5:  
        edges_to_cut.append(e)

bmesh.ops.subdivide_edges(bm, edges=edges_to_cut, cuts=10)
bmesh.update_edit_mesh(body.data)
bpy.ops.object.mode_set(mode='OBJECT')

tex_dent = bpy.data.textures.new("Tex_Dent", type='CLOUDS')
tex_dent.noise_scale = 1.2
mod_disp = body.modifiers.new("Dent", 'DISPLACE')
mod_disp.texture = tex_dent
mod_disp.strength = 0.08
bpy.ops.object.modifier_apply(modifier="Dent")
bpy.ops.object.shade_smooth()
parts.append(body)

for z_loc in [0.9, -0.9]:
    bpy.ops.mesh.primitive_torus_add(major_radius=0.6, minor_radius=0.03, location=(0, 0, z_loc))
    rim = bpy.context.active_object
    rim.data.materials.append(mat_metal)
    bpy.ops.object.shade_smooth()
    parts.append(rim)

for z_loc in [0.3, -0.3]:
    bpy.ops.mesh.primitive_torus_add(major_radius=0.61, minor_radius=0.025, location=(0, 0, z_loc))
    hoop = bpy.context.active_object
    hoop.data.materials.append(mat_barrel)
    bpy.ops.object.shade_smooth()
    parts.append(hoop)

bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.08, depth=0.02, location=(0.3, 0, 0.91))
cap_base = bpy.context.active_object
cap_base.data.materials.append(mat_metal)

bpy.ops.object.mode_set(mode='EDIT')
bm_cap = bmesh.from_edit_mesh(cap_base.data)
top_faces = [f for f in bm_cap.faces if f.normal.z > 0.9]
bmesh.ops.inset_region(bm_cap, faces=top_faces, thickness=0.06)
bmesh.ops.delete(bm_cap, geom=top_faces, context='FACES')
bmesh.update_edit_mesh(cap_base.data)
bpy.ops.object.mode_set(mode='OBJECT')
parts.append(cap_base)

bpy.ops.object.metaball_add(type='BALL', radius=0.45, location=(0.3, 0, 0.95))
mball = bpy.context.active_object
mball.name = "Slime_Base"
mball.data.resolution = 0.04

liquid_drops = [
    ((0.3, 0.25, 0.94), 0.35),
    ((0.5, 0.1, 0.92), 0.3),
    ((0.0, -0.2, 0.93), 0.28),
    ((-0.2, 0.3, 0.91), 0.25),
    ((0.65, 0.15, 0.8), 0.28),
    ((0.68, 0.1, 0.4), 0.25),
    ((0.66, 0.05, 0.1), 0.2),
    ((0.68, 0.0, -0.2), 0.22),
    ((0.64, -0.05, -0.6), 0.2),
    ((0.68, -0.1, -0.85), 0.28),
    ((0.6, -0.2, -0.95), 0.4),
    ((0.3, -0.4, -0.96), 0.35),
    ((0.0, -0.5, -0.95), 0.3),
    ((-0.2, -0.3, -0.94), 0.25),
    ((0.8, -0.1, -0.96), 0.3),
]

for loc, rad in liquid_drops:
    elem = mball.data.elements.new()
    elem.co = (loc[0] - mball.location.x, loc[1] - mball.location.y, loc[2] - mball.location.z)
    elem.radius = rad

deselect_all()
mball.select_set(True)
bpy.context.view_layer.objects.active = mball
bpy.ops.object.convert(target='MESH')
slime_mesh = bpy.context.active_object
slime_mesh.data.materials.append(mat_slime)
bpy.ops.object.shade_smooth()
parts.append(slime_mesh)

deselect_all()
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()

barrel = bpy.context.view_layer.objects.active
barrel.name = "Toxic_Barrel_Baked_4K"

bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
bpy.ops.object.mode_set(mode='OBJECT')

bake_img = bpy.data.images.new("Barrel_Bake_4K_Diffuse", width=4096, height=4096)

for mat in barrel.data.materials:
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex_node = nodes.new('ShaderNodeTexImage')
    tex_node.image = bake_img
    tex_node.name = "BAKE_TARGET"
    nodes.active = tex_node
    for n in nodes:
        if n.type == 'BSDF_PRINCIPLED':
             n.inputs['Metallic'].default_value = 0.0
        n.select = (n.name == "BAKE_TARGET")

bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.device = 'CPU'
bpy.context.scene.cycles.samples = 16
bpy.context.scene.render.bake.use_pass_direct = False
bpy.context.scene.render.bake.use_pass_indirect = False
bpy.context.scene.render.bake.use_pass_color = True
bpy.context.scene.render.bake.margin = 16

print("Proses baking sedang berjalan...")
bpy.ops.object.bake(type='DIFFUSE', save_mode='INTERNAL')
print("Baking Selesai!")

barrel.data.materials.clear()
baked_mat = bpy.data.materials.new(name="M_Baked_ToxicBarrel")
baked_mat.use_nodes = True
nodes = baked_mat.node_tree.nodes
links = baked_mat.node_tree.links
nodes.clear()

out = nodes.new('ShaderNodeOutputMaterial')
out.location = (300, 0)
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
bsdf.location = (0, 0)
bsdf.inputs['Roughness'].default_value = 0.3 
tex = nodes.new('ShaderNodeTexImage')
tex.image = bake_img
tex.location = (-300, 0)

links.new(tex.outputs[0], bsdf.inputs['Base Color'])
links.new(bsdf.outputs[0], out.inputs[0])
barrel.data.materials.append(baked_mat)