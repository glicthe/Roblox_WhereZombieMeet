import bpy
import bmesh
import math
import random

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

def create_mat(name, c_base, m_type):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    out = nodes.new('ShaderNodeOutputMaterial')
    out.location = (300, 0)
    
    if m_type == 2:
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.location = (0, 0)
        
        noise_c = nodes.new('ShaderNodeTexNoise')
        noise_c.inputs['Scale'].default_value = 6.0
        
        ramp_c = nodes.new('ShaderNodeValToRGB')
        ramp_c.color_ramp.elements[0].color = (0.25, 0.12, 0.04, 1)
        ramp_c.color_ramp.elements[1].color = (0.35, 0.18, 0.06, 1)
        
        voronoi = nodes.new('ShaderNodeTexVoronoi')
        voronoi.inputs['Scale'].default_value = 14.0
        
        noise_b = nodes.new('ShaderNodeTexNoise')
        noise_b.inputs['Scale'].default_value = 25.0
        
        mix_b = nodes.new('ShaderNodeMix')
        mix_b.data_type = 'FLOAT'
        mix_b.inputs[0].default_value = 0.7
        
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.65
        bump.inputs['Distance'].default_value = 0.15
        
        links.new(noise_c.outputs[0], ramp_c.inputs[0])
        links.new(ramp_c.outputs[0], bsdf.inputs['Base Color'])
        links.new(voronoi.outputs['Distance'], mix_b.inputs[6])
        links.new(noise_b.outputs[0], mix_b.inputs[7])
        links.new(mix_b.outputs[0], bump.inputs['Height'])
        links.new(bump.outputs[0], bsdf.inputs['Normal'])
        links.new(bsdf.outputs[0], out.inputs[0])
        
        bsdf.inputs['Roughness'].default_value = 0.85
        bsdf.inputs['Metallic'].default_value = 0.0
        return mat

    mix_shader = nodes.new('ShaderNodeMixShader')
    mix_shader.location = (100, 0)
    
    bsdf_clean = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf_clean.location = (-150, 150)
    bsdf_clean.inputs['Base Color'].default_value = c_base
    if m_type == 0:
        bsdf_clean.inputs['Metallic'].default_value = 1.0
        bsdf_clean.inputs['Roughness'].default_value = 0.25
    else:
        bsdf_clean.inputs['Roughness'].default_value = 0.5
        
    bsdf_rust = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf_rust.location = (-150, -150)
    bsdf_rust.inputs['Base Color'].default_value = (0.28, 0.12, 0.03, 1)
    bsdf_rust.inputs['Roughness'].default_value = 0.95
    bsdf_rust.inputs['Metallic'].default_value = 0.1
    
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 6.0
    noise.inputs['Detail'].default_value = 15.0
    
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.55
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

mat_metal = create_mat("M_Metal", (0.2, 0.21, 0.22, 1), 0)
mat_red = create_mat("M_Red", (0.45, 0.05, 0.05, 1), 1)
mat_green = create_mat("M_Green", (0.1, 0.18, 0.1, 1), 1)
mat_orange = create_mat("M_Orange", (0.55, 0.2, 0.01, 1), 1)
mat_blue = create_mat("M_Blue", (0.05, 0.15, 0.35, 1), 1)
mat_purple = create_mat("M_Purple", (0.25, 0.05, 0.25, 1), 1)
mat_food = create_mat("M_Food", (0, 0, 0, 1), 2)

bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.5, depth=0.8, location=(0,0,0))
m_body = bpy.context.active_object
m_body.data.materials.append(mat_metal)
m_body.data.materials.append(mat_red)

bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(m_body.data)
for f in bm.faces:
    if f.normal.z > 0.9:
        bm.faces.remove(f)
bmesh.update_edit_mesh(m_body.data)
bpy.ops.object.mode_set(mode='OBJECT')

mod_solid = m_body.modifiers.new(name="Solid", type='SOLIDIFY')
mod_solid.thickness = 0.08
mod_solid.offset = 1.0
bpy.ops.object.modifier_apply(modifier="Solid")

bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(m_body.data)
for f in bm.faces:
    dist = math.sqrt(f.calc_center_median().x**2 + f.calc_center_median().y**2)
    if dist > 0.48 and abs(f.normal.z) < 0.1:
        f.material_index = 1
    else:
        f.material_index = 0

for i in range(1, 16):
    z_cut = -0.4 + (0.8 / 16) * i
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z_cut), plane_no=(0, 0, 1))

for v in bm.verts:
    dist = math.sqrt(v.co.x**2 + v.co.y**2)
    if -0.38 < v.co.z < 0.38 and dist > 0.45:
        idx = round((v.co.z + 0.4) / (0.8 / 16))
        if idx % 2 == 0:
            v.co.x *= 0.88
            v.co.y *= 0.88

bmesh.update_edit_mesh(m_body.data)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_smooth()
es_body = m_body.modifiers.new(name="ES", type='EDGE_SPLIT')
es_body.split_angle = 0.52
bpy.ops.object.modifier_apply(modifier="ES")

bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.43, depth=0.015, location=(0,0,0))
m_lid = bpy.context.active_object
m_lid.data.materials.append(mat_metal)

bpy.ops.mesh.primitive_torus_add(major_radius=0.1, minor_radius=0.015, location=(0, -0.15, 0.01))
tab = bpy.context.active_object
tab.scale = (1, 1, 0.1)
tab.data.materials.append(mat_metal)

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.03, depth=0.02, location=(0, -0.15, 0.015))
rivet = bpy.context.active_object
rivet.data.materials.append(mat_metal)

bpy.ops.object.select_all(action='DESELECT')
tab.select_set(True)
rivet.select_set(True)
m_lid.select_set(True)
bpy.context.view_layer.objects.active = m_lid
bpy.ops.object.join()
bpy.ops.object.shade_smooth()

bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(m_lid.data)
for v in bm.verts:
    v.co.y += 0.43
bmesh.update_edit_mesh(m_lid.data)
bpy.ops.object.mode_set(mode='OBJECT')
es_lid = m_lid.modifiers.new(name="ES", type='EDGE_SPLIT')
es_lid.split_angle = 0.52
bpy.ops.object.modifier_apply(modifier="ES")

bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.41, depth=0.6, location=(0,0,0))
m_food_full = bpy.context.active_object
m_food_full.data.materials.append(mat_food)
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(m_food_full.data)
for v in bm.verts:
    v.co.z += 0.3
    if v.co.z > 0.5:
        v.co.z += random.uniform(-0.04, 0.04)
bmesh.update_edit_mesh(m_food_full.data)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_smooth()

bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.41, depth=0.6, location=(0,0,0))
m_food_half = bpy.context.active_object
m_food_half.data.materials.append(mat_food)
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(m_food_half.data)
for v in bm.verts:
    v.co.z += 0.3
    if v.co.z > 0.5:
        if v.co.x > 0:
            v.co.z -= (v.co.x * 1.5)
        v.co.z += random.uniform(-0.06, 0.06)
bmesh.update_edit_mesh(m_food_half.data)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_smooth()

data = [
    ((0.0, 0.0, 0.4), (0, 0, 0.5), 0, mat_red),
    ((0.98, 0.6, 0.4), (0, 0, 1.2), 0, mat_green),
    ((-0.98, 0.5, 0.4), (0, 0, -0.4), 0, mat_orange),
    ((0.9, -0.9, 0.4), (0, 0, 2.0), 0, mat_blue),
    ((-0.9, -0.8, 0.4), (0, 0, 0.0), 1, mat_purple),
    ((0.05, -0.05, 1.2), (0, 0, -0.5), 2, mat_orange),
    ((0.95, 0.55, 1.2), (0, 0, 0.8), 0, mat_red),
    ((-0.95, -0.85, 1.2), (0, 0, 2.1), 3, mat_green),
    ((-0.05, 0.05, 2.0), (0, 0, 1.0), 1, mat_blue),
    ((2.0, 0.0, 0.5), (1.5708, 0, 1.5708), 4, mat_orange),
    ((-2.0, -0.2, 0.5), (1.5708, 0, -1.5708), 4, mat_red),
    ((0.0, -2.0, 0.5), (1.5708, 0, 0.0), 4, mat_green),
    ((-0.98, 0.5, 1.24), (1.5708, 0, 0.0), 4, mat_purple),
    ((0.9, -0.9, 1.24), (1.5708, 0, 1.5708), 4, mat_orange)
]

final_cans = []

for loc, rot, state, l_mat in data:
    bpy.ops.object.select_all(action='DESELECT')
    
    b = m_body.copy()
    b.data = m_body.data.copy()
    bpy.context.collection.objects.link(b)
    b.data.materials[1] = l_mat
    
    l = m_lid.copy()
    l.data = m_lid.data.copy()
    bpy.context.collection.objects.link(l)
    l.location = (0, -0.43, 0.38)
    
    f = None
    if state == 0:
        l.rotation_euler = (0, 0, 0)
    elif state == 1:
        l.rotation_euler = (0.43, 0, 0)
        f = m_food_full.copy()
        f.data = m_food_full.data.copy()
        bpy.context.collection.objects.link(f)
        f.location = (0, 0, -0.38)
    elif state == 2:
        l.rotation_euler = (1.65, 0, 0)
        f = m_food_half.copy()
        f.data = m_food_half.data.copy()
        bpy.context.collection.objects.link(f)
        f.location = (0, 0, -0.38)
    elif state == 3:
        l.rotation_euler = (2.1, 0, 0)
        f = m_food_half.copy()
        f.data = m_food_half.data.copy()
        bpy.context.collection.objects.link(f)
        f.location = (0, 0, -0.38)
    elif state == 4:
        l.rotation_euler = (2.3, 0, 0)

    b.select_set(True)
    l.select_set(True)
    if f:
        f.select_set(True)
        
    bpy.context.view_layer.objects.active = b
    bpy.ops.object.join()
    
    b.location = loc
    b.rotation_euler = rot
    final_cans.append(b)

bpy.data.objects.remove(m_body, do_unlink=True)
bpy.data.objects.remove(m_lid, do_unlink=True)
bpy.data.objects.remove(m_food_full, do_unlink=True)
bpy.data.objects.remove(m_food_half, do_unlink=True)

bpy.ops.object.select_all(action='DESELECT')
for c in final_cans:
    c.select_set(True)
bpy.context.view_layer.objects.active = final_cans[0]
bpy.ops.object.join()
pile = bpy.context.view_layer.objects.active
pile.name = "Baked_Ration_Pile_4K"

bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
bpy.ops.object.mode_set(mode='OBJECT')

bake_img = bpy.data.images.new("Ration_Bake_4K", width=4096, height=4096)

for mat in pile.data.materials:
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

pile.data.materials.clear()
baked_mat = bpy.data.materials.new(name="M_Baked_Pile")
baked_mat.use_nodes = True
nodes = baked_mat.node_tree.nodes
links = baked_mat.node_tree.links
nodes.clear()

out = nodes.new('ShaderNodeOutputMaterial')
out.location = (300, 0)
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
bsdf.location = (0, 0)
tex = nodes.new('ShaderNodeTexImage')
tex.image = bake_img
tex.location = (-300, 0)

links.new(tex.outputs[0], bsdf.inputs['Base Color'])
links.new(bsdf.outputs[0], out.inputs[0])
pile.data.materials.append(baked_mat)