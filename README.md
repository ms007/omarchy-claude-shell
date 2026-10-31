# Claude ping

An Omarchy bar widget that shows the Claude mark in the bar while a Claude
Code session waits for input. Use it instead of a system notification.

## Behavior

- When a session waits (permission prompt, question, finished reply), the
  icon pulses briefly.
- If the session's terminal window has focus at that moment, the reply
  counts as seen: the icon hides after the pulse and does not come back.
- Otherwise the reply is unseen and the icon stays until you focus that
  session's window. After that it does not come back either.
- A session is also done once you submit a message, an approved tool has
  run, or the session ends.
- Clicking the icon dismisses all waiting sessions.
- The tooltip lists the projects (directory names) of the unseen sessions.

| State | Event | Effect | Next state |
|---|---|---|---|
| quiet | reply, session window focused | pulse, then hide | quiet |
| quiet | reply, other window focused | pulse, icon stays | unseen |
| unseen | session window focused | icon hides | quiet |
| unseen | another reply, other window focused | pulse again | unseen |
| unseen | another reply, session window focused | pulse, then hide | quiet |
| any | prompt submitted, tool ran, session ended, icon clicked | icon hides | quiet |

`bin/claude-ping` finds a session's window by walking up the process tree.
Several sessions in tabs of the same terminal window therefore count as one window,
and focusing it marks all of them as seen. If the script cannot find the
window, the session stays unseen until you answer or click the icon. This
applies to sessions inside tmux, because the tmux server is detached from
the terminal that started it.

## Installation

```bash
omarchy plugin add <repo-url> --enable
```

Or by hand: clone or symlink the repo to
`~/.config/omarchy/plugins/ms007.omarchy-claude-shell/`, then

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable ms007.omarchy-claude-shell
```

Requires `jq` and `hyprctl`.

### Claude Code setup

Add these hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [{ "type": "command", "command": "~/.config/omarchy/plugins/ms007.omarchy-claude-shell/bin/claude-ping waiting" }]
      }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.config/omarchy/plugins/ms007.omarchy-claude-shell/bin/claude-ping waiting" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/.config/omarchy/plugins/ms007.omarchy-claude-shell/bin/claude-ping done" }] }
    ],
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "~/.config/omarchy/plugins/ms007.omarchy-claude-shell/bin/claude-ping done" }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "~/.config/omarchy/plugins/ms007.omarchy-claude-shell/bin/claude-ping done" }] }
    ]
  }
}
```

Without the `Stop` entry the icon only appears for permission prompts and
questions, not after every finished reply. `idle_prompt` is left out on
purpose: it fires about a minute after a reply you may already have seen.

To avoid a second system notification, turn off "Local notification"
in Claude Code's `/config` (`"preferredNotifChannel": "notifications_disabled"`).

Claude Code loads new hooks only when a session starts.

## IPC

```bash
omarchy-shell ms007.omarchy-claude-shell waiting <session> <project> <window-address>
omarchy-shell ms007.omarchy-claude-shell done <session>
omarchy-shell ms007.omarchy-claude-shell clear
```

## Development

The shell reloads changes under `~/.config/omarchy/plugins/` automatically.
It does not see changes if the plugin is a symlink to a folder elsewhere, so
run `omarchy restart shell` after editing. Run it as well after changing the
signature of an IPC function, because the old instance keeps holding the IPC
target.

## Note

`assets/claude.svg` is Anthropic's Claude logo, taken from Omarchy's
`omarchy.agents` plugin. No free license covers it.
