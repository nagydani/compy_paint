## Paint

Paint is a mouse-driven creative sandbox. The current Compy
hardware has no touchscreen, so everything — painting, erasing,
dragging stickers — happens with the mouse and a couple of
modifier keys.

Launching `paint` opens a small **preset menu** with two choices
built over the same engine:

* **sticker board** — just the canvas and a tray of stickers.
  The calmest surface, for the youngest children.
* **full interface** — brush, eraser, the 16-color palette,
  line thickness, and the sticker tray.

`Shift+Esc` steps back: from the engine to the preset menu, and
from the menu out to the console.

### Interface design

The screen is a fixed 1024×600 — wide and short, so vertical
space is the scarce resource. All chrome therefore lives in one
column down the left edge, and the canvas keeps the full screen
height. Nothing is ever sized from the screen *width*; the
column is sized from its own width and the screen *height*.

```plain
+--------+--------------------------------------------------+
| brush  |                                                  |
| eraser |                                                  |
| sticker|                                                  |
|--------|                                                  |
| colors |                                                  |
|  or    |                     canvas                       |
| tray   |                                                  |
|--------|                                                  |
| line   |                                                  |
|--------|                                                  |
| clear  |                                                  |
+--------+--------------------------------------------------+
```

The middle band is mode-dependent: with the brush or eraser
selected it shows the palette (8 rows, each base color beside
its brighter variant) and two swatches — the primary color and
the canvas background; with
the sticker tool it shows the tray instead, since color and
thickness do not apply to stickers. In the 'sticker board'
preset the tray takes the whole column.

All of the geometry derives from two numbers:

```lua
WIDTH, HEIGHT = gfx.getDimensions()
COL_W = WIDTH * 0.2
```

### The object model

The picture's source of truth is not pixels — it is an ordered
**list of objects** (`objects.lua`). A stroke is a polyline plus
color and thickness; a sticker is an id plus position and scale.
Each object carries a bounding box.

```lua
stroke = {
  kind = "stroke",
  color = c,
  weight = w,
  points = { x, y },
  ...
}
```

This split between the model and the rendering is the
load-bearing idea of the program: because the list *is* the
drawing, we can erase one object, undo, or (someday) save —
none of which a flat bitmap allows.

### Drawing

Compy runs project code — including every event handler —
inside `use_canvas`, targeting a persistent virtual canvas that
keeps its contents between frames. Paint leans on that
("pen-and-paper" drawing): a brush stroke is stamped onto the
canvas once, at the moment the mouse moves, and stays there.
Nothing is redrawn per frame.

On entering a preset — inside a mouse handler, where the
live canvas is the active target — we grab its handle:

```lua
PICTURE = gfx.getCanvas()
```

and keep a deliberately tiny `love.draw`: composite the
picture, draw the chrome over it, then the live pointer
overlay — a thin circle showing the current brush size. Its
cost does not depend on how much the child has drawn.

A stroke is a chain of filled circles. Mouse events arrive
sparsely when the hand moves fast, so each new point is
connected to the previous one by interpolated stamps — the same
`stampSpan` walk is used live and during replay, so a replayed
stroke is pixel-identical to the original.

### Erasing

The eraser removes **whole objects**: touch a stroke and the
stroke disappears, touch a sticker and the sticker goes. On
press (or drag) the engine finds the topmost object under the
cursor — a cheap bounding-box test first, then a fine test:
point-to-polyline distance for strokes, the box itself for
stickers — removes it from the list, and **replays** the
remaining objects onto the canvas:

```lua
function replay()
  gfx.clear()
  for i = 1, #objects do
    drawObject(objects[i])
  end
end
```

The replay happens only when the list changes (erase, undo,
clear) — never per frame. For the object counts this activity
reaches, that is the whole performance story.

### Stickers

Eight stickers — circle, square, star, tree, house, sun,
flower, cloud — live in a manifest (`stickers.lua`); each entry
carries an `id`, a footprint `size` (96 px), and a `draw`
function that renders it with graphics primitives. Swapping in
artist-made images later means carrying an `image` instead of
`draw`, with no change to the model or the tool.

Press and hold a tray preview to pick a sticker up; while held
it follows the pointer at full size; release over the canvas to
place it (one object in the list); release anywhere else to
cancel silently. Placed stickers are not moved or resized — to
remove one, erase it.

### Undo and clear

`Ctrl+Z` undoes one step (depth 1). The model records the last
reversible action in a single stash and replays its inverse:

```lua
undone = { act = "erase", at = i, obj = o }
```

* **add** (a stroke or sticker) — drop the last object
* **erase** — reinsert the removed object at its old index, so
  undoing an erase brings *that* object back, not some other
* **clear** — restore the whole list (saved by reference, since
  Lua does not copy tables on assignment, so it costs nothing)

Any new action overwrites the stash, so a second undo in a row
does nothing. The garbage collector reclaims whatever the stash
no longer references.

### Input

Everything is driven by raw mouse events. A press is routed by
region — palette, canvas, tool strip, thickness, tray — through
small dispatch tables, so exactly one thing happens per click.

There is no double-click anywhere: the platform's double-click
detection must wait out a delay window before confirming a
single click, which makes every tap feel late. Paint acts on
`love.mousepressed` directly, so the response lands within a
frame. The `Alt` modifier controls the canvas background
instead: `Alt`+click a swatch repaints the background in that
color. There is no secondary drawing color — the brush always
paints the primary. The background lives outside the object
list, so erasing reveals it and undo/clear do not touch it.

A real right-button click reaches the program as a raw `Esc`
key; `paint` binds neither, so both are silently dropped.

Keyboard conveniences:

* `Tab` — next tool
* `[` / `]` — thinner / thicker line
* `1`–`8` — base colors; `Shift+1`–`8` — brighter variants
* `Ctrl+Z` — undo (one step)
* `Shift+Esc` — back to the preset menu / exit
* `Ctrl+Alt+Down` / `Ctrl+Alt+Up` — teacher chords for the
  seed-sticker notch: down pre-places a tree, a house, and a
  sun so a blank page is less intimidating; up returns to
  blank starts

Anything not listed is ignored.

### Files

* `main.lua` — the engine: screens, layout, input dispatch,
  rendering
* `constants.lua` — configuration and derived layout, pure data
* `objects.lua` — the object model, no drawing
* `stickers.lua` — the sticker manifest and placeholder art
