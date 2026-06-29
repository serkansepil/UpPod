import AppKit

#if DEBUG
setvbuf(stdout, nil, _IOLBF, 0)   // line-buffered: debug logs flush to file immediately too
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    var engine: PostureEngine!
    var statusBar: StatusBarController!
    var exerciseEngine: ExerciseEngine!
    var exerciseWindow: ExerciseWindowController!
    var updater: AppUpdater!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let useMock = RuntimeFlags.enabled("UPPOD_MOCK")
        let service: MotionProviding = useMock ? MockMotionService() : HeadphoneMotionService()
        let forcePersist = RuntimeFlags.enabled("UPPOD_PERSIST")
        let store: SessionStore = (useMock && !forcePersist) ? MemoryStore() : JSONFileStore()
        engine = PostureEngine(service: service, store: store)
        exerciseEngine = ExerciseEngine(posture: engine)
        exerciseWindow = ExerciseWindowController(engine: exerciseEngine)
        updater = AppUpdater()
        statusBar = StatusBarController(engine: engine,
                                        onStartExercise: { [weak self] in self?.exerciseWindow.present() },
                                        onCheckForUpdates: { [weak self] in self?.updater.checkForUpdates() })
        engine.start()

        if RuntimeFlags.enabled("UPPOD_EX_AUTOSTART") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.exerciseEngine.start(ExerciseLibrary.testPlan)   // headless test
                if RuntimeFlags.enabled("UPPOD_EX_AUTOPRESENT") {
                    self?.exerciseWindow.present()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        exerciseEngine?.stop()
        engine?.persistNow()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // Dockless menu bar app (LSUIElement)
app.run()
