//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// NOTE: ShellScreen.devicePixelRatio reports 2 instead of Hyprland's real 1.25
// on this system. Tried QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough (scoped via
// DefaultEnv) expecting Qt might be rounding away a correctly-detected 1.25 --
// confirmed no effect, so the value is never received as 1.25 in the first
// place (a protocol-level gap in Qt's Wayland QPA plugin for this surface type,
// not a rounding decision it makes). Not fixable from shell code. Hyprland
// still positions/sizes the surface using its own real 1.25, so this is a
// render-oversampling cost only, not a correctness issue -- do not re-attempt
// this specific fix.

import QtQuick
import Quickshell
import qs.config
import qs.ipc
import qs.framework
import qs.modules.frame
import qs.modules.bar

// -----------------------------------------------------------------------------
// WAVE 1: rounded screen frame + top bar + workspaces. The Wave 0 debug
// checkpoint (config/IPC/popup-framework harness) has been replaced by real
// content -- the popup framework itself is unchanged and will be exercised for
// real again once Wave 2 wires actual bar-anchored popups (control centre,
// notifications, etc). See the plan at
// ~/.claude/plans/i-m-looking-to-make-whimsical-dongarra.md.
// -----------------------------------------------------------------------------

ShellRoot {
    id: root
    settings.watchFiles: true

    ConfigWatcher {
        id: configWatcher
        onCompileFinished: (ok, hyprChanged) => {
            console.log(ok
                ? `nett-shell: config compiled ok${hyprChanged ? " (hypr binds changed)" : ""}`
                : `nett-shell: config compile FAILED: ${ConfigError.summary}`);
        }
    }

    // IPC surface + keybinds -- once-only, never inside the per-screen
    // Variants below (duplicate IpcHandler/GlobalShortcut instances collide).
    Handlers {}
    Shortcuts {}

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Frame {
                required property var modelData
                screen: modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {
                required property var modelData
                screen: modelData
                visible: Config.barOnMonitor(modelData.name)
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            DismissOverlay {
                required property var modelData
                screen: modelData
            }
        }
    }
}
