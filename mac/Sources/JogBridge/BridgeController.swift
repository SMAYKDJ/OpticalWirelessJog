import Foundation
import JogCore
import SwiftUI

/// Estado observável da interface. A lógica de tempo real fica no
/// `JogPipeline`; aqui só há cópias atualizadas a ~30 Hz.
@MainActor
final class BridgeController: ObservableObject {
    // Configuração persistida
    @Published var settings: JogSettings { didSet { settingsChanged() } }
    @Published var rightButtonTogglesDeck: Bool {
        didSet { UserDefaults.standard.set(rightButtonTogglesDeck, forKey: "rightButtonTogglesDeck") }
    }

    // Estado ao vivo
    @Published private(set) var telemetry = JogTelemetry()
    @Published private(set) var midiLog: [JogPipeline.MIDILogEntry] = []
    @Published private(set) var devices: [PointerDeviceInfo] = []
    @Published var selectedDeviceID: String?
    @Published private(set) var mouseState: MouseHIDSource.State = .idle
    @Published private(set) var hasInputMonitoring = MouseHIDSource.hasInputMonitoringAccess
    @Published private(set) var midiStatus = ""
    @Published var jogEnabled = true { didSet { pipeline.setEnabled(jogEnabled) } }

    // Calibração
    @Published private(set) var calibrating = false
    @Published private(set) var calibrationSamples = 0
    @Published private(set) var calibrationCounts: Double = 0
    @Published private(set) var lastCalibration: AxisCalibrator.Result?
    @Published var calibrationRevolutions: Double = 1

    // Telemetria auxiliar
    @Published private(set) var lastWheel = 0
    @Published private(set) var peakRPM: Double = 0

    private let thread = RunLoopThread()
    private let midi: MIDIOutput
    private let pipeline: JogPipeline
    private var mouse: MouseHIDSource!
    private var uiTimer: Timer?

    init() {
        let loaded = Self.loadSettings()
        settings = loaded
        rightButtonTogglesDeck = UserDefaults.standard.bool(forKey: "rightButtonTogglesDeck")
        let midiOut = MIDIOutput()
        midi = midiOut
        pipeline = JogPipeline(settings: loaded, midi: midiOut)
        midiStatus = pipeline.midiStatus

        thread.startAndWait()
        // Motor: ticks a cada 2 ms (paradas, liberação do touch, taxas).
        thread.addTimer(interval: 0.002) { [pipeline] in pipeline.tick(at: Clock.now()) }

        mouse = MouseHIDSource(thread: thread)
        wireMouse()

        AppLog.write("===== JogBridge iniciado · \(midiStatus) · log: \(AppLog.path)")
        logSettings("Ajustes carregados")

        uiTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshUI() }
        }
    }

    // MARK: Ações — mouse

    func requestInputMonitoring() {
        _ = MouseHIDSource.requestInputMonitoringAccess()
        hasInputMonitoring = MouseHIDSource.hasInputMonitoringAccess
        mouse.refresh()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshDevices() {
        hasInputMonitoring = MouseHIDSource.hasInputMonitoringAccess
        mouse.refresh()
    }

    func connectSelectedMouse() {
        guard let id = selectedDeviceID else { return }
        AppLog.write("Conectar: \(devices.first { $0.id == id }?.label ?? id)")
        UserDefaults.standard.set(id, forKey: "lastDevice")
        mouse.connect(id: id)
    }

    func disconnectMouse() {
        mouse.disconnect()
        pipeline.releaseAll()
    }

    // MARK: Ações — calibração óptica

    func startCalibration() {
        pipeline.beginCalibration()
        calibrating = true
        calibrationSamples = 0
        calibrationCounts = 0
        lastCalibration = nil
    }

    func finishCalibration() {
        let r = pipeline.finishCalibration(revolutions: max(0.25, calibrationRevolutions))
        calibrating = false
        lastCalibration = r
        guard let r else {
            AppLog.write("CALIBRAÇÃO falhou: amostras insuficientes")
            return
        }
        AppLog.write(String(format: "CALIBRAÇÃO: %.0f contagens por %.0f volta(s) → %.0f contagens/volta · eixo %.1f° · fora do eixo %.0f%% · retidão %.0f%% · %ld amostras · %@",
                            r.countsPerRevolution * max(0.25, calibrationRevolutions), max(0.25, calibrationRevolutions),
                            r.countsPerRevolution, atan2(r.axisY, r.axisX) * 180 / .pi,
                            r.offAxisRatio * 100, r.straightness * 100, r.sampleCount,
                            r.isReliable ? "CONFIÁVEL" : "SUSPEITA"))
        var s = settings
        s.axisX = r.axisX
        s.axisY = r.axisY
        s.countsPerRevolution = r.countsPerRevolution
        s.invert = false
        settings = s
    }

    func cancelCalibration() {
        pipeline.cancelCalibration()
        calibrating = false
    }

    func adjustCounts(by delta: Double) {
        var s = settings
        s.countsPerRevolution = max(10, round(s.countsPerRevolution + delta))
        settings = s
        AppLog.write("Ajuste manual de contagens: \(s.countsPerRevolution) (delta: \(delta))")
    }

    func setCountsDirectly(_ value: Double) {
        var s = settings
        s.countsPerRevolution = max(10, round(value))
        settings = s
        AppLog.write("Contagens definidas diretamente para: \(s.countsPerRevolution)")
    }

    // MARK: Ações — teste / Traktor Learn

    func resetCounters() {
        AppLog.write(String(format: "ZERAR (antes: voltas %.3f · reversões %ld · pico %.0f RPM)",
                            telemetry.revolutions, telemetry.reversals, peakRPM))
        pipeline.resetCounters()
        peakRPM = 0
    }

    func sendLearnTurn(_ positive: Bool) { pipeline.sendTest(.turn(positive ? 1 : -1)) }
    func sendLearnTouch(_ on: Bool) { pipeline.sendTest(.touch(on)) }

    func setDeck(_ channel: Int) {
        var s = settings
        s.midiChannel = channel
        settings = s
    }

    // MARK: Interno

    private func wireMouse() {
        let pipeline = self.pipeline
        mouse.onCounts = { dx, dy, t in pipeline.counts(dx: dx, dy: dy, at: t) }
        mouse.onButton = { [weak self] button, down, t in
            if button == 1 {
                pipeline.button(down, at: t)
            } else if button == 2, down {
                Task { @MainActor in
                    guard let self, self.rightButtonTogglesDeck else { return }
                    self.setDeck(self.settings.midiChannel == 1 ? 2 : 1)
                }
            }
        }
        mouse.onWheel = { [weak self] v, _ in
            Task { @MainActor in self?.lastWheel = v }
        }
        mouse.onDevicesChanged = { [weak self] in
            Task { @MainActor in self?.reloadDeviceList() }
        }
        mouse.onStateChanged = { [weak self] state in
            Task { @MainActor in
                self?.mouseState = state
                AppLog.write("Estado do mouse: \(state)")
                if case .connected = state {} else { pipeline.releaseAll() }
            }
        }
    }

    private func reloadDeviceList() {
        devices = mouse.deviceList
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            let last = UserDefaults.standard.string(forKey: "lastDevice")
            selectedDeviceID = devices.first(where: { $0.id == last })?.id
                ?? devices.first(where: { $0.isExternal })?.id
                ?? devices.first?.id
        }
        // Conexão automática ao encontrar o dispositivo
        if case .idle = mouseState, selectedDeviceID != nil {
            connectSelectedMouse()
        }
    }

    private func settingsChanged() {
        pipeline.update(settings: settings)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "settings")
        }
    }

    private static func loadSettings() -> JogSettings {
        guard let data = UserDefaults.standard.data(forKey: "settings"),
              let s = try? JSONDecoder().decode(JogSettings.self, from: data) else { return JogSettings() }
        return s
    }

    private var lastLoggedRevs = 0.0
    private var lastLogTime = Date.distantPast
    private var lastLoggedMIDI = 0

    private func logSettings(_ title: String) {
        let s = settings
        AppLog.write(String(format: "%@: contagens/volta %.0f · ticks/volta %.0f · sens %.2f · touch %@ · soltar %.0f ms · canal %ld · CC %ld · nota %ld · %@",
                            title, s.countsPerRevolution, s.ticksPerRevolution, s.sensitivity,
                            s.touchMode.rawValue, s.touchReleaseMs, s.midiChannel, s.turnCC, s.touchNote,
                            s.encoderMode.rawValue))
    }

    private func refreshUI() {
        let (t, log, cal, counts, samples) = pipeline.snapshot()
        // A cada 0,5 s com movimento: uma linha de telemetria no log.
        if Date().timeIntervalSince(lastLogTime) >= 0.5, abs(t.revolutions - lastLoggedRevs) > 0.0005 {
            lastLogTime = Date()
            lastLoggedRevs = t.revolutions
            AppLog.write(String(format: "voltas %+.3f · %+.2f volta/s · dir %+ld · touch %@ · %.0f Hz · MIDI %.0f msg/s · fora do eixo %.0f%% · reversões %ld",
                                t.revolutions, t.revPerSecond, t.direction, t.touching ? "ON" : "off",
                                t.reportRateHz, t.turnMessagesPerSecond, t.offAxisRatio * 100, t.reversals))
        }
        if let last = log.last, last.id != lastLoggedMIDI {
            for e in log where e.id > lastLoggedMIDI && (e.text.contains("Touch") || e.id % 25 == 0) {
                AppLog.write("MIDI \(e.text)")
            }
            lastLoggedMIDI = last.id
        }
        if t != telemetry { telemetry = t }
        peakRPM = max(peakRPM, abs(t.rpm))
        if log.last?.id != midiLog.last?.id { midiLog = log }
        if cal {
            calibrationSamples = samples
            calibrationCounts = counts
        }
        if devices.isEmpty { reloadDeviceList() }
    }
}
