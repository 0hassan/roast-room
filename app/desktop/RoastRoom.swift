// Roast Room as a Mac app: starts the server, shows the room in its own window,
// and stops the server when the window closes. Built by build.sh (npm run desktop).
import Cocoa
import WebKit

let root = Bundle.main.object(forInfoDictionaryKey: "RoastRoomRoot") as! String
let room = URL(string: "http://localhost:4730")!

class App: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
  let server = Process()
  var window: NSWindow!
  var web: WKWebView!
  var tries = 0

  func applicationDidFinishLaunching(_ n: Notification) {
    // A login shell, so node and claude are on PATH the same way they are in Terminal.
    server.executableURL = URL(fileURLWithPath: "/bin/zsh")
    server.arguments = ["-lc", "exec node app/server.mjs"]
    server.currentDirectoryURL = URL(fileURLWithPath: root)
    try? server.run()

    web = WKWebView(frame: .zero)
    web.navigationDelegate = self
    web.uiDelegate = self
    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Roast Room"
    window.contentView = web
    window.center()
    window.setFrameAutosaveName("RoastRoom")
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    web.load(URLRequest(url: room))
  }

  // The server takes a moment to start listening: retry for about 15 seconds.
  func webView(_ w: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
    tries += 1
    if tries > 30 {
      w.loadHTMLString("<body style='font:15px -apple-system;background:#07121c;color:#fff;padding:40px'>The room didn't start. In Terminal, run <code>cd \(root) && npm start</code> to see why.</body>", baseURL: nil)
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { w.load(URLRequest(url: room)) }
  }

  // "Download PDF": ask where to save it.
  func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    decisionHandler(a.shouldPerformDownload ? .download : .allow)
  }
  func webView(_ w: WKWebView, navigationAction: WKNavigationAction, didBecome d: WKDownload) { d.delegate = self }
  func download(_ d: WKDownload, decideDestinationUsing r: URLResponse, suggestedFilename name: String, completionHandler: @escaping (URL?) -> Void) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = name
    panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.url : nil) }
  }

  // Links that open a new tab go to the default browser.
  func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? {
    if let u = a.request.url { NSWorkspace.shared.open(u) }
    return nil
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
  func applicationWillTerminate(_ n: Notification) {
    if server.isRunning { server.terminate(); server.waitUntilExit() }
  }
}

// Menus, so Cmd+Q, copy, paste, and undo work.
func menu(_ title: String, _ items: [(String, Selector, String)]) -> NSMenuItem {
  let m = NSMenu(title: title)
  for (t, a, k) in items { m.addItem(withTitle: t, action: a, keyEquivalent: k) }
  let item = NSMenuItem()
  item.submenu = m
  return item
}
let bar = NSMenu()
bar.addItem(menu("Roast Room", [("Quit Roast Room", #selector(NSApplication.terminate(_:)), "q")]))
bar.addItem(menu("Edit", [
  ("Undo", Selector(("undo:")), "z"), ("Redo", Selector(("redo:")), "Z"),
  ("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"),
  ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a"),
]))
bar.addItem(menu("Window", [("Close", #selector(NSWindow.performClose(_:)), "w"), ("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")]))

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.mainMenu = bar
app.setActivationPolicy(.regular)
app.run()
