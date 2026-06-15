-- objects.lua

-- Object model: the ordered list of objects is the picture's
-- source of truth; pixels are derived from it (spec). This
-- module is pure data — no drawing happens here.

objects = { }

-- the stroke currently being drawn

stroke = nil

-- the last reversible action, kept for one-step undo (spec):
-- { act = "add" } | { act = "erase", at, obj } |
-- { act = "clear", list }

undone = nil

function beginStroke(x, y, c, w)
  stroke = {
    kind = "stroke",
    color = c,
    weight = w,
    pad = w,
    points = { }
  }
  stroke.x1 = x
  stroke.y1 = y
  stroke.x2 = x
  stroke.y2 = y
  strokePoint(x, y)
end

function strokePoint(x, y)
  local pts = stroke.points
  pts[#pts + 1] = x
  pts[#pts + 1] = y
  stroke.x1 = math.min(stroke.x1, x)
  stroke.y1 = math.min(stroke.y1, y)
  stroke.x2 = math.max(stroke.x2, x)
  stroke.y2 = math.max(stroke.y2, y)
end

function markAdd()
  undone = { act = "add" }
end

function commitStroke()
  objects[#objects + 1] = stroke
  stroke = nil
  markAdd()
end

function clearObjects()
  objects = { }
  stroke = nil
  undone = nil
end

-- saves the array by reference: Lua tables are not
-- copied on assignment, and undo swaps it back

function clearPicture()
  undone = {
    act = "clear",
    list = objects
  }
  objects = { }
end

-- undo handlers, one per recorded action (spec: depth 1)

function undoAdd()
  objects[#objects] = nil
end

function undoErase(u)
  table.insert(objects, u.at, u.obj)
end

function undoClear(u)
  objects = u.list
end

UNDO = {
  add = undoAdd,
  erase = undoErase,
  clear = undoClear
}

-- one step back: replay the inverse of the last action,
-- then drop the stash so a second undo does nothing

function undo()
  if undone then
    UNDO[undone.act](undone)
    undone = nil
  end
end

function stickerBox(o, half)
  o.x1 = o.x - half
  o.y1 = o.y - half
  o.x2 = o.x + half
  o.y2 = o.y + half
end

function addSticker(index, x, y, half, scale)
  markAdd()
  local o = {
    kind = "sticker",
    index = index,
    x = x,
    y = y,
    scale = scale,
    pad = 0
  }
  stickerBox(o, half)
  objects[#objects + 1] = o
end

-- hit testing: a coarse bbox test, then a fine test per kind
-- (point-to-polyline for strokes), topmost object first (spec)

function clamp01(t)
  return math.max(0, math.min(1, t))
end

function inBBox(o, x, y, r)
  local pad = o.pad + r
  return o.x1 - pad <= x and x <= o.x2 + pad
       and o.y1 - pad <= y
       and y <= o.y2 + pad
end

-- squared distance from (x, y) to the segment ending at
-- point index i of the polyline

function segDist2(o, i, x, y)
  local pts = o.points
  local ax, ay = pts[i - 2], pts[i - 1]
  local ex = pts[i] - ax
  local ey = pts[i + 1] - ay
  local ll = ex * ex + ey * ey
  local t = 0
  if 0 < ll then
    t = clamp01(((x - ax) * ex + (y - ay) * ey) / ll)
  end
  local dx = x - (ax + ex * t)
  local dy = y - (ay + ey * t)
  return dx * dx + dy * dy
end

function hitDot(o, x, y, p2)
  local dx = x - o.points[1]
  local dy = y - o.points[2]
  return dx * dx + dy * dy <= p2
end

function hitStroke(o, x, y, r)
  local pad = o.weight + r
  local p2 = pad * pad
  local pts = o.points
  if #pts == 2 then
    return hitDot(o, x, y, p2)
  end
  for i = 3, #pts - 1, 2 do
    if segDist2(o, i, x, y) <= p2 then
      return true
    end
  end
  return false
end

-- for stickers the box itself is the fine test (spec)

function hitSticker()
  return true
end

HIT_OBJECT = {
  stroke = hitStroke,
  sticker = hitSticker
}

function hitObject(o, x, y, r)
  if not inBBox(o, x, y, r) then
    return false
  end
  return HIT_OBJECT[o.kind](o, x, y, r)
end

function topmostAt(x, y, r)
  for i = #objects, 1, -1 do
    if hitObject(objects[i], x, y, r) then
      return i
    end
  end
end

function removeObject(i)
  undone = {
    act = "erase",
    at = i,
    obj = objects[i]
  }
  table.remove(objects, i)
end
