# Boids in Niva

An idiomatic Niva port of Aloe's
[examples/boids.aloe](../../2026-09-02-aloe-racket/examples/boids.aloe),
plus two renderers.

| Folder | What | Run |
|---|---|---|
| `sim/` | The port itself: `Vec2`, `Boid`, `Flock`. No `main.niva`; it's shared code. | — |
| `headless/` | Aloe's 3-boid demo, printed. Tests pin step 1 to Aloe's exact output. | `niva run`, `niva test` |
| `world/` | Rules that only the renderers need: `Screen`, random flocks, edge wrapping, a speed cap. | — |
| `imgui/` | A window drawn with Dear ImGui (imgui-java), one step per frame. Esc quits. | `./run.sh` |
| `png/` | Java2D, no window: writes `frame-0.png` … `frame-400.png`. | `niva run` |

Niva builds every `.niva` file under the folder that holds `main.niva`, and
nothing outside it. So each front end is its own project and pulls in
`sim/` (and `world/`) through a symlink.

## Aloe → Niva

- `(Point T)` → `Vec2` of Doubles. Niva generics have no bounds, so
  `T + T` doesn't resolve. Aloe's own notes already make `Boid` and `Sim`
  monomorphic.
- `define-class` methods → `extend Boid [ on … ]` blocks. Fields are in
  scope by name, and `+ - * /` are ordinary methods on `Vec2`.
- `neighbors` (fold + cons) → `filter:`. `cohere`/`align` (map + fold) →
  `(others map: [it position]) mean`, using a `List::Vec2 mean` method.
- `Sim` → `Flock`. As in Aloe, `step` returns a new value and mutates nothing.
- Methods aren't tied to their type, so `world/` adds `Flock stepOn:`
  and `Boid wrapTo:` without touching `sim/`.

## Aloe's rules speed up forever

Boids only see neighbors ahead of them (`in-view?`). Cohesion therefore
pulls stragglers forward, and nothing pulls the leaders back. With 150
random boids, mean speed goes from 1.6 to 40 px/step over 1000 steps and
keeps climbing. With all-around vision it decays to 0.3 instead. `sim/`
keeps Aloe's behavior. `world/` caps speed at 4 (`Flock maxSpeed`), which
is what classic boids do.

## Graphics options

- **ImGui** (used in `imgui/`). This is what gavr uses: bazar has three
  ImGui programs, and the generated Gradle build has an ImGui fix for
  macOS. Immediate mode suits one-step-per-frame, and it comes with
  sliders and buttons for tuning the rules live.
  On this machine (one 4K monitor at scale 2, with GNOME's
  `xwayland-native-scaling`):
  - Under XWayland, GLFW ignores `Xft.dpi: 192`, so the window comes out
    half size. Native Wayland gets the 2x scale right (framebuffer scale
    2.0). The ImGui font is drawn at 1x and stretched, so it's a bit soft.
  - On Wayland there's no title bar. GNOME leaves title bars to the app,
    and GLFW hands that to libdecor. Since libdecor 0.2.3 (May 2025), its
    GTK plugin won't run off the process's first thread, because GTK isn't
    thread-safe. The JVM never runs `main` there. The cairo plugin has no
    such check (`sudo apt install libdecor-0-plugin-1-cairo`).
  - Exiting the JVM with the window open (Ctrl+C, kill, `exitProcess`)
    segfaults in NVIDIA's EGL driver and leaves an `hs_err_pid*.log`. A
    normal close (Esc, Alt+F4) is clean.
  - The monitor runs at 29.96 Hz and ImGui waits for vsync, hence 29 fps.
    A step takes 0.4 ms.
- **Java2D** (used in `png/`). Built into the JDK, so no dependencies or
  native libraries. Good for snapshots and tests. A live Swing window
  would need the same `@emit "object : …"` trick the ImGui binding uses,
  to subclass `JPanel`.
- **GTK4/Adwaita** (java-gi). bazar's `gtk.bind.niva` covers widgets only
  (no DrawingArea or Cairo) and uses older syntax.
- **Raylib**. It isn't in bazar, the Niva repo, or any of gavr's public
  repos. It would need new bindings to a Java raylib library such as
  jaylib. raylib's flat static API should map neatly onto `Bind`. Untried.
- **Compose**. Niva has a `jvmCompose` target, but its help text says
  "not supported yet", and bazar's Compose examples are in `old/`.

## Niva gotchas hit along the way

- Keyword args are now `canSee(other): Boid`. The older `other::Boid`
  form is parsed as a generic type named `other`.
- A method needs an explicit `-> Type` to be callable from files that
  compile before it (files go in name order).
- `on:` can't be a keyword, because `on` starts method declarations.
- `"${a b}"` is passed to Kotlin unchanged, so only `$name` interpolation
  works.
- No operator precedence between `&&` and comparisons; add parens.
  Arithmetic does have precedence (`2 + 3 * 4` is 14).
- `%` on Doubles is a remainder, not a floor-mod. There is no `sqrt`;
  `world/math.bind.niva` binds Kotlin's.
- **Compiler bug:** a bound `@emit` unary used as a binary operand
  (`1.0 + x sqrt`) generates broken Kotlin. Assign it to a name first.
- `niva run` exits 0 even when the Kotlin build fails.
