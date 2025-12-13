import AppKit

// Explicit entry point - this file ensures AppDelegate is always invoked
// (bypasses any Xcode caching issues with @main attribute).

autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}

