import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Claude mark that stays in the bar while any Claude Code session waits for
// input. Driven by Claude Code hooks via bin/claude-ping:
//   omarchy-shell ms007.omarchy-claude-shell waiting <session> <project> <window>
//   omarchy-shell ms007.omarchy-claude-shell done <session>
// A reply always pulses the icon. If the session's terminal window has focus
// at that moment the reply counts as seen and the icon hides afterwards;
// otherwise the session stays unseen (icon stays) until you focus its window.
BarWidget {
  id: root
  moduleName: "ms007.omarchy-claude-shell"

  // unseen sessions: session id -> { project, window }
  property var sessions: ({})
  // Hyprland address of the focused window, without the 0x prefix
  property string activeWindow: ""
  // true while the pulse plays after a new waiting event, so it is shown
  // even if the reply was seen right away
  property bool flashing: false
  property string lastProject: ""

  readonly property var projects: {
    var out = []
    for (var k in sessions) out.push(sessions[k].project)
    return out
  }

  visible: projects.length > 0 || flashing
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function peers() {
    return bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root]
  }

  function setWaiting(session, project, window) {
    var addr = String(window || "").replace(/^0x/, "")
    var next = Object.assign({}, sessions)
    if (addr !== "" && addr === activeWindow) delete next[session]
    else next[session] = { project: project, window: addr }
    sessions = next
    lastProject = project
    pulse.restart()
    flashing = true
  }

  function setDone(session) {
    if (!(session in sessions)) return
    var next = Object.assign({}, sessions)
    delete next[session]
    sessions = next
  }

  function clearAll() { sessions = ({}) }

  // Focusing a session's window marks its replies as seen.
  onActiveWindowChanged: {
    if (activeWindow === "") return
    var next = Object.assign({}, sessions)
    var changed = false
    for (var k in next) {
      if (next[k].window === activeWindow) { delete next[k]; changed = true }
    }
    if (changed) sessions = next
  }

  IpcHandler {
    target: "ms007.omarchy-claude-shell"

    function waiting(session: string, project: string, window: string): void {
      var items = root.peers()
      for (var i = 0; i < items.length; i++) items[i].setWaiting(session, project, window)
    }

    function done(session: string): void {
      var items = root.peers()
      for (var i = 0; i < items.length; i++) items[i].setDone(session)
    }

    function clear(): void {
      var items = root.peers()
      for (var i = 0; i < items.length; i++) items[i].clearAll()
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activewindowv2") root.activeWindow = String(event.data).replace(/^0x/, "")
    }
  }

  Process {
    id: activeProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.activeWindow = String(JSON.parse(text).address || "").replace(/^0x/, "") } catch (e) {}
      }
    }
  }

  Component.onCompleted: activeProc.running = true

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Claude waiting: " + (root.projects.length > 0 ? root.projects.join(", ") : root.lastProject)
    iconComponent: Image {
      source: Qt.resolvedUrl("assets/claude.svg")
      sourceSize: Qt.size(width * 2, height * 2)
      fillMode: Image.PreserveAspectFit
      anchors.fill: parent
      anchors.margins: 1
      smooth: true
    }
    onPressed: root.peers().forEach(function(w) { w.clearAll() })
  }

  SequentialAnimation {
    id: pulse
    loops: 3
    onRunningChanged: if (!running) { root.flashing = false; button.opacity = 1 }
    NumberAnimation { target: button; property: "opacity"; to: 0.25; duration: 350; easing.type: Easing.InOutQuad }
    NumberAnimation { target: button; property: "opacity"; to: 1; duration: 350; easing.type: Easing.InOutQuad }
  }
}
