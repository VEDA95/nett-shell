-- Minimal JSON encoder for the nett-shell config pipeline.
--
-- Only encoding is needed: Lua writes, QML reads. Deliberately not a general
-- JSON library -- it handles exactly the cases a config table produces, and
-- fails loudly on the ones it cannot represent.
--
-- Two details that a naive encoder gets wrong, both hit in practice:
--
--   * Floats. string.format("%.17g", 0.92) is "0.92000000000000004". We escalate
--     through shorter precisions and take the first that round-trips, so numbers
--     survive the round trip looking like what the user typed.
--
--   * Empty tables. Lua cannot distinguish {} the empty list from {} the empty
--     object, and guessing wrong turns `monitors = {}` into `{}` (which QML reads
--     as an object, not an empty array). So empty tables must be tagged with
--     json.arr{} / json.obj{}; an untagged empty table encodes as an object and
--     emits a warning rather than silently picking one.

local json = {}

local ARRAY, OBJECT = "array", "object"

--- Tag a table as a JSON array. Required for *empty* lists.
function json.arr(t)
  return setmetatable(t or {}, { __jsontype = ARRAY })
end

--- Tag a table as a JSON object. Required for *empty* maps.
function json.obj(t)
  return setmetatable(t or {}, { __jsontype = OBJECT })
end

--- Tag a table as an *open* JSON object: a free-form map whose keys are data
--- rather than schema (theme token overrides, per-monitor wallpaper paths). The
--- merge step accepts arbitrary keys here without reporting them as typos.
function json.map(t)
  return setmetatable(t or {}, { __jsontype = OBJECT, __jsonopen = true })
end

--- Does this table accept arbitrary keys?
function json.isopen(t)
  local mt = getmetatable(t)
  return mt ~= nil and mt.__jsonopen == true
end

--- Explicit tag, if any, else nil.
function json.tagof(t)
  local mt = getmetatable(t)
  return mt and mt.__jsontype or nil
end

--- Is this table an array? Explicit tag wins; otherwise a non-empty table with
--- a [1] is a list. Empty and untagged is ambiguous -- caller decides.
function json.isarray(t)
  local tag = json.tagof(t)
  if tag then return tag == ARRAY end
  return rawget(t, 1) ~= nil
end

local ESCAPES = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function escape_char(c)
  return ESCAPES[c] or string.format("\\u%04x", string.byte(c))
end

local function encode_string(s)
  -- Escape the JSON-mandatory set plus C0 controls and DEL. UTF-8 above 0x7f
  -- passes through untouched, which is valid JSON and keeps glyphs readable.
  return '"' .. s:gsub('[%z\1-\31"\\\127]', escape_char) .. '"'
end

-- Integer check that works on 5.3+ (math.type) and degrades on 5.1/LuaJIT.
local function is_integer(v)
  if math.type then return math.type(v) == "integer" end
  return v == math.floor(v) and math.abs(v) < 2 ^ 53
end

local PRECISIONS = { "%.14g", "%.15g", "%.16g", "%.17g" }

local function encode_number(v, path, warn)
  if v ~= v then                                    -- NaN
    warn(path, "NaN is not representable in JSON, encoded as null")
    return "null"
  end
  if v == math.huge or v == -math.huge then
    warn(path, "infinity is not representable in JSON, encoded as null")
    return "null"
  end
  if is_integer(v) then
    return string.format("%d", v)
  end
  -- Shortest representation that round-trips exactly.
  for _, fmt in ipairs(PRECISIONS) do
    local s = string.format(fmt, v)
    if tonumber(s) == v then return s end
  end
  return string.format("%.17g", v)                  -- unreachable in practice
end

-- Sort keys so output is byte-stable across runs. That matters: the Hyprland
-- config emitter hashes its output to decide whether `hyprctl reload` is needed,
-- and pairs() order would make every compile look like a change.
local function sorted_keys(t, path, warn)
  local keys, n = {}, 0
  for k in pairs(t) do
    local kt = type(k)
    if kt == "string" then
      n = n + 1
      keys[n] = k
    elseif kt == "number" then
      n = n + 1
      keys[n] = k
    else
      warn(path, ("key of type %s cannot be a JSON key, dropped"):format(kt))
    end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

local encode_value

local function encode_array(t, indent, depth, path, warn, seen)
  local n = #t
  if n == 0 then return "[]" end
  local pad, pad_in = "", ""
  local nl, sep = "", ","
  if indent then
    pad = string.rep(indent, depth)
    pad_in = string.rep(indent, depth + 1)
    nl = "\n"
    sep = ",\n"
  end
  local parts = {}
  for i = 1, n do
    parts[i] = pad_in .. encode_value(t[i], indent, depth + 1,
                                      ("%s[%d]"):format(path, i), warn, seen)
  end
  return "[" .. nl .. table.concat(parts, sep) .. nl .. pad .. "]"
end

local function encode_object(t, indent, depth, path, warn, seen)
  local keys = sorted_keys(t, path, warn)
  if #keys == 0 then return "{}" end
  local pad, pad_in = "", ""
  local nl, sep, colon = "", ",", ":"
  if indent then
    pad = string.rep(indent, depth)
    pad_in = string.rep(indent, depth + 1)
    nl = "\n"
    sep = ",\n"
    colon = ": "
  end
  local parts = {}
  for i, k in ipairs(keys) do
    local child = path == "" and tostring(k) or (path .. "." .. tostring(k))
    parts[i] = pad_in .. encode_string(tostring(k)) .. colon ..
               encode_value(t[k], indent, depth + 1, child, warn, seen)
  end
  return "{" .. nl .. table.concat(parts, sep) .. nl .. pad .. "}"
end

encode_value = function(v, indent, depth, path, warn, seen)
  local tv = type(v)
  if v == nil then return "null" end
  if tv == "boolean" then return v and "true" or "false" end
  if tv == "number" then return encode_number(v, path, warn) end
  if tv == "string" then return encode_string(v) end

  if tv == "table" then
    if seen[v] then
      -- A cycle would otherwise recurse until the stack dies.
      error(("circular reference at %s"):format(path == "" and "<root>" or path), 0)
    end
    seen[v] = true

    local tag = json.tagof(v)
    local result
    if tag == ARRAY then
      result = encode_array(v, indent, depth, path, warn, seen)
    elseif tag == OBJECT then
      result = encode_object(v, indent, depth, path, warn, seen)
    elseif rawget(v, 1) ~= nil then
      result = encode_array(v, indent, depth, path, warn, seen)
    elseif next(v) == nil then
      -- Ambiguous: tag it in defaults.lua with json.arr{} or json.obj{}.
      warn(path, "empty untagged table encoded as {}; use json.arr{} if a list was meant")
      result = "{}"
    else
      result = encode_object(v, indent, depth, path, warn, seen)
    end

    seen[v] = nil
    return result
  end

  -- functions, userdata, threads
  warn(path, ("value of type %s is not representable in JSON, encoded as null"):format(tv))
  return "null"
end

--- Encode a Lua value as JSON.
--- @param value any
--- @param opts table|nil  { indent = "  " | false, warn = function(path, msg) }
--- @return string
function json.encode(value, opts)
  opts = opts or {}
  local indent = opts.indent
  if indent == nil then indent = "  " end
  if indent == false then indent = nil end
  local warn = opts.warn or function() end
  return encode_value(value, indent, 0, "", warn, {})
end

return json
