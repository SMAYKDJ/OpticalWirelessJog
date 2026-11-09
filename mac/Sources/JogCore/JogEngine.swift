import Foundation

/// Eventos de alto nível que a saída MIDI transforma em mensagens.
public enum JogEvent: Equatable, Sendable {
    /// Ticks relativos de `Jog Turn` (positivo = sentido "play").
    case turn(Int)
    /// `Jog Touch` (mão no prato).
    case touch(Bool)
}

/// Estado instantâneo exposto à interface de diagnóstico.
public struct JogTelemetry: Equatable, Sendable {
    public var lastDX: Double = 0
    public var lastDY: Double = 0
    public var lastProjected: Double = 0
    public var lastPerpendicular: Double = 0
    /// Voltas acumuladas desde o último reset (teste de "uma volta").
    public var revolutions: Double = 0
    /// Velocidade angular em voltas por segundo (positivo = play).
    public var revPerSecond: Double = 0
    /// -1 (reverso), 0 (parado), +1 (play).
    public var direction: Int = 0
    public var touching: Bool = false
    public var button: Bool = false
    /// Relatórios de movimento por segundo vindos do sensor.
    public var reportRateHz: Double = 0
    /// Mensagens de Jog Turn por segundo enviadas.
    public var turnMessagesPerSecond: Double = 0
    /// Fração média de movimento fora do eixo tangencial (0–1).
    public var offAxisRatio: Double = 0
    /// Reversões instantâneas detectadas desde o reset.
    public var reversals: Int = 0

    public var rpm: Double { revPerSecond * 60 }

    public init() {}
}

/// Converte deslocamentos (contagens X/Y do sensor óptico do mouse) em
/// eventos de jog para o Traktor.
///
/// Toda a lógica é determinística e recebe o tempo explicitamente, para
/// poder ser testada sem hardware.
public final class JogEngine {
    public var settings: JogSettings
    public private(set) var telemetry = JogTelemetry()

    private var tickRemainder = 0.0
    private var gateBuffer = 0.0
    private var gateTime: Double = -.infinity
    private var lastMotionTime: Double = -.infinity
    private var touching = false
    private var buttonDown = false

    // Janela para estimar velocidade: (tempo, voltas acumuladas)
    private var history: [(t: Double, rev: Double)] = []
    private let velocityWindow = 0.030

    // Contadores de taxa
    private var reportTimes: [Double] = []
    private var turnTimes: [Double] = []
    private var lastReportTime: Double = -.infinity
    private var offAxisEMA = 0.0
    private var lastDirection = 0

    public init(settings: JogSettings = JogSettings()) {
        self.settings = settings
    }

    // MARK: - Entradas

    /// Entrada do sensor óptico (contagens brutas do relatório HID).
    /// X e Y podem chegar em chamadas separadas com o mesmo `time`:
    /// como a projeção é linear, o resultado é o mesmo.
    @discardableResult
    public func inputCounts(dx: Double, dy: Double, at time: Double) -> [JogEvent] {
        let len = settings.axisLength
        let ax = len > 0 ? settings.axisX / len : 1
        let ay = len > 0 ? settings.axisY / len : 0

        var s = dx * ax + dy * ay
        let perp = -dx * ay + dy * ax
        if settings.invert { s = -s }

        if dx != 0 { telemetry.lastDX = dx }
        if dy != 0 { telemetry.lastDY = dy }
        telemetry.lastProjected = s
        telemetry.lastPerpendicular = perp
        let mag = abs(s) + abs(perp)
        if mag > 0 {
            offAxisEMA += 0.05 * (abs(perp) / mag - offAxisEMA)
            telemetry.offAxisRatio = offAxisEMA
        }

        noteReport(at: time)

        // Portão de ruído: com o prato parado, pequenas contagens isoladas
        // são acumuladas e só passam se ultrapassarem o limiar.
        let stopped = (time - lastMotionTime) * 1000 > settings.stopTimeoutMs
        if stopped {
            // Ruído isolado "envelhece": não deixa um passeio aleatório de
            // ±1 contagem virar movimento falso depois de muito tempo.
            if time - gateTime > 0.2 { gateBuffer = 0 }
            gateTime = time
            gateBuffer += s
            if abs(gateBuffer) <= settings.jitterGateCounts {
                return []
            }
            s = gateBuffer
            gateBuffer = 0
        }

        guard settings.countsPerRevolution > 0 else { return [] }
        return inputRevolutions(s / settings.countsPerRevolution, at: time, countReport: false)
    }

    /// Entrada angular direta (voltas). O caminho do mouse passa por aqui
    /// depois da projeção; também serve para testes e futuras fontes.
    @discardableResult
    public func inputRevolutions(_ delta: Double, at time: Double, countReport: Bool = true) -> [JogEvent] {
        if countReport { noteReport(at: time) }
        guard delta != 0 else { return [] }

        var events: [JogEvent] = []
        lastMotionTime = time

        // Touch automático: a "mão encosta" no primeiro movimento.
        if !touching {
            switch settings.touchMode {
            case .auto, .always:
                touching = true
                events.append(.touch(true))
            case .button, .off:
                break
            }
        }

        telemetry.revolutions += delta
        history.append((t: time, rev: telemetry.revolutions))
        trimHistory(now: time)
        updateVelocity(now: time)

        // Ticks MIDI com acúmulo fracionário (nada se perde em giros lentos).
        tickRemainder += delta * settings.ticksPerRevolution * settings.sensitivity
        let whole = Int(tickRemainder.rounded(.towardZero))
        if whole != 0 {
            tickRemainder -= Double(whole)
            let maxStep = max(1, min(63, settings.maxStepPerMessage))
            var remaining = whole
            while remaining != 0 {
                let step = remaining > 0 ? min(remaining, maxStep) : max(remaining, -maxStep)
                events.append(.turn(step))
                remaining -= step
                turnTimes.append(time)
            }
        }

        telemetry.touching = touching
        return events
    }

    /// Botão do mouse / do dispositivo.
    @discardableResult
    public func setButton(_ down: Bool, at time: Double) -> [JogEvent] {
        guard down != buttonDown else { return [] }
        buttonDown = down
        telemetry.button = down
        guard settings.touchMode == .button else { return [] }
        touching = down
        telemetry.touching = down
        if !down { tickRemainder = 0 }
        return [.touch(down)]
    }

    /// Chamar periodicamente (ex.: a cada 5 ms). Trata paradas e a
    /// liberação automática do touch.
    @discardableResult
    public func tick(at time: Double) -> [JogEvent] {
        var events: [JogEvent] = []
        let idleMs = (time - lastMotionTime) * 1000

        if idleMs > settings.stopTimeoutMs {
            telemetry.revPerSecond = 0
            telemetry.direction = 0
            history.removeAll(keepingCapacity: true)
        } else {
            trimHistory(now: time)
            updateVelocity(now: time)
        }

        if settings.touchMode == .auto, touching, idleMs > settings.touchReleaseMs {
            touching = false
            tickRemainder = 0
            events.append(.touch(false))
        }
        if settings.touchMode == .off, touching {
            touching = false
            events.append(.touch(false))
        }

        // Taxas (janela de 1 s)
        reportTimes.removeAll { time - $0 > 1 }
        turnTimes.removeAll { time - $0 > 1 }
        telemetry.reportRateHz = Double(reportTimes.count)
        telemetry.turnMessagesPerSecond = Double(turnTimes.count)
        telemetry.touching = touching
        return events
    }

    /// Força o estado de touch (ex.: ao trocar de modo para `.always`).
    @discardableResult
    public func applyTouchModeChange() -> [JogEvent] {
        switch settings.touchMode {
        case .always where !touching:
            touching = true; telemetry.touching = true
            return [.touch(true)]
        case .off where touching, .auto where touching && telemetry.direction == 0:
            touching = false; telemetry.touching = false
            return [.touch(false)]
        case .button where touching != buttonDown:
            touching = buttonDown; telemetry.touching = buttonDown
            return [.touch(buttonDown)]
        default:
            return []
        }
    }

    /// Libera tudo (desconexão do sensor).
    @discardableResult
    public func releaseAll() -> [JogEvent] {
        tickRemainder = 0
        gateBuffer = 0
        history.removeAll()
        telemetry.revPerSecond = 0
        telemetry.direction = 0
        guard touching else { return [] }
        touching = false
        telemetry.touching = false
        return [.touch(false)]
    }

    public func resetCounters() {
        telemetry.revolutions = 0
        telemetry.reversals = 0
        telemetry.direction = 0
        history.removeAll()
    }

    public func setCalibrationTelemetry(revolutions: Double, dx: Double, dy: Double, direction: Int, at time: Double) {
        telemetry.revolutions = revolutions
        telemetry.lastDX = dx
        telemetry.lastDY = dy
        telemetry.direction = direction
        telemetry.touching = true
        noteReport(at: time)
    }

    public func setCalibrationStopped() {
        telemetry.direction = 0
    }

    // MARK: - Interno

    private func noteReport(at time: Double) {
        if time != lastReportTime {
            reportTimes.append(time)
            lastReportTime = time
        }
    }

    private func trimHistory(now: Double) {
        while history.count > 2, let first = history.first, now - first.t > velocityWindow {
            history.removeFirst()
        }
    }

    private func updateVelocity(now: Double) {
        guard let first = history.first, let last = history.last else { return }
        let span = max(last.t - first.t, 0.004)
        let v = (last.rev - first.rev) / span
        telemetry.revPerSecond = v

        let deadband = 0.02 // voltas/s
        let dir = v > deadband ? 1 : (v < -deadband ? -1 : 0)
        if dir != 0, lastDirection != 0, dir != lastDirection {
            telemetry.reversals += 1
        }
        if dir != 0 { lastDirection = dir }
        telemetry.direction = dir
    }
}
