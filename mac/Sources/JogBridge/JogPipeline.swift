import Foundation
import JogCore

/// Junta motor de jog + calibração + MIDI. Thread-safe: o mouse (thread de
/// tempo real) e a interface chamam daqui, e tudo passa pelo mesmo lock
/// (seções muito curtas).
final class JogPipeline {
    struct MIDILogEntry: Identifiable {
        let id: Int
        let time: Double
        let text: String
    }

    private let lock = NSLock()
    private let engine: JogEngine
    private let midi: MIDIOutput
    private var calibrator: AxisCalibrator?
    private var enabled = true
    private var log: [MIDILogEntry] = []
    private var logCounter = 0

    init(settings: JogSettings, midi: MIDIOutput) {
        self.engine = JogEngine(settings: settings)
        self.midi = midi
    }

    var midiStatus: String { midi.statusText }

    // MARK: Entradas das fontes

    func counts(dx: Double, dy: Double, at t: Double) {
        lock.lock(); defer { lock.unlock() }
        if calibrator != nil {
            calibrator!.add(dx: dx, dy: dy)
            // Atualiza telemetria do motor para o prato e a agulha girarem ao vivo na tela,
            // garantindo que o disco complete a volta visual junto com o movimento da tampa!
            let net = calibrator!.currentCounts
            let target = max(50.0, engine.settings.countsPerRevolution)
            let revs = net / target
            engine.setCalibrationTelemetry(revolutions: revs, dx: dx, dy: dy, direction: calibrator!.lastDirection, at: t)
            return
        }
        guard enabled else { return }
        emit(engine.inputCounts(dx: dx, dy: dy, at: t), at: t)
    }

    func button(_ down: Bool, at t: Double) {
        lock.lock(); defer { lock.unlock() }
        emit(engine.setButton(down, at: t), at: t)
    }

    func tick(at t: Double) {
        lock.lock(); defer { lock.unlock() }
        if calibrator != nil {
            _ = engine.tick(at: t)
            return
        }
        emit(engine.tick(at: t), at: t)
    }

    // MARK: Controle

    func update(settings: JogSettings) {
        lock.lock(); defer { lock.unlock() }
        let modeChanged = engine.settings.touchMode != settings.touchMode
        let routingChanged = engine.settings.midiChannel != settings.midiChannel
            || engine.settings.touchNote != settings.touchNote
        if routingChanged {
            // Solta o touch no canal/nota antigos antes de trocar.
            emit(engine.releaseAll(), at: Clock.now())
        }
        engine.settings = settings
        if modeChanged { emit(engine.applyTouchModeChange(), at: Clock.now()) }
    }

    func setEnabled(_ on: Bool) {
        lock.lock(); defer { lock.unlock() }
        enabled = on
        if !on { emit(engine.releaseAll(), at: Clock.now()) }
    }

    func releaseAll() {
        lock.lock(); defer { lock.unlock() }
        emit(engine.releaseAll(), at: Clock.now())
    }

    func resetCounters() {
        lock.lock(); defer { lock.unlock() }
        engine.resetCounters()
    }

    func beginCalibration() {
        lock.lock(); defer { lock.unlock() }
        emit(engine.releaseAll(), at: Clock.now())
        engine.resetCounters() // Zera o prato virtual para 0.000 voltas ao iniciar calibração
        calibrator = AxisCalibrator()
    }

    func calibrationSampleCount() -> Int {
        lock.lock(); defer { lock.unlock() }
        return calibrator?.sampleCount ?? 0
    }

    func calibrationCurrentCounts() -> Double {
        lock.lock(); defer { lock.unlock() }
        return calibrator?.currentCounts ?? 0
    }

    func finishCalibration(revolutions: Double) -> AxisCalibrator.Result? {
        lock.lock(); defer { lock.unlock() }
        let r = calibrator?.finish(revolutions: revolutions)
        calibrator = nil
        return r
    }

    func cancelCalibration() {
        lock.lock(); defer { lock.unlock() }
        calibrator = nil
    }

    /// Mensagens manuais para o "Learn" do Traktor.
    func sendTest(_ event: JogEvent) {
        lock.lock(); defer { lock.unlock() }
        emit([event], at: Clock.now())
    }

    func snapshot() -> (JogTelemetry, [MIDILogEntry], Bool, Double, Int) {
        lock.lock(); defer { lock.unlock() }
        let counts = calibrator?.currentCounts ?? 0
        let samples = calibrator?.sampleCount ?? 0
        return (engine.telemetry, log, calibrator != nil, counts, samples)
    }

    // MARK: Interno (chamado com o lock adquirido)

    private func emit(_ events: [JogEvent], at t: Double) {
        guard !events.isEmpty else { return }
        let s = engine.settings
        let msgs = events.map { MIDIEncoding.bytes(for: $0, settings: s) }
        midi.send(msgs)
        for (e, m) in zip(events, msgs) where !m.isEmpty {
            logCounter += 1
            let hex = m.map { String(format: "%02X", $0) }.joined(separator: " ")
            let label: String
            switch e {
            case .turn(let n): label = "Jog Turn \(n > 0 ? "+" : "")\(n)"
            case .touch(let on): label = on ? "Jog Touch ON" : "Jog Touch OFF"
            }
            log.append(MIDILogEntry(id: logCounter, time: t, text: "\(hex)   \(label)"))
        }
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
