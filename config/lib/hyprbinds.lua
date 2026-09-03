-- Read the keys Hyprland already has bound, so the generator can refuse to
-- shadow them.
--
-- This exists because of an ordering hazard: nett-shell.conf is sourced after
-- bindings.conf, and in hyprlang a later `bind` for an already-bound key wins
-- silently. Without this check, adding an entry to keybinds.lua that happens to
-- collide would quietly break a working keybind, and the only symptom would be
-- "SUPER+F stopped opening my file manager".
--
-- It is a pragmatic scanner, not an hyprlang parser: it resolves `$variables`,
-- follows `source =` lines, and pulls the mods+key out of every bind* line. That
-- covers everything a normal config does. It deliberately errs toward reporting a
-- conflict when unsure -- a false conflict costs one renamed keybind, a missed one
-- costs a silently broken shortcut.

local hyprbinds = {}

-- Modifier spellings Hyprland accepts, normalised so SUPER and MOD4 compare equal.
local MOD_ALIASES = {
  SUPER = "SUPER", SUPER_L = "SUPER", SUPER_R = "SUPER",
  MOD4 = "SUPER", META = "SUPER", WIN = "SUPER", LOGO = "SUPER",
  ALT = "ALT", ALT_L = "ALT", ALT_R = "ALT", MOD1 = "ALT",
  CTRL = "CTRL", CONTROL = "CTRL", CONTROL_L = "CTRL", CONTROL_R = "CTRL",
  SHIFT = "SHIFT", SHIFT_L = "SHIFT", SHIFT_R = "SHIFT",
  CAPS = "CAPS", CAPSLOCK = "CAPS",
  MOD2 = "MOD2", MOD3 = "MOD3", MOD5 = "MOD5",
}

local function expand_home(path)
  local home = os.getenv("HOME") or ""
  path = path:gsub("^~", home)
  path = path:gsub("^%$HOME", home)
  return path
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Canonical form of a mods+key pair: sorted normalised mods, then the key.
--- "$mainMod SHIFT, S" and "SHIFT SUPER, s" both become "SHIFT+SUPER|S".
function hyprbinds.normalise(mods, key)
  local list = {}
  for token in tostring(mods):gmatch("[^%s]+") do
    local up = token:upper()
    list[#list + 1] = MOD_ALIASES[up] or up
  end
  table.sort(list)

  local k = trim(tostring(key)):gsub("%s+", "")
  -- `code:20` keeps its numeric form; named keys compare case-insensitively.
  if not k:lower():match("^code:") then k = k:upper() end

  return table.concat(list, "+") .. "|" .. k
end

-- Substitute $vars, longest name first so $mainModShift cannot be eaten by
-- a $mainMod substitution.
local function substitute(line, vars)
  local names = {}
  for name in pairs(vars) do names[#names + 1] = name end
  table.sort(names, function(a, b) return #a > #b end)

  local prev
  -- Variables can reference other variables; iterate until stable.
  for _ = 1, 5 do
    prev = line
    for _, name in ipairs(names) do
      line = line:gsub("%$" .. name:gsub("(%W)", "%%%1"), (vars[name]:gsub("%%", "%%%%")))
    end
    if line == prev then break end
  end
  return line
end

-- Split "a, b, c" respecting nothing else -- hyprlang binds are plain
-- comma-separated, and we only ever need the first two fields.
local function first_two_fields(rest)
  local first, second = rest:match("^([^,]*),([^,]*)")
  if not first then return nil end
  return trim(first), trim(second)
end

local function scan(path, vars, found, seen_files, problems)
  path = expand_home(path)
  if seen_files[path] then return end
  seen_files[path] = true

  local fh = io.open(path, "r")
  if not fh then
    problems[#problems + 1] = ("could not read %s"):format(path)
    return
  end

  local sources = {}

  for raw in fh:lines() do
    -- Strip comments, but not a '#' inside a colour literal like rgba(CC0000aa).
    local line = raw:gsub("%s*#.*$", "")
    line = trim(line)
    if line ~= "" then
      local name, value = line:match("^%$([%w_]+)%s*=%s*(.*)$")
      if name then
        vars[name] = trim(value)
      else
        local src = line:match("^source%s*=%s*(.+)$")
        if src then
          sources[#sources + 1] = trim(substitute(src, vars))
        else
          -- bind, bindd, bindel, bindm, bindr, binddel, ...
          local flags, rest = line:match("^bind([%a]*)%s*=%s*(.+)$")
          if rest then
            rest = substitute(rest, vars)
            local mods, key = first_two_fields(rest)
            if mods and key and key ~= "" then
              local id = hyprbinds.normalise(mods, key)
              found[id] = found[id] or {
                key = trim(key), mods = trim(mods), file = path, flags = flags,
              }
            end
          end
        end
      end
    end
  end
  fh:close()

  for _, src in ipairs(sources) do
    scan(src, vars, found, seen_files, problems)
  end
end

--- Collect every key already bound, starting from an Hyprland entry config and
--- following its `source =` chain.
--- @param entry string path to hyprland.conf
--- @param ignore table|nil  set of absolute paths to skip (our own generated file)
--- @return table taken, table problems  -- taken: normalised id -> info
function hyprbinds.collect(entry, ignore)
  local found, problems = {}, {}
  local seen = {}
  for path in pairs(ignore or {}) do
    seen[expand_home(path)] = true
  end
  scan(entry, {}, found, seen, problems)
  return found, problems
end

return hyprbinds
