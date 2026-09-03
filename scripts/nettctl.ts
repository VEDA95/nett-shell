// nettctl -- small operational CLI for nett-shell.
//
// Compiled to a standalone binary (see the build command in the header of
// scripts/build.sh, or just `bun build --compile scripts/nettctl.ts --outfile
// scripts/nettctl`) rather than run through a `bun` shebang: this is a real
// CLI with a stable argv surface, and a compiled binary starts faster and
// doesn't depend on `bun` still being the interpreter on PATH later.
//
// Deliberately thin: `compile` and `binds` just shell out to
// `lua config/compile.lua`, so there is exactly one implementation of "compile
// the config" -- this file never re-parses or re-emits anything Lua already
// owns. What actually belongs in bun rather than Lua or QML is the stuff that
// genuinely needs it: dependency checks, filesystem bootstrap, and (in later
// waves) thumbnail generation -- see scripts/wallpapers.ts once that lands.
//
// Subcommands:
//   nettctl compile        recompile config.lua -> config.json (+ hypr file)
//   nettctl binds          recompile, writing only the Hyprland file
//   nettctl print-config   print the merged config as JSON, write nothing
//   nettctl doctor         report on dependencies, install state, config health
//   nettctl install        idempotently source nett-shell.conf from
//                          hyprland.conf (NOT run automatically by anything
//                          here -- this edits a file outside the shell
//                          directory, so it is a deliberate, explicit step)

import { existsSync, lstatSync, readlinkSync, readFileSync, appendFileSync, copyFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";
import { spawnSync } from "node:child_process";

// `import.meta.url` resolves inside Bun's virtual bundled filesystem
// (`/$bunfs/...`) once this is `bun build --compile`'d into a standalone
// binary, NOT the real on-disk location -- confirmed by running the compiled
// binary and watching it try to open `/$bunfs/config/compile.lua`.
// `process.execPath` is the actual filesystem path of the running executable
// regardless of bundling, so resolve from there instead. realpathSync follows
// the symlink a PATH entry would normally be, so invoking `nettctl` from
// anywhere still finds the real scripts/ directory.
const SHELL_DIR = dirname(dirname(realpathSync(process.execPath)));
const HOME = homedir();

function xdg(envVar: string, fallback: string): string {
  const v = process.env[envVar];
  return v && v.length > 0 ? v : join(HOME, fallback);
}

const STATE_DIR = join(xdg("XDG_STATE_HOME", ".local/state"), "nett-shell");
const CONFIG_HOME = xdg("XDG_CONFIG_HOME", ".config");
const HYPR_DIR = join(CONFIG_HOME, "hypr");
const HYPR_ENTRY = join(HYPR_DIR, "hyprland.conf");
const HYPR_GENERATED = join(HYPR_DIR, "nett-shell.conf");
const QMLLS_INI = join(SHELL_DIR, ".qmlls.ini");

interface RunResult {
  ok: boolean;
  status: number | null;
  stdout: string;
  stderr: string;
}

function run(cmd: string, args: string[]): RunResult {
  const r = spawnSync(cmd, args, { encoding: "utf-8" });
  return {
    ok: r.status === 0,
    status: r.status,
    stdout: (r.stdout ?? "").trim(),
    stderr: (r.stderr ?? "").trim(),
  };
}

function compileLua(extraArgs: string[]): RunResult {
  return run("lua", [join(SHELL_DIR, "config/compile.lua"), ...extraArgs]);
}

// ---------------------------------------------------------------------------
// compile / binds / print-config -- thin passthroughs to compile.lua
// ---------------------------------------------------------------------------

function cmdCompile(): never {
  const r = compileLua([]);
  if (r.stderr) process.stderr.write(r.stderr + "\n");
  if (r.stdout) process.stdout.write(r.stdout + "\n");
  process.exit(r.status ?? 1);
}

function cmdBinds(): never {
  const r = compileLua(["--binds"]);
  if (r.stderr) process.stderr.write(r.stderr + "\n");
  if (r.stdout) process.stdout.write(r.stdout + "\n");
  process.exit(r.status ?? 1);
}

function cmdPrintConfig(): never {
  const r = compileLua(["--print"]);
  if (r.stderr) process.stderr.write(r.stderr + "\n");
  process.stdout.write(r.stdout + "\n");
  process.exit(r.status ?? 1);
}

// ---------------------------------------------------------------------------
// doctor -- read-only diagnostic report. Never mutates anything.
// ---------------------------------------------------------------------------

function reportLine(label: string, status: string, detail: string = ""): void {
  const pad = label.padEnd(22, " ");
  console.log(`  ${pad} ${status}${detail ? "  " + detail : ""}`);
}

function cmdDoctor(): never {
  console.log("nett-shell doctor\n");

  console.log("Runtime:");
  const qs = run("qs", ["--version"]);
  if (qs.ok) {
    const isUpstream = /^quickshell\b/i.test(qs.stdout) && !/noctalia/i.test(qs.stdout);
    reportLine("quickshell", isUpstream ? "OK" : "WARN",
      qs.stdout + (isUpstream ? "" : "  (expected upstream 'quickshell', not a fork)"));
  } else {
    reportLine("quickshell", "MISSING", "`qs` not found on PATH");
  }

  const lua = run("lua", ["-v"]);
  reportLine("lua", lua.ok ? "OK" : "MISSING", lua.ok ? lua.stdout.split("\n")[0] : "");

  console.log("\nFonts:");
  const fc = run("fc-list", []);
  const hasMaterialSymbols = fc.ok && /material symbols/i.test(fc.stdout);
  reportLine("Material Symbols", hasMaterialSymbols ? "OK" : "MISSING",
    hasMaterialSymbols ? "" : "install ttf-material-symbols-variable (icons render as literal fallback text without it)");
  const hasNerdFont = fc.ok && /nerd font/i.test(fc.stdout);
  reportLine("Nerd Font", hasNerdFont ? "OK" : "MISSING", "");

  console.log("\nQML tooling:");
  if (!existsSync(QMLLS_INI)) {
    reportLine(".qmlls.ini", "MISSING", "run `touch .qmlls.ini` then start qs once to let it self-populate");
  } else {
    try {
      const st = lstatSync(QMLLS_INI);
      if (st.isSymbolicLink()) {
        const target = readlinkSync(QMLLS_INI);
        const alive = existsSync(QMLLS_INI);
        reportLine(".qmlls.ini", alive ? "OK" : "DANGLING",
          alive ? `-> ${target}` : `-> ${target} (target gone; delete and touch a fresh empty file)`);
      } else {
        reportLine(".qmlls.ini", "OK", "(plain file, not yet a symlink -- start qs once)");
      }
    } catch {
      reportLine(".qmlls.ini", "MISSING", "");
    }
  }

  console.log("\nConfig:");
  const check = compileLua(["--check"]);
  reportLine("compile.lua --check", check.ok ? "OK" : "FAIL", check.stdout || check.stderr);

  console.log("\nHyprland integration:");
  reportLine("nett-shell.conf", existsSync(HYPR_GENERATED) ? "generated" : "not yet generated", HYPR_GENERATED);
  let sourced = false;
  if (existsSync(HYPR_ENTRY)) {
    const entry = readFileSync(HYPR_ENTRY, "utf-8");
    sourced = entry.split("\n").some(line => line.replace(/#.*$/, "").includes("nett-shell.conf"));
  }
  reportLine("sourced from hyprland.conf", sourced ? "YES" : "NO",
    sourced ? "" : "run `nettctl install` to wire it up (edits hyprland.conf, asks first)");

  console.log("\nState:");
  reportLine("state dir", existsSync(STATE_DIR) ? "OK" : "MISSING", STATE_DIR);

  const allGood = qs.ok && lua.ok && check.ok;
  process.exit(allGood ? 0 : 1);
}

// ---------------------------------------------------------------------------
// install -- idempotently source nett-shell.conf from hyprland.conf.
//
// Never invoked automatically by anything in this repo. Editing the user's
// live Hyprland config is exactly the kind of action that deserves an explicit
// "yes, do it" rather than happening as a side effect of running the shell.
// ---------------------------------------------------------------------------

function cmdInstall(): void {
  if (!existsSync(HYPR_ENTRY)) {
    console.error(`hyprland.conf not found at ${HYPR_ENTRY}`);
    process.exit(1);
  }

  const entry = readFileSync(HYPR_ENTRY, "utf-8");
  const already = entry.split("\n").some(line => line.replace(/#.*$/, "").includes("nett-shell.conf"));
  if (already) {
    console.log("already sourced -- nothing to do");
    return;
  }

  const backup = HYPR_ENTRY + ".bak-nettctl";
  copyFileSync(HYPR_ENTRY, backup);
  appendFileSync(HYPR_ENTRY, `\nsource = ${HYPR_GENERATED}\n`);
  console.log(`appended:  source = ${HYPR_GENERATED}`);
  console.log(`backup at: ${backup}`);
  console.log("run `hyprctl reload` to pick it up");
}

// ---------------------------------------------------------------------------

const [, , cmd, ...rest] = process.argv;
void rest;

switch (cmd) {
  case "compile": cmdCompile(); break;
  case "binds": cmdBinds(); break;
  case "print-config": cmdPrintConfig(); break;
  case "doctor": cmdDoctor(); break;
  case "install": cmdInstall(); break;
  default:
    console.log("usage: nettctl <compile|binds|print-config|doctor|install>");
    process.exit(cmd ? 1 : 0);
}
