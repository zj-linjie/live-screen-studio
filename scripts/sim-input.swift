// Posts synthetic mouse input for smoke tests.
//   swift scripts/sim-input.swift where
//   swift scripts/sim-input.swift click [button=2]
//   swift scripts/sim-input.swift hold-scroll <notches> [button=2]   (positive = wheel away from you)
//   swift scripts/sim-input.swift move <x> <y> [seconds=0]           (global coordinates, top-left origin)
//   swift scripts/sim-input.swift ctrl-click                          (⌃+left click, the trackpad trigger)
//   swift scripts/sim-input.swift ctrl-scroll <notches>               (hold ⌃ + scroll, positive = zoom in)
//   swift scripts/sim-input.swift draw [shift=0|1]                    (left-drag a stroke at the cursor)
//   swift scripts/sim-input.swift esc                                 (press Esc)
import CoreGraphics
import Foundation

let args = CommandLine.arguments.dropFirst().map { $0 }
let source = CGEventSource(stateID: .hidSystemState)
var location: CGPoint { CGEvent(source: nil)?.location ?? .zero }

func post(_ type: CGEventType, button: Int) {
    let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location,
                        mouseButton: CGMouseButton(rawValue: UInt32(button))!)!
    event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
    event.post(tap: .cghidEventTap)
}

func postControl(_ down: Bool) {
    CGEvent(keyboardEventSource: source, virtualKey: 59, keyDown: down)!.post(tap: .cghidEventTap)
}

switch args.first {
case "where":
    print(location)
case "click":
    let button = args.count > 1 ? Int(args[1])! : 2
    post(.otherMouseDown, button: button)
    usleep(60_000)
    post(.otherMouseUp, button: button)
case "hold-scroll":
    let notches = Int(args[1])!
    let button = args.count > 2 ? Int(args[2])! : 2
    post(.otherMouseDown, button: button)
    usleep(60_000)
    for _ in 0..<abs(notches) {
        CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1,
                wheel1: Int32(notches > 0 ? 1 : -1), wheel2: 0, wheel3: 0)!.post(tap: .cghidEventTap)
        usleep(50_000)
    }
    post(.otherMouseUp, button: button)
case "move":
    let target = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
    let seconds = args.count > 3 ? Double(args[3])! : 0
    let start = location
    let steps = max(1, Int(seconds * 120))
    for i in 1...steps {
        let t = Double(i) / Double(steps)
        let p = CGPoint(x: start.x + (target.x - start.x) * t, y: start.y + (target.y - start.y) * t)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!
            .post(tap: .cghidEventTap)
        if steps > 1 { usleep(useconds_t(1_000_000 / 120)) }
    }
case "ctrl-click":
    // ⌃+left click: flags must be set explicitly, synthesized clicks do not inherit modifier state.
    for (type, button) in [(CGEventType.leftMouseDown, CGMouseButton.left), (.leftMouseUp, CGMouseButton.left)] {
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location,
                            mouseButton: button)!
        event.flags = .maskControl
        event.post(tap: .cghidEventTap)
        if type == .leftMouseDown { usleep(60_000) }
    }
case "ctrl-scroll":
    let notches = Int(args[1])!
    postControl(true)
    usleep(50_000)
    for _ in 0..<abs(notches) {
        let scroll = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1,
                             wheel1: Int32(notches > 0 ? 1 : -1), wheel2: 0, wheel3: 0)!
        scroll.flags = .maskControl
        scroll.post(tap: .cghidEventTap)
        usleep(50_000)
    }
    postControl(false)
case "draw":
    // Left-drag a stroke at the cursor; flags are set on every event so ⇧/⌃ variants behave like hardware.
    let flags: CGEventFlags = (args.count > 1 && args[1] == "1") ? .maskShift : []
    func postMouse(_ type: CGEventType, at point: CGPoint) {
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point,
                            mouseButton: .left)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
    let start = location
    postMouse(.leftMouseDown, at: start)
    usleep(40_000)
    for step in 1...8 {
        postMouse(.leftMouseDragged, at: CGPoint(x: start.x + CGFloat(step) * 24, y: start.y + CGFloat(step) * 6))
        usleep(30_000)
    }
    postMouse(.leftMouseUp, at: CGPoint(x: start.x + 192, y: start.y + 48))
case "esc":
    CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true)!.post(tap: .cghidEventTap)
    usleep(30_000)
    CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false)!.post(tap: .cghidEventTap)
default:
    print("usage: where | click [button] | hold-scroll <notches> [button] | move <x> <y> [seconds] | ctrl-click | ctrl-scroll <notches>")
    exit(1)
}
