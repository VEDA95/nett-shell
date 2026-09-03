-- Deep-merge the user's config table over the defaults table.
--
-- This is the first of the two defaulting layers. It guarantees the emitted JSON
-- is always *complete* -- every key the shell reads is present -- so QML property
-- defaults are only a backstop for a missing or truncated file, never the primary
-- mechanism. It also means `nettctl print-config` shows the real effective config.
--
-- Policy decisions worth knowing:
--
--   * Type mismatches keep the default and warn. A config typo like
--     `bar = { height = "40" }` should not propagate a string into an int
--     property and break a binding somewhere unrelated.
--
--   * Lists are replaced wholesale, not merged element-wise. When you write
--     `modules = { left = { "workspaces" } }` you mean *only* workspaces, not
--     workspaces appended to the defaults.
--
--   * Unknown keys are kept and warned about, not dropped. Keeping them makes
--     typos visible in the compiled JSON (and in the warning list) instead of
--     vanishing silently; JsonAdapter ignores what it does not declare anyway.

local json = require("json")

local merge = {}

local function is_arraylike(t)
  return json.isarray(t)
end

-- Shallow copy of a list, preserving the array tag so an empty user list still
-- encodes as [] rather than {}.
local function copy_list(src)
  local out = {}
  for i = 1, #src do out[i] = src[i] end
  return json.arr(out)
end

local function deep_copy(v)
  if type(v) ~= "table" then return v end
  if is_arraylike(v) then
    local out = {}
    for i = 1, #v do out[i] = deep_copy(v[i]) end
    return json.arr(out)
  end
  local out = {}
  for k, val in pairs(v) do out[k] = deep_copy(val) end
  if json.isopen(v) then return json.map(out) end
  return json.tagof(v) == "object" and json.obj(out) or out
end

local function join(path, key)
  if path == "" then return tostring(key) end
  return path .. "." .. tostring(key)
end

local function walk(default, user, path, warn)
  if user == nil then return deep_copy(default) end

  local dt, ut = type(default), type(user)

  if dt ~= ut then
    warn(path, ("expected %s but got %s, keeping default"):format(dt, ut))
    return deep_copy(default)
  end

  if dt ~= "table" then
    return user
  end

  -- Lists: the user's value replaces the default entirely.
  if is_arraylike(default) or is_arraylike(user) then
    if is_arraylike(default) and not is_arraylike(user) and next(user) ~= nil then
      warn(path, "expected a list but got a table with named keys, keeping default")
      return deep_copy(default)
    end
    return copy_list(user)
  end

  -- Objects: recurse key by key.
  -- An "open" default is a free-form map (theme.tokens, wallpaper.perMonitor):
  -- its keys are data, so arbitrary user keys are expected, not typos.
  local open = json.isopen(default)

  local out = {}
  for k, v in pairs(default) do
    out[k] = deep_copy(v)
  end
  for k, v in pairs(user) do
    if default[k] ~= nil then
      out[k] = walk(default[k], v, join(path, k), warn)
    else
      if not open then
        warn(join(path, k), "unknown option (kept, but the shell will ignore it)")
      end
      out[k] = deep_copy(v)
    end
  end
  return open and json.map(out) or json.obj(out)
end

--- Merge `user` over `default`.
--- @param default table  the complete default table (defines the schema)
--- @param user table|nil the user's partial table
--- @return table merged, table warnings  -- warnings: { {path=, message=}, ... }
function merge.apply(default, user)
  local warnings = {}
  local function warn(path, message)
    warnings[#warnings + 1] = {
      path = (path == "" and "<root>" or path),
      message = message,
    }
  end

  if user ~= nil and type(user) ~= "table" then
    warn("", ("config must return a table, got %s; using defaults"):format(type(user)))
    return deep_copy(default), warnings
  end

  return walk(default, user, "", warn), warnings
end

return merge
