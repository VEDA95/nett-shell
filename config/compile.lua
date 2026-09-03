-- Compile config.lua into the artefacts the shell and Hyprland consume.
--
--   lua config/compile.lua            write everything
--   lua config/compile.lua --print    print the merged JSON, write nothing
--   lua config/compile.lua --check    validate only, write nothing
--   lua config/compile.lua --binds    write only the Hyprland file
--
-- This is a standalone entrypoint rather than logic inside QML for one concrete
-- reason: Hyprland reads nett-shell.conf at login, before `qs` has started. The
-- shell's file watcher, nettctl, and an exec-once all invoke this same file, so
-- there is exactly one implementation of "compile the config".
--
-- EXIT CODES  (the shell distinguishes these)
--   0  success
--   2  syntax error in config.lua
--   3  runtime error while evaluating config.lua
--   4  validation failure
--   5  I/O failure
--
-- On any failure the previous config.json is left untouched, so a typo mid-edit
-- degrades to "the shell keeps the last good config" rather than "the shell goes
-- blank". That property is the whole reason for the temp-file-and-rename dance
-- below: a partial write would be worse than no write.

local E_OK, E_SYNTAX, E_RUNTIME, E_VALIDATION, E_IO = 0, 2, 3, 4, 5

-- ---------------------------------------------------------------------------
-- Locate ourselves, so `require` works from any working directory
-- ---------------------------------------------------------------------------
local script = arg[0] or "config/compile.lua"
local config_dir = script:match("^(.*)[/\\][^/\\]*$") or "."
local shell_dir = config_dir:match("^(.*)[/\\][^/\\]*$") or "."

package.path = table.concat({
  config_dir .. "/lib/?.lua",
  config_dir .. "/?.lua",
  package.path,
}, ";")

local json = require("json")
local merge = require("merge")
local hyprbinds = require("hyprbinds")
local hyprgen = require("hyprgen")

-- ---------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------
local HOME = os.getenv("HOME") or "."

local function expand(path)
  return (path:gsub("^~", HOME))
end

-- Deliberately our own state directory rather than Quickshell's statePath():
-- this script runs before `qs` exists, so it cannot ask Quickshell for a shell
-- id. XDG_STATE_HOME is computable identically from Lua and from QML, which is
-- what makes the two sides agree. It is also outside the shell directory, so
-- writing here can never trip the QML file watcher into a reload loop.
local STATE_DIR = expand((os.getenv("XDG_STATE_HOME") or "~/.local/state") .. "/nett-shell")
local CONFIG_JSON = STATE_DIR .. "/config.json"
local CONFIG_ERR = STATE_DIR .. "/config.err"
local HYPR_CONF = expand("~/.config/hypr/nett-shell.conf")
local HYPR_ENTRY = expand("~/.config/hypr/hyprland.conf")

local USER_CONFIG = config_dir .. "/config.lua"
local DEFAULTS = config_dir .. "/defaults.lua"
local KEYBINDS = config_dir .. "/keybinds.lua"

-- ---------------------------------------------------------------------------
-- Flags
-- ---------------------------------------------------------------------------
local flags = {}
for i = 1, #arg do flags[arg[i]] = true end
local only_print = flags["--print"] or false
local only_check = flags["--check"] or false
local only_binds = flags["--binds"] or false
local quiet = flags["--quiet"] or false

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------
local messages = {}

local function note(kind, text)
  messages[#messages + 1] = { kind = kind, text = text }
end

local function warn(path, message)
  note("warn", ("%s: %s"):format(path, message))
end

-- Errors go to stderr so the shell's StdioCollector picks them up verbatim, and
-- to config.err so a shell starting fresh can still show what went wrong.
local function fail(code, text)
  io.stderr:write(text, "\n")
  if not (only_print or only_check) then
    os.execute(("mkdir -p %q"):format(STATE_DIR))
    local fh = io.open(CONFIG_ERR, "w")
    if fh then
      fh:write(text, "\n")
      fh:close()
    end
  end
  os.exit(code)
end

-- ---------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------
local function read_file(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local content = fh:read("a")
  fh:close()
  return content
end

--- Load a Lua table from a file in a restricted environment.
---
--- `load(..., "t", env)` is text-only, so a config file cannot smuggle in
--- precompiled bytecode, and `env` withholds os.execute / io / package. This is a
--- config file, not a plugin: it should describe values, not run programs.
local function load_table(path, chunkname, sandbox)
  local src = read_file(path)
  if not src then return nil, nil end

  local env
  if sandbox then
    env = {
      -- Enough to compute values, nothing that touches the outside world.
      math = math, string = string, table = table,
      tonumber = tonumber, tostring = tostring, type = type,
      ipairs = ipairs, pairs = pairs, next = next, select = select,
      pcall = pcall, error = error, assert = assert,
      os = { getenv = os.getenv, date = os.date, time = os.time },
      -- So config.lua can disambiguate empty containers, same as defaults.lua.
      json = { arr = json.arr, obj = json.obj, map = json.map },
      arr = json.arr, obj = json.obj, map = json.map,
      HOME = HOME,
    }
    env._G = env
  else
    env = _ENV
  end

  local chunk, syntax_err = load(src, "=" .. chunkname, "t", env)
  if not chunk then
    return nil, { code = E_SYNTAX, message = syntax_err }
  end

  local ok, result = pcall(chunk)
  if not ok then
    return nil, { code = E_RUNTIME, message = tostring(result) }
  end

  return result, nil
end

-- Defaults are ours, so they load unsandboxed and may `require`.
local defaults, derr = load_table(DEFAULTS, "defaults", false)
if derr then
  fail(derr.code, ("defaults.lua: %s"):format(derr.message))
end
if type(defaults) ~= "table" then
  fail(E_VALIDATION, "defaults.lua must return a table")
end

-- The user's config is sandboxed.
local user, uerr = load_table(USER_CONFIG, "config", true)
if uerr then
  fail(uerr.code, uerr.message)
end
if user == nil then
  note("info", "config.lua not found, using defaults")
end

local cfg, warnings = merge.apply(defaults, user)
for _, w in ipairs(warnings) do
  warn(w.path, w.message)
end

-- ---------------------------------------------------------------------------
-- Validation -- catch what a type check cannot
-- ---------------------------------------------------------------------------
local function validate(c)
  local problems = {}

  local function check(cond, msg)
    if not cond then problems[#problems + 1] = msg end
  end

  check(c.bar.height > 0, "bar.height must be positive")
  check(c.frame.inset >= 0, "frame.inset cannot be negative")
  check(c.frame.radius >= 0, "frame.radius cannot be negative")
  check(c.theme.opacity > 0 and c.theme.opacity <= 1, "theme.opacity must be in (0, 1]")
  check(c.osd.maxVolume >= 1, "osd.maxVolume must be at least 1")
  check(c.workspaces.persistent >= 0, "workspaces.persistent cannot be negative")

  local positions = { top = true, bottom = true }
  check(positions[c.bar.position], ("bar.position must be top or bottom, got %q")
    :format(tostring(c.bar.position)))

  local modes = { shared = true, ["per-monitor"] = true }
  check(modes[c.wallpaper.mode], ("wallpaper.mode must be shared or per-monitor, got %q")
    :format(tostring(c.wallpaper.mode)))

  -- The multiples-of-4 rule: warn rather than fail, because it is a rendering
  -- nicety, not a correctness issue -- but a shimmering 1px border is genuinely
  -- hard to diagnose later, so it is worth saying out loud. This stays safe
  -- whether the compositor's real 1.25 scale ends up governing the render
  -- (4 x 1.25 = 5, whole) or Qt's own devicePixelRatio does, which has been
  -- observed as 2 on this system due to a known Qt/Wayland limitation with
  -- fractional scale factors between 100% and 200% (4 x 2 = 8, also whole).
  for _, item in ipairs({
    { "frame.inset", c.frame.inset }, { "frame.radius", c.frame.radius },
    { "bar.height", c.bar.height }, { "bar.gap", c.bar.gap },
    { "popups.gap", c.popups.gap },
  }) do
    local name, value = item[1], item[2]
    if value % 4 ~= 0 then
      warn(name, ("%d is not a multiple of 4; at this system's scale that can "
        .. "land on a fractional physical pixel and render soft"):format(value))
    end
  end

  return problems
end

local ok_validate, problems = pcall(validate, cfg)
if not ok_validate then
  fail(E_VALIDATION, ("validation crashed: %s"):format(tostring(problems)))
end
if #problems > 0 then
  fail(E_VALIDATION, "invalid configuration:\n  - " .. table.concat(problems, "\n  - "))
end

-- ---------------------------------------------------------------------------
-- Keybinds -- loaded and resolved before encoding, so config.json can carry a
-- `keybinds` array alongside the Hyprland file. Shortcuts.qml instantiates one
-- GlobalShortcut per entry here, using the exact same `name` hyprgen.lua wrote
-- into the generated bind's `global, appid:name` dispatch -- one derivation,
-- read from two places, so the two can never name a shortcut differently.
-- ---------------------------------------------------------------------------
local binds = load_table(KEYBINDS, "keybinds", true) or {}
if type(binds) ~= "table" then
  fail(E_VALIDATION, "keybinds.lua must return a list")
end

-- Skip our own generated file when scanning, or every regeneration would see the
-- keys it wrote last time and report all of them as conflicts.
local taken, scan_problems = hyprbinds.collect(HYPR_ENTRY, { [HYPR_CONF] = true })
for _, p in ipairs(scan_problems) do
  note("warn", "hyprland scan: " .. p)
end

local hypr_content, conflicts, emitted = hyprgen.render(cfg, binds, taken)

for _, c in ipairs(conflicts) do
  note("conflict", ("%s -- %s (keybind not installed)"):format(c.key, c.reason))
end

-- `exec` entries (e.g. lock) dispatch straight from Hyprland and never touch
-- the shell, so they get no GlobalShortcut and are left out of this list.
local keybinds_out = {}
for _, e in ipairs(emitted) do
  if not e.isExec then
    keybinds_out[#keybinds_out + 1] = {
      name = e.name,
      action = e.action,
      arg = e.arg,
      repeatable = e.repeatable,
      locked = e.locked,
      desc = e.desc,
    }
  end
end
cfg.keybinds = json.arr(keybinds_out)

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------
local encoded = json.encode(cfg, { indent = "  ", warn = warn })

if only_print then
  print(encoded)
  os.exit(E_OK)
end

if only_check then
  for _, m in ipairs(messages) do
    io.stderr:write(("[%s] %s\n"):format(m.kind, m.text))
  end
  print(("config OK -- %d keybinds to install, %d conflicts")
    :format(#emitted, #conflicts))
  os.exit(E_OK)
end

-- ---------------------------------------------------------------------------
-- Write
-- ---------------------------------------------------------------------------
if os.execute(("mkdir -p %q"):format(STATE_DIR)) == nil then
  fail(E_IO, ("could not create %s"):format(STATE_DIR))
end

--- Write atomically: a partial file is worse than a stale one, because FileView
--- would happily parse the truncated half.
local function write_atomic(path, content)
  local tmp = path .. ".tmp"
  local fh, err = io.open(tmp, "w")
  if not fh then return false, err end
  local ok_w, werr = fh:write(content)
  fh:close()
  if not ok_w then
    os.remove(tmp)
    return false, werr
  end
  local ok_r, rerr = os.rename(tmp, path)
  if not ok_r then
    os.remove(tmp)
    return false, rerr
  end
  return true
end

--- Only rewrite when the content actually differs. This is what makes
--- `hyprctl reload` rare: reloading re-applies monitors and can flash or reset
--- scaling, so doing it on every config save would jolt the displays constantly.
--- Returns true when the file changed.
local function write_if_changed(path, content)
  if read_file(path) == content then return false end
  local ok_w, err = write_atomic(path, content)
  if not ok_w then
    fail(E_IO, ("could not write %s: %s"):format(path, tostring(err)))
  end
  return true
end

local hypr_changed = write_if_changed(HYPR_CONF, hypr_content)

if not only_binds then
  local ok_w, err = write_atomic(CONFIG_JSON, encoded .. "\n")
  if not ok_w then
    fail(E_IO, ("could not write %s: %s"):format(CONFIG_JSON, tostring(err)))
  end
  -- Clear the error file on success, so the shell's toast goes away.
  write_atomic(CONFIG_ERR, "")
end

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
if not quiet then
  for _, m in ipairs(messages) do
    io.stderr:write(("[%s] %s\n"):format(m.kind, m.text))
  end
end

-- The shell reads this line to decide whether to run `hyprctl reload`.
if hypr_changed then
  print("HYPR_CHANGED")
end

os.exit(E_OK)
