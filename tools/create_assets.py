"""Rebuild original Little Donut art in Blender. Coordinates below use Godot Y-up."""
import bpy, math, os, sys
from mathutils import Vector
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
M={}
def mat(name, color, rough=.65):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough
    M[name]=m; return m
for n,c in {'cream':(.96,.88,.71),'wall':(.93,.77,.65),'mint':(.36,.65,.55),'mintlight':(.62,.82,.69),'pink':(.88,.40,.49),'peach':(.95,.63,.45),'wood':(.69,.40,.23),'board':(.88,.66,.40),'dark':(.22,.12,.10),'white':(1,.96,.86),'bear':(.64,.34,.18),'muzzle':(.92,.70,.44),'bunny':(.96,.83,.71),'lilac':(.63,.51,.75),'glass':(.52,.77,.81),'gold':(.88,.62,.25),'bread':(.77,.43,.18)}.items():mat(n,c)
def conv(p):return (p[0],-p[2],p[1])
def finish(o,n,c):
    o.name=n; o.data.materials.append(M[c]);
    for p in o.data.polygons:p.use_smooth=True
    return o
def ball(n,p,s,c):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=conv(p)); o=bpy.context.object; o.scale=(s[0],s[2],s[1]);return finish(o,n,c)
def box(n,p,s,c,bevel=.08):
    bpy.ops.mesh.primitive_cube_add(size=1,location=conv(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft toy edges','BEVEL');mod.width=bevel;mod.segments=3
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
    return finish(o,n,c)
def cylinder(n,p,r,d,c):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=r,depth=d,location=conv(p));return finish(bpy.context.object,n,c)
def torus(n,p,major,minor,c):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=16,location=conv(p),major_radius=major,minor_radius=minor);return finish(bpy.context.object,n,c)
def export(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets',name+'.glb'),export_format='GLB',use_selection=True,export_apply=True)
def character(kind):
    before=set(bpy.data.objects); fur='bear' if kind=='bear' else 'bunny'
    ball('Body',(0,.78,0),(.52,.65,.38),fur)
    ball('Apron',(0,.78,.29),(.44,.46,.15),'mint' if kind=='bear' else 'lilac')
    box('Apron pocket',(0,.70,.44),(.32,.18,.045),'white',.035)
    for x in [-.27,.27]:ball('Foot',(x,.16,.10),(.23,.18,.32),fur)
    for x in [-.59,.59]:ball('Paw',(x,.85,.06),(.19,.36,.20),fur)
    ball('Head',(0,1.66,.025),(.63,.57,.46),fur)
    if kind=='bear':
        for x in [-.48,.48]:
            ball('Round ear',(x,2.07,.01),(.25,.26,.18),fur);ball('Ear inner',(x,2.08,.145),(.15,.16,.06),'muzzle')
    else:
        for x in [-.29,.29]:
            ball('Long ear',(x,2.30,-.01),(.18,.62,.16),fur);ball('Ear inner',(x,2.34,.13),(.09,.43,.025),'pink')
    ball('Muzzle',(0,1.49,.421),(.34,.24,.12),'muzzle' if kind=='bear' else 'white')
    ball('Nose',(0,1.59,.547),(.095,.065,.045),'dark')
    for x in [-.245,.245]:
        ball('Eye',(x,1.77,.443),(.05,.071,.028),'dark');ball('Eye glint',(x-.01,1.793,.47),(.014,.018,.009),'white')
        ball('Cheek',(x*1.55,1.52,.403),(.105,.055,.025),'pink')
    # A smiling curved mouth.
    points=[]
    for i in range(17):
        a=math.pi+math.pi*i/16;points.append((.13*math.cos(a),1.47+.07*math.sin(a),.543))
    curve=bpy.data.curves.new('Smile','CURVE');curve.dimensions='3D';curve.bevel_depth=.012;curve.bevel_resolution=3
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for pt,co in zip(spline.points,points):pt.co=(*conv(co),1)
    obj=bpy.data.objects.new('Smile',curve);bpy.context.collection.objects.link(obj);obj.data.materials.append(M['dark'])
    if kind=='bear':
        cylinder('Hat band',(0,2.16,.02),.37,.21,'white')
        for x,y in [(-.24,2.32),(0,2.43),(.24,2.32)]:ball('Chef hat puff',(x,y,.02),(.28,.25,.29),'white')
    else:
        for x in [-.14,.14]:ball('Bow',(x,1.13,.41),(.15,.10,.075),'pink')
        ball('Bow knot',(0,1.13,.47),(.07,.07,.05),'gold')
    objs=set(bpy.data.objects)-before
    export(kind,list(objs))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art',kind+'.blend'))
    for o in objs:bpy.data.objects.remove(o,do_unlink=True)
character('bear');character('bunny')
box('Floor',(0,-.12,0),(18,.20,15),'cream')
box('Back wall',(0,3.1,-4.5),(17,6.5,.25),'cream')
for i in range(-10,11):box('Wallpaper stripe',(i*.72,3.25,-4.34),(.30,6,.015),'wall',0)
box('Wall skirting',(0,.35,-4.1),(17,.7,.3),'mint')
# Mint cupboards and worktop.
box('Back counter',(0,.73,-3.15),(12,1.4,1.55),'mint')
box('Back worktop',(0,1.48,-3.10),(12.2,.15,1.75),'board')
for x in [-4.8,-3.2,-1.6,0,1.6,3.2,4.8]:
    box('Cabinet inset',(x,.78,-2.345),(1.42,1.03,.06),'mintlight',.045)
    ball('Cabinet knob',(x,1.12,-2.27),(.055,.055,.04),'gold')
# Window and chunky frame.
box('Window frame',(-3.65,3.45,-4.11),(3.5,2.5,.18),'white',.22)
box('Morning sky',(-3.65,3.45,-3.995),(3.22,2.23,.04),'glass',.15)
for x in [-4.45,-3.7,-2.8]:ball('Cloud',(x,3.65,-3.94),(.38,.18,.025),'white')
box('Window mullion',(-3.65,3.45,-3.90),(.10,2.26,.10),'white')
box('Window crossbar',(-3.65,3.45,-3.90),(3.23,.10,.10),'white')
# Back sign blank, label is native Godot text.
box('Shop sign',(0,3.65,-4.05),(3.3,1.75,.20),'mint',.30)
box('Shop sign inset',(0,3.65,-3.93),(3.05,1.50,.045),'cream',.22)
# Shelves with pastel jars and pastries.
for y in [2.65,3.9]:
    box('Shelf',(3.9,y,-3.94),(3.4,.13,.8),'wood')
    for j in range(4):
        x=2.8+j*.7
        cylinder('Pantry jar',(x,y+.35,-3.97),.21,.51,['pink','mintlight','lilac','white'][j])
        cylinder('Jar lid',(x,y+.63,-3.97),.23,.10,'gold')
# Warm lamps.
for x in [-2.2,2.2]:
    cylinder('Lamp cord',(x,5,-1.9),.018,1.4,'dark')
    ball('Pendant shade',(x,4.35,-1.9),(.42,.20,.42),'peach')
    ball('Pendant light',(x,4.26,-1.9),(.27,.075,.27),'white')
# Foreground table. Donut and tools are interactive Godot meshes.
box('Counter base',(0,.12,1.8),(12,.80,5.4),'mint',.18)
box('Counter edge',(0,.55,1.8),(12.3,.20,5.5),'wood',.12)
box('Counter top',(0,.70,1.8),(12.35,.16,5.55),'board',.10)
for x in [-4,-2,0,2,4]:box('Wood inlay',(x,.786,1.8),(.015,.005,5.3),'wood',0)
# Props on the edges.
cylinder('Utensil pot',(-4.35,1.06,.2),.30,.55,'white')
for x in [-4.49,-4.28]:
    box('Spoon handle',(x,1.60,.2),(.06,.8,.06),'wood',.025)
    ball('Spoon end',(x,2.00,.2),(.14,.20,.055),'wood')
box('Napkin stack',(4.35,.87,1.2),(1.1,.12,.8),'white',.03)
export('shop',list(bpy.data.objects))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art','shop.blend'))
print('Little Donut art exported.')
