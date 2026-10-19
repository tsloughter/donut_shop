"""Rebuild the original Little Donut art in Blender and export it for Godot.

Geometry is generated with bmesh in Godot's Y-up coordinates and converted to Blender's Z-up
once, when it is written. Static parts are merged into one mesh per material so the shop and
each helper cost a handful of draw calls on a phone; only animated parts stay separate.

Run:  blender --background --factory-startup --python tools/create_assets.py
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
ART = os.path.join(ROOT, "art")
BEVEL_SEGMENTS = 3
COLORS = {
    "cream": (0.96, 0.88, 0.71),
    "wall": (0.93, 0.77, 0.65),
    "mint": (0.36, 0.65, 0.55),
    "mintlight": (0.62, 0.82, 0.69),
    "pink": (0.88, 0.40, 0.49),
    "peach": (0.95, 0.63, 0.45),
    "wood": (0.69, 0.40, 0.23),
    "board": (0.88, 0.66, 0.40),
    "dark": (0.22, 0.12, 0.10),
    "white": (1, 0.96, 0.86),
    "bear": (0.64, 0.34, 0.18),
    "muzzle": (0.92, 0.70, 0.44),
    "bunny": (0.96, 0.83, 0.71),
    "lilac": (0.63, 0.51, 0.75),
    "glass": (0.52, 0.77, 0.81),
    "gold": (0.88, 0.62, 0.25),
    "bread": (0.77, 0.43, 0.18),
}
MATERIALS = {}


def to_blender(point):
    """Godot (x, y up, z toward camera) to Blender (x, y into screen, z up)."""
    return Vector((point[0], -point[2], point[1]))


def size_to_blender(size):
    return Matrix.Diagonal((size[0], size[2], size[1], 1))


def make_materials():
    for name, color in COLORS.items():
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*color, 1)
        m.use_nodes = True
        m.use_backface_culling = True
        # Materials outlive the per-asset scene purge.
        m.use_fake_user = True
        principled = m.node_tree.nodes.get("Principled BSDF")
        principled.inputs["Base Color"].default_value = (*color, 1)
        principled.inputs["Roughness"].default_value = 0.65
        MATERIALS[name] = m


def set_smooth(bm, smooth):
    for face in bm.faces:
        face.smooth = smooth


class Group:
    """Parts that move together. Everything added here becomes one mesh per material."""

    def __init__(self, name):
        self.name = name
        self.meshes = {}

    def add(self, bm, material):
        target = self.meshes.setdefault(material, bmesh.new())
        scratch = bpy.data.meshes.new("scratch")
        bm.to_mesh(scratch)
        bm.free()
        target.from_mesh(scratch)
        bpy.data.meshes.remove(scratch)

    def realize(self, collection, parent=None, origin=(0, 0, 0)):
        """Write one object per material, with vertices relative to origin (Godot space)."""
        objects = []
        pivot = to_blender(origin)
        for material, bm in self.meshes.items():
            bm.transform(Matrix.Translation(-pivot))
            mesh = bpy.data.meshes.new(self.name if len(self.meshes) == 1 else f"{self.name} {material}")
            bm.to_mesh(mesh)
            bm.free()
            mesh.materials.append(MATERIALS[material])
            obj = bpy.data.objects.new(mesh.name, mesh)
            obj.location = pivot
            obj.parent = parent
            # Keeps the big faces of beveled boxes flat under smooth shading; applied on export.
            obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
            collection.objects.link(obj)
            objects.append(obj)
        return objects


def sphere(group, center, radii, material):
    # Tessellate by size: an eye glint does not need the head's polygon budget.
    largest = max(radii)
    segments, rings = (24, 16) if largest >= 0.3 else (16, 10) if largest >= 0.1 else (8, 5)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    bm.transform(Matrix.Translation(to_blender(center)) @ size_to_blender(radii))
    set_smooth(bm, True)
    group.add(bm, material)


def box(group, center, size, material, bevel=0.08):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(size_to_blender(size))
    if bevel:
        bmesh.ops.bevel(
            bm,
            geom=bm.verts[:] + bm.edges[:],
            offset=bevel,
            segments=BEVEL_SEGMENTS,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )
    bm.transform(Matrix.Translation(to_blender(center)))
    set_smooth(bm, True)
    group.add(bm, material)


def cylinder(group, center, radius, depth, material):
    bm = bmesh.new()
    segments = 32 if radius >= 0.2 else 12
    bmesh.ops.create_cone(
        bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth
    )
    bm.transform(Matrix.Translation(to_blender(center)))
    set_smooth(bm, True)
    group.add(bm, material)


def tube(group, points, radius, material, sides=8):
    """A smooth tube along a polyline of Godot-space points, closed at both ends."""
    bm = bmesh.new()
    rings = []
    for i, point in enumerate(points):
        prev = points[max(i - 1, 0)]
        following = points[min(i + 1, len(points) - 1)]
        tangent = (to_blender(following) - to_blender(prev)).normalized()
        side = tangent.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(tangent)
        center = to_blender(point)
        ring = []
        for j in range(sides):
            angle = j * math.tau / sides
            ring.append(bm.verts.new(center + (side * math.cos(angle) + up * math.sin(angle)) * radius))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(sides):
            bm.faces.new((a[j], a[(j + 1) % sides], b[(j + 1) % sides], b[j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    set_smooth(bm, True)
    group.add(bm, material)


def new_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def export(name, collection):
    bpy.context.view_layer.update()
    for obj in bpy.data.objects:
        obj.select_set(obj.name in collection.all_objects)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ASSETS, name + ".glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        # Nothing is textured, so UVs would only pad every vertex.
        export_texcoords=False,
    )


def save_blend(name):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, name + ".blend"))


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    bpy.data.orphans_purge(do_recursive=True)


def character(kind):
    collection = new_collection(kind)
    fur = kind
    body = Group("Body")
    sphere(body, (0, 0.78, 0), (0.52, 0.65, 0.38), fur)
    sphere(body, (0, 0.78, 0.29), (0.44, 0.46, 0.15), "mint" if kind == "bear" else "lilac")
    box(body, (0, 0.70, 0.44), (0.32, 0.18, 0.045), "white", 0.035)
    for x in (-0.27, 0.27):
        sphere(body, (x, 0.16, 0.10), (0.23, 0.18, 0.32), fur)
    sphere(body, (0, 1.66, 0.025), (0.63, 0.57, 0.46), fur)
    if kind == "bear":
        for x in (-0.48, 0.48):
            sphere(body, (x, 2.07, 0.01), (0.25, 0.26, 0.18), fur)
            sphere(body, (x, 2.08, 0.145), (0.15, 0.16, 0.06), "muzzle")
    else:
        for x in (-0.29, 0.29):
            sphere(body, (x, 2.30, -0.01), (0.18, 0.62, 0.16), fur)
            sphere(body, (x, 2.34, 0.13), (0.09, 0.43, 0.025), "pink")
    sphere(body, (0, 1.49, 0.421), (0.34, 0.24, 0.12), "muzzle" if kind == "bear" else "white")
    sphere(body, (0, 1.59, 0.547), (0.095, 0.065, 0.045), "dark")
    for x in (-0.245, 0.245):
        sphere(body, (x, 1.77, 0.443), (0.05, 0.071, 0.028), "dark")
        sphere(body, (x - 0.01, 1.793, 0.47), (0.014, 0.018, 0.009), "white")
        sphere(body, (x * 1.55, 1.52, 0.403), (0.105, 0.055, 0.025), "pink")
    smile = []
    for i in range(17):
        angle = math.pi + math.pi * i / 16
        smile.append(Vector((0.13 * math.cos(angle), 1.47 + 0.07 * math.sin(angle), 0.543)))
    tube(body, smile, 0.012, "dark")
    if kind == "bear":
        cylinder(body, (0, 2.16, 0.02), 0.37, 0.21, "white")
        for x, y in ((-0.24, 2.32), (0, 2.43), (0.24, 2.32)):
            sphere(body, (x, y, 0.02), (0.28, 0.25, 0.29), "white")
    else:
        for x in (-0.14, 0.14):
            sphere(body, (x, 1.13, 0.41), (0.15, 0.10, 0.075), "pink")
        sphere(body, (0, 1.13, 0.47), (0.07, 0.07, 0.05), "gold")
    body.realize(collection)
    # Paws are animated by the game, so each stays its own object.
    for x in (-0.59, 0.59):
        paw = Group("Paw")
        sphere(paw, (x, 0.85, 0.06), (0.19, 0.36, 0.20), fur)
        paw.realize(collection, origin=(x, 0.85, 0.06))
    export(kind, collection)
    save_blend(kind)
    clear_scene()


def shop():
    collection = new_collection("shop")
    room = Group("Shop")
    box(room, (0, -0.12, 0), (18, 0.20, 15), "cream")
    box(room, (0, 3.1, -4.5), (17, 6.5, 0.25), "cream")
    for i in range(-10, 11):
        box(room, (i * 0.72, 3.25, -4.34), (0.30, 6, 0.015), "wall", 0)
    box(room, (0, 0.35, -4.1), (17, 0.7, 0.3), "mint")
    # Mint cupboards and worktop.
    box(room, (0, 0.73, -3.15), (12, 1.4, 1.55), "mint")
    box(room, (0, 1.48, -3.10), (12.2, 0.15, 1.75), "board")
    for x in (-4.8, -3.2, -1.6, 0, 1.6, 3.2, 4.8):
        box(room, (x, 0.78, -2.345), (1.42, 1.03, 0.06), "mintlight", 0.045)
        sphere(room, (x, 1.12, -2.27), (0.055, 0.055, 0.04), "gold")
    # Window and chunky frame.
    box(room, (-3.65, 3.45, -4.11), (3.5, 2.5, 0.18), "white", 0.22)
    box(room, (-3.65, 3.45, -3.995), (3.22, 2.23, 0.04), "glass", 0.15)
    for x in (-4.45, -3.7, -2.8):
        sphere(room, (x, 3.65, -3.94), (0.38, 0.18, 0.025), "white")
    box(room, (-3.65, 3.45, -3.90), (0.10, 2.26, 0.10), "white")
    box(room, (-3.65, 3.45, -3.90), (3.23, 0.10, 0.10), "white")
    # Back sign blank; the label is native Godot text.
    box(room, (0, 3.65, -4.05), (3.3, 1.75, 0.20), "mint", 0.30)
    box(room, (0, 3.65, -3.93), (3.05, 1.50, 0.045), "cream", 0.22)
    # Shelves with pastel jars.
    for y in (2.65, 3.9):
        box(room, (3.9, y, -3.94), (3.4, 0.13, 0.8), "wood")
        for j, color in enumerate(("pink", "mintlight", "lilac", "white")):
            x = 2.8 + j * 0.7
            cylinder(room, (x, y + 0.35, -3.97), 0.21, 0.51, color)
            cylinder(room, (x, y + 0.63, -3.97), 0.23, 0.10, "gold")
    # Warm lamps.
    for x in (-2.2, 2.2):
        cylinder(room, (x, 5, -1.9), 0.018, 1.4, "dark")
        sphere(room, (x, 4.35, -1.9), (0.42, 0.20, 0.42), "peach")
        sphere(room, (x, 4.26, -1.9), (0.27, 0.075, 0.27), "white")
    # Foreground table. The donut and tools are interactive Godot meshes.
    box(room, (0, 0.12, 1.8), (12, 0.80, 5.4), "mint", 0.18)
    box(room, (0, 0.55, 1.8), (12.3, 0.20, 5.5), "wood", 0.12)
    box(room, (0, 0.70, 1.8), (12.35, 0.16, 5.55), "board", 0.10)
    for x in (-4, -2, 0, 2, 4):
        box(room, (x, 0.786, 1.8), (0.015, 0.005, 5.3), "wood", 0)
    # Props on the edges.
    cylinder(room, (-4.35, 1.06, 0.2), 0.30, 0.55, "white")
    for x in (-4.49, -4.28):
        box(room, (x, 1.60, 0.2), (0.06, 0.8, 0.06), "wood", 0.025)
        sphere(room, (x, 2.00, 0.2), (0.14, 0.20, 0.055), "wood")
    box(room, (4.35, 0.87, 1.2), (1.1, 0.12, 0.8), "white", 0.03)
    room.realize(collection)
    export("shop", collection)
    save_blend("shop")


clear_scene()
make_materials()
character("bear")
character("bunny")
shop()
print("Little Donut art exported.")
