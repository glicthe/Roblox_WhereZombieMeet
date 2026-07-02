import bpy
import bmesh
import math
import random

for obj in list(bpy.context.scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

def deselect_all():
    for obj in bpy.context.selected_objects:
        obj.select_set(False)

def create_mat(name, m_type):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    out = nodes.new('ShaderNodeOutputMaterial')
    out.location = (300, 0)
    
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    bsdf.inputs['Metallic'].default_value = 0.0
    
    if m_type == "GORE":
        bsdf.inputs['Roughness'].default_value = 0.45
        
        noise1 = nodes.new('ShaderNodeTexNoise')
        noise1.inputs['Scale'].default_value = 2.0
        noise1.inputs['Detail'].default_value = 15.0
        
        voronoi1 = nodes.new('ShaderNodeTexVoronoi')
        voronoi1.inputs['Scale'].default_value = 12.0
        voronoi1.feature = 'F2'
        
        ramp1 = nodes.new('ShaderNodeValToRGB')
        ramp1.color_ramp.elements[0].position = 0.1
        ramp1.color_ramp.elements[0].color = (0.015, 0.0, 0.0, 1)
        ramp1.color_ramp.elements[1].position = 0.5
        ramp1.color_ramp.elements[1].color = (0.12, 0.01, 0.02, 1)
        ramp1.color_ramp.elements.new(0.8)
        ramp1.color_ramp.elements[2].color = (0.04, 0.0, 0.01, 1)
        
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.9
        
        links.new(noise1.outputs[0], ramp1.inputs[0])
        links.new(ramp1.outputs[0], bsdf.inputs['Base Color'])
        links.new(voronoi1.outputs['Distance'], bump.inputs['Height'])
        links.new(bump.outputs[0], bsdf.inputs['Normal'])
        
    elif m_type == "SPORE":
        bsdf.inputs['Roughness'].default_value = 0.35
        bsdf.inputs['Base Color'].default_value = (0.1, 0.02, 0.0, 1.0)
        
        noise2 = nodes.new('ShaderNodeTexNoise')
        noise2.inputs['Scale'].default_value = 8.0
        
        ramp2 = nodes.new('ShaderNodeValToRGB')
        ramp2.color_ramp.elements[0].position = 0.4
        ramp2.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1)
        ramp2.color_ramp.elements[1].position = 0.6
        ramp2.color_ramp.elements[1].color = (0.8, 1.0, 0.0, 1)
        
        if 'Emission Color' in bsdf.inputs:
            links.new(ramp2.outputs[0], bsdf.inputs['Emission Color'])
            bsdf.inputs['Emission Strength'].default_value = 5.0
        elif 'Emission' in bsdf.inputs:
            links.new(ramp2.outputs[0], bsdf.inputs['Emission'])
            
        bump2 = nodes.new('ShaderNodeBump')
        bump2.inputs['Strength'].default_value = 0.6
        voronoi2 = nodes.new('ShaderNodeTexVoronoi')
        voronoi2.inputs['Scale'].default_value = 25.0
        
        links.new(noise2.outputs[0], ramp2.inputs[0])
        links.new(voronoi2.outputs['Distance'], bump2.inputs['Height'])
        links.new(bump2.outputs[0], bsdf.inputs['Normal'])
        
    elif m_type == "BONE":
        bsdf.inputs['Roughness'].default_value = 0.6
        bsdf.inputs['Base Color'].default_value = (0.6, 0.55, 0.45, 1)
        
        noise3 = nodes.new('ShaderNodeTexNoise')
        noise3.inputs['Scale'].default_value = 15.0
        bump3 = nodes.new('ShaderNodeBump')
        bump3.inputs['Strength'].default_value = 0.4
        
        links.new(noise3.outputs[0], bump3.inputs['Height'])
        links.new(bump3.outputs[0], bsdf.inputs['Normal'])
        
    links.new(bsdf.outputs[0], out.inputs[0])
    return mat

mat_gore = create_mat("M_Gore", "GORE")
mat_spore = create_mat("M_ToxicSpore", "SPORE")
mat_bone = create_mat("M_Bone", "BONE")

parts = []

bpy.ops.object.metaball_add(type='BALL', radius=1.0, location=(0, 0, 0))
mball = bpy.context.active_object
mball.data.resolution = 0.05

blob_data = []
for i in range(40):
    a = random.uniform(0, math.pi * 2)
    d = random.uniform(0, 1.8)
    x = math.cos(a) * d
    y = math.sin(a) * d
    z = random.uniform(-0.2, 0.6) - (d * 0.15)
    r = random.uniform(0.15, 0.6)
    blob_data.append((x, y, z, r))

for x, y, z, r in blob_data:
    elem = mball.data.elements.new()
    elem.co = (x, y, z)
    elem.radius = r

deselect_all()
mball.select_set(True)
bpy.context.view_layer.objects.active = mball
bpy.ops.object.convert(target='MESH')
base_gore = bpy.context.active_object
base_gore.data.materials.append(mat_gore)

tex_meat = bpy.data.textures.new("Tex_Meat", type='CLOUDS')
tex_meat.noise_scale = 0.35
mod_disp = base_gore.modifiers.new("DispMeat", 'DISPLACE')
mod_disp.texture = tex_meat
mod_disp.strength = 0.25
bpy.ops.object.modifier_apply(modifier="DispMeat")
bpy.ops.object.shade_smooth()
parts.append(base_gore)

num_tentacles = 18
for i in range(num_tentacles):
    a = (i / num_tentacles) * (math.pi * 2) + random.uniform(-0.3, 0.3)
    d = random.uniform(0.4, 1.6)
    sx = math.cos(a) * d
    sy = math.sin(a) * d
    sz = random.uniform(-0.1, 0.3)
    
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.18, depth=random.uniform(1.5, 3.5), location=(sx, sy, sz))
    tentacle = bpy.context.active_object
    tentacle.data.materials.append(mat_gore)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(tentacle.data)
    for v in bm.verts:
        v.co.z += tentacle.dimensions.z / 2
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=15)
    
    freq = random.uniform(1.5, 3.5)
    amp = random.uniform(0.1, 0.35)
    phase_x = random.uniform(0, 10)
    phase_y = random.uniform(0, 10)
    
    for v in bm.verts:
        z_ratio = v.co.z / tentacle.dimensions.z
        v.co.x += math.sin(v.co.z * freq + phase_x) * amp * z_ratio
        v.co.y += math.cos(v.co.z * freq + phase_y) * amp * z_ratio
        scale_mod = max(0.02, 1.0 - (z_ratio * 0.95))
        v.co.x *= scale_mod
        v.co.y *= scale_mod
        
    bmesh.update_edit_mesh(tentacle.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    tentacle.rotation_euler = (random.uniform(0.2, 0.8) * math.sin(a), random.uniform(0.2, 0.8) * -math.cos(a), a)
    
    mod_disp_t = tentacle.modifiers.new("DispTentacle", 'DISPLACE')
    mod_disp_t.texture = tex_meat
    mod_disp_t.strength = 0.1
    bpy.ops.object.modifier_apply(modifier="DispTentacle")
    bpy.ops.object.shade_smooth()
    parts.append(tentacle)

for i in range(22):
    a = random.uniform(0, math.pi * 2)
    d = random.uniform(0.2, 1.3)
    sx = math.cos(a) * d
    sy = math.sin(a) * d
    sz = random.uniform(0.3, 1.1)
    
    bpy.ops.mesh.primitive_cube_add(size=random.uniform(0.3, 0.6), location=(sx, sy, sz))
    sac = bpy.context.active_object
    sac.data.materials.append(mat_spore)
    
    mod_sub = sac.modifiers.new("Sub", 'SUBSURF')
    mod_sub.levels = 3
    bpy.ops.object.modifier_apply(modifier="Sub")
    
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(sac.data)
    for v in bm.verts:
        v.co.x += random.uniform(-0.08, 0.08)
        v.co.y += random.uniform(-0.08, 0.08)
        v.co.z += random.uniform(-0.15, 0.15)
    bmesh.update_edit_mesh(sac.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    sac.rotation_euler = (random.uniform(0, 3.14), random.uniform(0, 3.14), random.uniform(0, 3.14))
    bpy.ops.object.shade_smooth()
    parts.append(sac)

for i in range(15):
    a = random.uniform(0, math.pi * 2)
    d = random.uniform(0.3, 1.5)
    sx = math.cos(a) * d
    sy = math.sin(a) * d
    sz = random.uniform(0.1, 0.7)
    
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.08, radius2=0.0, depth=random.uniform(0.4, 1.2), location=(sx, sy, sz))
    spike = bpy.context.active_object
    spike.data.materials.append(mat_bone)
    
    spike.rotation_euler = (random.uniform(-1.0, 1.0), random.uniform(-1.0, 1.0), random.uniform(0, 6.28))
    
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(spike.data)
    for v in bm.verts:
        v.co.x += random.uniform(-0.02, 0.02)
        v.co.y += random.uniform(-0.02, 0.02)
    bmesh.update_edit_mesh(spike.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    bpy.ops.object.shade_smooth()
    parts.append(spike)

deselect_all()
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()

nest = bpy.context.view_layer.objects.active
nest.name = "Zombie_Horror_Nest_4K"

bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.015)
bpy.ops.object.mode_set(mode='OBJECT')

bake_img = bpy.data.images.new("Nest_Bake_4K", width=4096, height=4096)

for mat in nest.data.materials:
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

bpy.ops.object.bake(type='DIFFUSE', save_mode='INTERNAL')

nest.data.materials.clear()
baked_mat = bpy.data.materials.new(name="M_Baked_HorrorNest")
baked_mat.use_nodes = True
nodes = baked_mat.node_tree.nodes
links = baked_mat.node_tree.links
nodes.clear()

out = nodes.new('ShaderNodeOutputMaterial')
out.location = (300, 0)
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
bsdf.location = (0, 0)
bsdf.inputs['Metallic'].default_value = 0.0
bsdf.inputs['Roughness'].default_value = 0.45 
tex = nodes.new('ShaderNodeTexImage')
tex.image = bake_img
tex.location = (-300, 0)

links.new(tex.outputs[0], bsdf.inputs['Base Color'])
links.new(bsdf.outputs[0], out.inputs[0])
nest.data.materials.append(baked_mat)