# Little Donut

A cozy 3D donut-shop game for a young child, built in **Godot 4.5.2** with original **Blender** characters and shop art. Designed for landscape Android touchscreens; also playable with a mouse on Linux.

## Play

1. **Cut:** tap the round cutter to press a donut out of the dough.
2. **Bake:** drag the donut up into Pip's oven, or tap **Bake**. It takes four seconds, with no burning or failure.
3. **Frost:** pick strawberry, chocolate, vanilla, or blueberry and rub over the donut. Colors can overlap and mix.
4. **Decorate:** drag a rainbow, star, or sugar-pearl jar onto the donut. You can also select a jar and tap or sweep over the donut. **Clear tops** removes the toppings without removing frosting.
5. **Serve:** celebrate your creation with Pip the bear and Bean the bunny, then **Make another**.

The camera stays at the workbench. There are no movement controls, orders to remember, scores, time limits, ads, purchases, accounts, or network features. The sound button toggles gentle synthesized chimes. Visual cues and large illustrated tools supplement the written instructions; a parent may want to demonstrate the first recipe. No spoken narration is included.

## Install on Android

Build the APK with `tools/build_android.sh` (see [Android build setup](#android-build-setup)). It is written to `builds/little-donut-android.apk` as a debug-signed prototype for sideloading; the `builds/` folder is not committed.

- Copy the APK to your Android phone/tablet and open it from Files.
- If Android asks, allow that file manager to install this app.
- Open **Little Donut** and turn the device sideways.

The package targets ARM64 and ARMv7 devices, Android 7.0/API 24 or newer, using Godot's OpenGL compatibility renderer. It requests no Android permissions. It is not a Play Store release. Performance and touch behavior on your particular physical Android device still need testing.

A Linux executable can be exported to `builds/little-donut-linux.x86_64` (see below). Double-click it, or launch it from a terminal. If your graphics driver has trouble, run `LIBGL_ALWAYS_SOFTWARE=1 builds/little-donut-linux.x86_64`.

## Open and edit

Import `project.godot` into Godot **4.5.2** (standard/GDScript edition), then press **F6** in the main scene or **F5** to play. Later Godot 4.x versions may also work but were not used for this build. Blender is **not needed to play** or import the Godot project: the exported GLBs are already included.

`tools/run.sh` discovers Godot on PATH, accepts a `GODOT_BIN` override, and can use an installed Godot Flatpak. Run `tools/run.sh --editor` to open the project.

## Project layout

| Location | Purpose |
| --- | --- |
| `scenes/main.tscn` | Entry scene: shop, lights, camera, oven, helpers, confetti, donut, HUD |
| `scenes/hud.tscn`, `scripts/hud.gd` | Anchored HUD built from containers; reports taps and jar drags |
| `scenes/tool_button.tscn` | Illustrated tool button instanced into the HUD's tool row |
| `scripts/game.gd` | Recipe state machine, workbench gestures, baking, sounds |
| `scripts/donut.gd` | Shared torus meshes, paintable frosting texture, MultiMesh toppings |
| `scripts/toy_icon.gd` | Original vector illustrations for the touch tools |
| `assets/*.glb` | Original Blender shop, bear, and bunny meshes |
| `art/*.blend` | Editable Blender source for the three assets |
| `tools/create_assets.py` | Reproducible Blender modeling and GLB export script |
| `tests/input_test.gd` | Godot viewport touch/mouse event integration test |
| `tests/smoke_test.gd` | Recipe transition and topping-bound checks |
| `tests/visual_test.gd` | Renders stage previews into `builds/previews` (needs a display) |
| `export_presets.cfg` | Android and Linux export presets |

To rebuild the art with Blender 5.2:

```sh
blender --background --factory-startup --python tools/create_assets.py
```

For the installed Flatpak, use `flatpak run org.blender.Blender` in place of `blender`. The script regenerates the three GLBs and three `.blend` sources. Art and build folders have `.gdignore` files so Godot imports only runtime assets.

## Android build setup

Install the **matching Godot 4.5.2 export templates**, a full **JDK 17**, and the **Android SDK** with platform-tools and build-tools 35.0.1. Set **Java SDK Path** and **Android SDK Path** in Godot's **Editor Settings → Export → Android**, then run:

```sh
tools/build_android.sh
```

Godot generates/uses a development keystore. This build’s key is saved locally at `builds/debug.keystore` (standard debug alias `androiddebugkey`, password `android`). Set Godot’s Debug Keystore field to that file to keep later builds installable as updates. Signing keys and machine-specific paths are deliberately not committed. The preset disables Gradle and exports a standard APK. Android texture imports are enabled in `project.godot`.

See the [official Godot Android export guide](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html) for SDK installation details or production signing.

For a Linux release, install its matching export template and run:

```sh
tools/run.sh --headless --export-release Linux builds/little-donut-linux.x86_64
```

## Verification and limits

```sh
tools/test.sh
# With a graphical display, capture each stage into builds/previews:
tools/run.sh --script tests/visual_test.gd
# Or a single decorated donut:
tools/run.sh --script tests/visual_test.gd -- --showcase
```

GDScript is formatted with [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit): `gdformat scripts tests tools`.

Tests cover the complete recipe, touch and mouse input, donut-to-oven dragging, continuous frosting strokes, color changes, extra-finger handling, jar dragging, rejecting toppings in the hole, the 220-topping cap, serving, and replay. The scene was also rendered and reviewed using Mesa software OpenGL on Linux.

This is a playable first prototype: one donut shape, one shop, an oven, four frostings, and three topping types. Helpers have simple procedural work/idle animations. Frosting and the current donut are held in memory; mute preference and completed-donut count are saved locally. There is no gallery or resume-after-app-termination yet. Toppings stop accumulating at 220 to bound mobile rendering cost. The UI is designed at 1280×800 and anchored to the screen edges; wider phones see more of the shop instead of side bars.

## License

Copyright (C) 2026 Little Donut contributors.

Little Donut's original code, scenes, characters, models, icons, sounds, and editable art sources are licensed under the **GNU Affero General Public License, version 3 or (at your option) any later version** (`AGPL-3.0-or-later`). See [LICENSE.txt](LICENSE.txt) for the full terms. This program is distributed without any warranty, including the implied warranties of merchantability or fitness for a particular purpose.

Corresponding source, including the editable art and build instructions, is available in the [project repository](https://github.com/tsloughter/donut_shop). When distributing a binary, provide its matching Corresponding Source under the AGPL's terms.

The in-game **Licenses** button displays the project license, source location, and Godot's notices. Both export presets include `LICENSE.txt` and `assets/GODOT-LICENSE.txt` so these remain readable in Android and Linux builds.

The bundled Godot runtime remains under its own MIT license and third-party licenses. Their full notices are in [assets/GODOT-LICENSE.txt](assets/GODOT-LICENSE.txt), with another generated copy at `builds/GODOT-LICENSE.txt`. Regenerate them for a new engine version with `tools/run.sh --headless --script tools/write_licenses.gd`. See also the [Godot license page](https://godotengine.org/license/) and [Godot's license inclusion guidance](https://docs.godotengine.org/en/4.5/about/complying_with_licenses.html).
