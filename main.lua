-- main.lua

-- Paint: engine + interface presets over it (spec).
-- Configuration in constants.lua, picture model in
-- objects.lua, sticker art in stickers.lua.

require("constants")
require("objects")
require("stickers")

-- the star sticker doubles as the sticker-tool icon

STAR_ID = STICKER_INDEX["star"]

-- pen-and-paper (spec #18): all event handlers run inside
-- the framework's use_canvas, so the picture lives on the
-- persistent virtual canvas. The handle is captured inside
-- a handler (enterPreset), where the platform guarantees
-- the live canvas is the active target. This capture and
-- the blit in drawEngine are the only platform-behavior
-- dependencies

PICTURE = nil

-- relative mode: the system pointer is off, the position
-- lives in mx, my and is clamped off the screen edges; the
-- program draws its own large, high-contrast arrow (spec)

love.mouse.setRelativeMode(true)
mx = WIDTH / 2
my = HEIGHT / 2

function clampScale(s)
  return math.max(SCALE_MIN, math.min(SCALE_MAX, s))
end

function clampAxis(v, dim)
  return math.max(EDGE_PAD, math.min(dim - EDGE_PAD - 1, v))
end

-- screen state: the preset menu or the engine

screen = "menu"
preset = nil

-- tray geometry: depends on the active preset

tray_y = 0
tray_row = 0
preview_d = 0

-- selected state. bg is the canvas background color --
-- Alt+click on a swatch repaints it (replaces the old
-- secondary-color path); held is the tray sticker
-- dragged; notch is the teacher difficulty step (spec)

color = Color.black
bg = Color.black
weight = DEFAULT_WEIGHT
tool = BRUSH
erasing = false
held = nil
held_scale = 1
notch = 0

-- range tests: column regions use x < COL_W, canvas the rest

function inCanvasRange(x, _)
  return COL_W < x
end

function inToolRange(x, y)
  return x < COL_W and y < TOOLS_H
end

function inPaletteRange(x, y)
  return x < COL_W and CTRL_Y <= y and y < SEL_Y
end

function inWeightRange(x, y)
  return x < COL_W and WB_Y <= y and y < ACTION_Y
end

function inUndoRange(x, y)
  return x < COL_W / 2 and ACTION_Y <= y
end

function inClearRange(x, y)
  return COL_W / 2 <= x and x < COL_W and ACTION_Y <= y
end

function inTrayRange(x, y)
  return x < COL_W and tray_y <= y
end

-- chrome

function drawBackground()
  gfx.setColor(Color[bg])
  gfx.rectangle("fill", 0, 0, WIDTH, HEIGHT)
end

function drawColumn()
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", 0, 0, COL_W, HEIGHT)
end

-- tool icons

function beginIcon(cx, cy, s)
  gfx.push()
  gfx.translate(cx, cy)
  gfx.scale(s, s)
  gfx.rotate(ICON_ANGLE)
end

-- flame tip of the brush icon, rendered once at load

BRUSH_TIP = love.math.newBezierCurve(
  -12,
  12,
  -15,
  20,
  -5,
  30,
  0,
  35,
  5,
  30,
  15,
  20,
  12,
  12
):render()

function drawBrushHandle()
  gfx.setColor(0.6, 0.4, 0.2)
  gfx.rectangle("fill", -8, -80, 16, 60)
  gfx.setColor(0.8, 0.6, 0.4)
  gfx.rectangle("fill", -6, -75, 3, 50)
end

function drawBrushFerrule()
  gfx.setColor(0.7, 0.7, 0.8)
  gfx.rectangle("fill", -10, -25, 20, 12)
  gfx.setColor(0.9, 0.9, 1)
  gfx.rectangle("fill", -8, -24, 3, 10)
end

function drawBrushBristles()
  gfx.setColor(0.2, 0.2, 0.2)
  gfx.rectangle("fill", -12, -13, 24, 25)
  gfx.polygon("fill", BRUSH_TIP)
end

function drawBrush(cx, cy)
  beginIcon(cx, cy, (ICON_D / ICON_BASE) * 0.8)
  drawBrushHandle()
  drawBrushFerrule()
  drawBrushBristles()
  gfx.pop()
end

function drawEraserBody()
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", -12, -40, 24, 60)
  gfx.setColor(Color[Color.blue])
  gfx.rectangle("fill", -12, -40, 6, 60)
  gfx.rectangle("fill", 6, -40, 6, 60)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle("fill", -12, 15, 24, 8)
end

function drawEraser(cx, cy)
  beginIcon(cx, cy, ICON_D / ICON_BASE)
  drawEraserBody()
  gfx.pop()
end

function drawSticker(i, cx, cy, d)
  gfx.push()
  gfx.translate(cx, cy)
  STICKERS[i].draw(d)
  gfx.pop()
end

function drawStickerTool(cx, cy)
  drawSticker(STAR_ID, cx - ART_DX, cy - ART_DY, ICON_D * 0.8)
end

TOOLS = {
  drawBrush,
  drawEraser,
  drawStickerTool
}

function toolIconColor(i)
  if i == tool then
    return Color.black
  end
  return BRIGHT_WHITE
end

function drawToolIcon(i)
  local cx = (i - 1) * SLOT_W + SLOT_W / 2
  local cy = TOOLS_H / 2
  local x = cx - ICON_D / 2
  local y = cy - ICON_D / 2
  gfx.setColor(Color[toolIconColor(i)])
  gfx.rectangle("fill", x, y, ICON_D, ICON_D)
  gfx.setColor(Color[Color.black])
  gfx.rectangle("line", x, y, ICON_D, ICON_D)
  TOOLS[i](cx + ART_DX, cy + ART_DY)
end

function drawTools()
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle("line", 0, 0, COL_W, TOOLS_H)
  for i = 1, #(preset.tools) do
    drawToolIcon(preset.tools[i])
  end
end

-- palette

function drawSwatch(c, x, y)
  gfx.setColor(Color[c])
  gfx.rectangle("fill", x, y, SWATCH_W, ROW_H)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("line", x, y, SWATCH_W, ROW_H)
end

function drawPaletteGrid()
  for row = 0, PAL_COLS - 1 do
    local y = CTRL_Y + row * ROW_H
    drawSwatch(row, 0, y)
    drawSwatch(row + PAL_COLS, SWATCH_W, y)
  end
end

function outlineFor(c)
  local lc = BRIGHT_WHITE
  if c == lc then
    return Color.black
  end
  return lc
end

function drawSelected(c, x)
  local sx = x + MARGIN
  local sy = SEL_Y + MARGIN
  local w = SWATCH_W - M_2
  local h = SEL_H - M_2
  gfx.setColor(Color[c])
  gfx.rectangle("fill", sx, sy, w, h)
  gfx.setColor(Color[outlineFor(c)])
  gfx.rectangle("line", sx, sy, w, h)
end

function drawSelectedSwatches()
  drawSelected(color, 0)
  drawSelected(bg, SWATCH_W)
end

function drawControlArea()
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle("line", 0, CTRL_Y, COL_W, CTRL_H)
  drawPaletteGrid()
  drawSelectedSwatches()
end

function drawTrayEntry(i)
  local y = tray_y + ((i - 1) * tray_row)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle(
    "line",
    MARGIN,
    y + MARGIN,
    COL_W - M_2,
    tray_row - M_2
  )
  drawSticker(i, COL_W / 2, y + (tray_row / 2), preview_d)
end

function drawTray()
  for i = 1, #STICKERS do
    drawTrayEntry(i)
  end
end

function drawActionFrame(x, w)
  local y = ACTION_Y + MARGIN
  local h = ACTION_H - M_2
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle("fill", x, y, w, h)
  gfx.setColor(Color[Color.black])
  gfx.rectangle("line", x, y, w, h)
end

function drawUndoIcon(cx, cy, d)
  local r = d * 0.32
  local s = d * 0.2
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(3)
  gfx.arc("line", "open", cx, cy, r, -math.pi, 0.9)
  gfx.setLineWidth(1)
  local ax = cx - r
  gfx.polygon("fill", ax - s, cy, ax + s, cy, ax, cy + s)
end

function drawTrashIcon(cx, cy, d)
  gfx.push()
  gfx.translate(cx, cy)
  gfx.setColor(Color[Color.black])
  gfx.rectangle("line", -d * 0.25, -d * 0.2, d * 0.5, d * 0.55)
  gfx.rectangle("fill", -d * 0.32, -d * 0.3, d * 0.64, d * 0.08)
  gfx.rectangle("fill", -d * 0.1, -d * 0.38, d * 0.2, d * 0.08)
  gfx.pop()
end

function drawActionRow()
  local w = (COL_W - (3 * MARGIN)) / 2
  local cy = ACTION_Y + (ACTION_H / 2)
  local x2 = (2 * MARGIN) + w
  drawActionFrame(MARGIN, w)
  drawUndoIcon(MARGIN + (w / 2), cy, ACTION_H * 0.8)
  drawActionFrame(x2, w)
  drawTrashIcon(x2 + (w / 2), cy, ACTION_H * 0.8)
end

function drawPaintControls()
  drawControlArea()
  drawWeightSelector()
  drawActionRow()
end

MODE_CONTROLS = {
  drawPaintControls,
  drawPaintControls,
  drawTray
}

-- goose marker for the selected weight, drawn around y = 0

GOOSE_SHAPE = {
  2 * MARGIN, -MARGIN / 2,
  2 * MARGIN, MARGIN / 2,
  7 * MARGIN, MARGIN / 2,
  7 * MARGIN, MARGIN,
  9 * MARGIN, 0,
  7 * MARGIN, -MARGIN,
  7 * MARGIN, -MARGIN / 2
}

-- line weight selector

CURSOR_PTS = { }

function cursorPoint(x, y)
  CURSOR_PTS[#CURSOR_PTS + 1] = x
  CURSOR_PTS[#CURSOR_PTS + 1] = y
end

cursorPoint(0, 0)
cursorPoint(0, 36)
cursorPoint(8, 28)
cursorPoint(14, 41)
cursorPoint(20, 38)
cursorPoint(14, 25)
cursorPoint(25, 25)

CURSOR_TRIS = love.math.triangulate(CURSOR_PTS)

GOOSE_TRIS = love.math.triangulate(GOOSE_SHAPE)

function drawGooseMarker(mid)
  gfx.push()
  gfx.translate(0, mid)
  gfx.setColor(GOOSE)
  for i = 1, #GOOSE_TRIS do
    gfx.polygon("fill", GOOSE_TRIS[i])
  end
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(2)
  gfx.polygon("line", GOOSE_SHAPE)
  gfx.setLineWidth(1)
  gfx.pop()
end

function drawWeightBar(mid, lw)
  gfx.setColor(Color[Color.black])
  local aw = WEIGHTS[lw]
  gfx.rectangle("fill", COL_W / 3, mid - (aw / 2),
    COL_W / 2, aw)
end

function drawWeightRow(i, h)
  local y = WB_Y + MARGIN + (i * h)
  local lw = i + 1
  local mid = y + (h / 2)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle("fill", MARGIN, y, COL_W - M_2, h)
  if lw == weight then
    drawGooseMarker(mid)
  end
  drawWeightBar(mid, lw)
end

function drawWeightSelector()
  local h = (WEIGHT_H - M_2) / #WEIGHTS
  for i = 0, #WEIGHTS - 1 do
    drawWeightRow(i, h)
  end
end

function getWeight()
  local aw = WEIGHTS[weight]
  if tool == ERASER then
    aw = aw * ERASER_SCALE
  end
  return aw
end

-- a small center dot marks the exact action point under
-- any tool cursor

-- cursor outlines are drawn twice -- a thick light pass
-- under a thin dark pass -- so the pointer stays visible
-- on any background or drawing

function strokeRing(r)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.setLineWidth(3)
  gfx.circle("line", mx, my, r)
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(1)
  gfx.circle("line", mx, my, r)
end

function strokeBox(r)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.setLineWidth(3)
  gfx.rectangle("line", mx - r, my - r, r * 2, r * 2)
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(1)
  gfx.rectangle("line", mx - r, my - r, r * 2, r * 2)
end

function drawHotspot()
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.circle("fill", mx, my, 2)
  gfx.setColor(Color[Color.black])
  gfx.circle("fill", mx, my, 1)
end

-- brush cursor: a ring the size of the stroke (PS brush)

function brushCursor()
  if inCanvasRange(mx, my) then
    strokeRing(getWeight())
    drawHotspot()
  end
end

-- eraser cursor: a square frame the size of the erase zone

function eraserCursor()
  if inCanvasRange(mx, my) then
    strokeBox(getWeight())
    drawHotspot()
  end
end

function crossArm(x1, y1, x2, y2)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.setLineWidth(3)
  gfx.line(x1, y1, x2, y2)
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(1)
  gfx.line(x1, y1, x2, y2)
end

function drawCrosshair()
  local d = CROSS_D
  crossArm(mx - d, my, mx + d, my)
  crossArm(mx, my - d, mx, my + d)
end

-- sticker cursor: held preview, else a crosshair marking
-- where the sticker would land

function stickerCursor()
  if held then
    drawSticker(held, mx, my, STICKER_SIZE * held_scale)
  elseif inCanvasRange(mx, my) then
    drawCrosshair()
  end
end

POINTER = {
  brushCursor,
  eraserCursor,
  stickerCursor
}

function drawCursor()
  gfx.push()
  gfx.translate(mx, my)
  gfx.setColor(Color[BRIGHT_WHITE])
  for i = 1, #CURSOR_TRIS do
    gfx.polygon("fill", CURSOR_TRIS[i])
  end
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(2)
  gfx.polygon("line", CURSOR_PTS)
  gfx.setLineWidth(1)
  gfx.pop()
end

-- the only per-frame work: composite the persistent
-- picture (cost independent of the object count, spec),
-- draw the chrome over any stamp bleed, then the live
-- pointer overlay. gfx.draw tints by the current color,
-- so the blit needs the identity tint (1, 1, 1) -- black
-- from drawBackground would render the picture invisible

function drawEngine()
  drawBackground()
  gfx.setColor(1, 1, 1)
  gfx.draw(PICTURE)
  drawColumn()
  if hasStrip() then
    drawTools()
  end
  MODE_CONTROLS[tool]()
  POINTER[tool]()
end

-- preset menu (the landing screen, spec)

function boardIcon(cx, cy, d)
  drawSticker(STAR_ID, cx, cy, d)
end

function fullIcon(cx, cy, d)
  local s = d / ICON_D
  gfx.push()
  gfx.translate(cx, cy)
  gfx.scale(s, s)
  drawBrush(0, 0)
  gfx.pop()
end

PRESET_ICONS = {
  boardIcon,
  fullIcon
}

function menuButtonY(i)
  return MENU_Y + ((i - 1) * (MENU_H + MENU_GAP))
end

function drawMenuButton(i)
  local y = menuButtonY(i)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", MENU_X, y, MENU_W, MENU_H)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle("line", MENU_X, y, MENU_W, MENU_H)
  local cy = y + (MENU_H / 2)
  PRESET_ICONS[i](MENU_X + (MENU_H / 2), cy, MENU_ICON)
  gfx.setColor(Color[Color.black])
  local fh = gfx.getFont():getHeight()
  gfx.print(PRESETS[i].id, MENU_X + MENU_H, cy - (fh / 2))
end

function drawMenu()
  drawBackground()
  for i = 1, #PRESETS do
    drawMenuButton(i)
  end
end

SCREEN_DRAW = {
  menu = drawMenu,
  engine = drawEngine
}

function love.draw()
  SCREEN_DRAW[screen]()
  if not (screen == "engine" and inCanvasRange(mx, my)) then
    drawCursor()
  end
end

-- click handlers

function gridIndex(v, origin, cell)
  return math.modf((v - origin) / cell) + 1
end

function setColor(x, y, alt)
  local row = gridIndex(y, CTRL_Y, ROW_H) - 1
  local col = gridIndex(x, 0, SWATCH_W) - 1
  local c = row + (col * PAL_COLS)
  if alt then
    bg = c
  else
    color = c
  end
end

function setTool(x, _)
  local sel = gridIndex(x, 0, SLOT_W)
  if sel <= #(preset.tools) then
    tool = preset.tools[sel]
  end
end

function setLineWeight(_, y)
  local h = WEIGHT_H / #WEIGHTS
  weight = gridIndex(y, WB_Y, h)
end

function stamp(cx, cy, aw)
  gfx.circle("fill", cx, cy, aw)
end

-- stamps along the segment ending at point index i, so the
-- live stroke and the replay produce identical pixels

function stampSpan(o, i)
  local pts = o.points
  local ex = pts[i] - pts[i - 2]
  local ey = pts[i + 1] - pts[i - 1]
  local len = math.sqrt(ex * ex + ey * ey)
  local n = math.ceil(len / (o.weight * STEP_FRAC))
  for k = 1, n do
    local t = k / n
    stamp(pts[i - 2] + ex * t, pts[i - 1] + ey * t, o.weight)
  end
end

function brushPress(x, y)
  beginStroke(x, y, color, getWeight())
  gfx.setColor(Color[stroke.color])
  stamp(x, y, stroke.weight)
end

function eraseAt(x, y)
  local i = topmostAt(x, y, getWeight())
  if i then
    removeObject(i)
    replay()
  end
end

function erasePress(x, y)
  erasing = true
  eraseAt(x, y)
end

TOOL_PRESS = {
  brushPress,
  erasePress
}

function canvasPress(x, y, alt)
  TOOL_PRESS[tool](x, y, alt)
end

function extendStroke(x, y)
  strokePoint(x, y)
  gfx.setColor(Color[stroke.color])
  stampSpan(stroke, #(stroke.points) - 1)
end

-- rendering an object from the model

function drawObjectStroke(o)
  local pts = o.points
  gfx.setColor(Color[o.color])
  stamp(pts[1], pts[2], o.weight)
  for i = 3, #pts - 1, 2 do
    stampSpan(o, i)
  end
end

function drawObjectSticker(o)
  drawSticker(o.id, o.x, o.y, STICKER_SIZE * o.scale)
end

DRAW_OBJECT = {
  stroke = drawObjectStroke,
  sticker = drawObjectSticker
}

function drawObject(o)
  DRAW_OBJECT[o.kind](o)
end

-- rebuilds the picture from the object list; called only
-- when the list changes (erase/undo), never per frame (spec)

function replay()
  gfx.clear()
  for i = 1, #objects do
    drawObject(objects[i])
  end
end

function pickSticker(_, y)
  held = gridIndex(y, tray_y, tray_row)
  held_scale = 1
end

function love.wheelmoved(_, dy)
  if held then
    held_scale = clampScale(held_scale + (dy * SCALE_STEP))
  end
end

function placeSticker(i, x, y, scale)
  local half = (STICKER_SIZE * scale) / 2
  addSticker(i, x, y, half, scale)
  drawObjectSticker(objects[#objects])
end

function dropSticker(x, y)
  if inCanvasRange(x, y) then
    placeSticker(held, x, y, held_scale)
  end
  held = nil
end

-- notch -1 seeds the canvas with three stickers so a child
-- staring at a blank page has somewhere to start (spec)

function applySeeds()
  for i = 1, #SEEDS do
    local s = SEEDS[i]
    placeSticker(STICKER_INDEX[s.id], s.x + COL_W, s.y, 1)
  end
end

function notchDown()
  if notch == 0 then
    notch = -1
    applySeeds()
  end
end

function notchUp()
  if notch == -1 then
    notch = 0
  end
end

-- clear is a visible action because it is undoable: the
-- model keeps the cleared array by reference (no copy)

function doClear()
  clearPicture()
  replay()
end

function doUndo()
  undo()
  replay()
end

function clearPress()
  doClear()
end

function undoPress()
  doUndo()
end

-- input dispatch: all actions on raw mouse events (spec)
-- Alt+left picks the background; right button never arrives
-- (the platform delivers it as a raw Esc, which is unbound)

-- click regions: each list is a sequence of test/action
-- pairs, all built the same way through addRegion

function addRegion(list, test, action)
  list[#list + 1] = {
    test,
    action
  }
end

PAINT_REGIONS = { }
addRegion(PAINT_REGIONS, inPaletteRange, setColor)
addRegion(PAINT_REGIONS, inCanvasRange, canvasPress)
addRegion(PAINT_REGIONS, inToolRange, setTool)
addRegion(PAINT_REGIONS, inWeightRange, setLineWeight)
addRegion(PAINT_REGIONS, inUndoRange, undoPress)
addRegion(PAINT_REGIONS, inClearRange, clearPress)

STICKER_REGIONS = { }
addRegion(STICKER_REGIONS, inToolRange, setTool)
addRegion(STICKER_REGIONS, inTrayRange, pickSticker)

-- a single-tool preset has no tool strip: the only active
-- region left of the canvas is the tray; clicking the empty
-- canvas with the sticker tool does nothing (spec)

BOARD_REGIONS = { }
addRegion(BOARD_REGIONS, inTrayRange, pickSticker)

MODE_REGIONS = {
  PAINT_REGIONS,
  PAINT_REGIONS,
  STICKER_REGIONS
}

function dispatch(regions, x, y, alt)
  for i = 1, #regions do
    local r = regions[i]
    if r[1](x, y) then
      r[2](x, y, alt)
    end
  end
end

function hasStrip()
  return 1 < #(preset.tools)
end

function regionsFor()
  if hasStrip() then
    return MODE_REGIONS[tool]
  end
  return BOARD_REGIONS
end

function enginePress(x, y, alt)
  dispatch(regionsFor(), x, y, alt)
end

-- entering a preset starts a fresh picture: re-picking from
-- the menu is the documented relaunch-style clear (spec)

function setTrayArea()
  tray_y = 0
  if hasStrip() then
    tray_y = TOOLS_H
  end
  tray_row = (HEIGHT - tray_y) / #STICKERS
  preview_d = tray_row - M_2
end

function enterPreset(i)
  PICTURE = gfx.getCanvas()
  bg = Color.black
  preset = PRESETS[i]
  tool = preset.tools[1]
  setTrayArea()
  clearObjects()
  replay()
  if notch == -1 then
    applySeeds()
  end
  screen = "engine"
end

function enterMenu()
  if stroke then
    commitStroke()
  end
  held = nil
  erasing = false
  screen = "menu"
end

function inMenuButton(i, x, y)
  local by = menuButtonY(i)
  return MENU_X <= x and x <= MENU_X + MENU_W
       and by <= y
       and y <= by + MENU_H
end

function menuPress(x, y)
  for i = 1, #PRESETS do
    if inMenuButton(i, x, y) then
      enterPreset(i)
    end
  end
end

SCREEN_PRESS = {
  menu = menuPress,
  engine = enginePress
}

function love.mousepressed()
  SCREEN_PRESS[screen](mx, my, Key.alt())
end

function love.mousemoved(_, _, dx, dy)
  mx = clampAxis(mx + (dx * POINTER_SPEED), WIDTH)
  my = clampAxis(my + (dy * POINTER_SPEED), HEIGHT)
  if not inCanvasRange(mx, my) then
    return 
  end
  if stroke then
    extendStroke(mx, my)
  elseif erasing then
    eraseAt(mx, my)
  end
end

function love.mousereleased()
  if stroke then
    commitStroke()
  end
  if held then
    dropSticker(mx, my)
  end
  erasing = false
end

-- keyboard

function cycleTool()
  local n = #(preset.tools)
  for i = 1, n do
    if preset.tools[i] == tool then
      tool = preset.tools[(i % n) + 1]
      return 
    end
  end
end

function weightDown()
  if 1 < weight then
    weight = weight - 1
  end
end

function weightUp()
  if weight < #WEIGHTS then
    weight = weight + 1
  end
end

KEYS = {
  tab = cycleTool,
  ["["] = weightDown,
  ["]"] = weightUp
}

function setColorKey(k)
  local c = COLORKEYS[k]
  if c then
    if Key.shift() then
      c = c + PAL_COLS
    end
    color = c
  end
end

-- Shift+Esc steps back: engine -> preset menu -> console.
-- raw Esc (the platform's right-click) is dropped (spec)

function exitToConsole()
  gfx.clear()
  love.mouse.setRelativeMode(false)
  stop()
end

function escapePressed()
  if Key.ctrl() then
    love.mouse.setRelativeMode(false)
    return 
  end
  if not Key.shift() then
    return 
  end
  if screen == "engine" then
    enterMenu()
  else
    exitToConsole()
  end
end

-- teacher chords: Ctrl+Alt+Down seeds, Ctrl+Alt+Up steps
-- back up; plain arrows stay ignored (spec)

CHORDS = {
  down = notchDown,
  up = notchUp
}

function chordKey(k)
  local chord = CHORDS[k]
  if chord and Key.ctrl() and Key.alt() then
    chord()
  end
end

CTRL_KEYS = { z = doUndo }

function ctrlKey(k)
  local action = CTRL_KEYS[k]
  if action and Key.ctrl() then
    action()
  end
end

function engineKey(k)
  local action = KEYS[k]
  if action then
    action()
  end
  ctrlKey(k)
  chordKey(k)
  setColorKey(k)
end

function love.keypressed(k)
  if k == "escape" then
    escapePressed()
    return 
  end
  if screen == "engine" then
    engineKey(k)
  end
end
