// jogselftest — testes do motor de jog sem depender do Xcode/XCTest.
//   swift run jogselftest
import Foundation
import JogCore

// MARK: - Mini framework

var failures = 0
var checks = 0
var currentTest = ""

func check(_ cond: Bool, _ msg: @autoclosure () -> String) {
    checks += 1
    if !cond { failures += 1; print("   ✗ \(currentTest): \(msg())") }
}
func near(_ a: Double, _ b: Double, _ tol: Double, _ what: String) {
    check(abs(a - b) <= tol, "\(what) = \(String(format: "%.4f", a)), esperado \(b) ± \(tol)")
}
func test(_ name: String, _ body: () -> Void) {
    currentTest = name
    let before = failures
    body()
    print(failures == before ? "✓ \(name)" : "✗ \(name)")
}

// MARK: - Simulação: prato girando sob o sensor

struct SimulatedDisc {
    var axisAngle: Double
    var countsPerRev: Double
    var reportRate: Double = 125

    func reports(rps: Double, duration: Double, start: Double = 0) -> [(Double, Double, Double)] {
        var out: [(Double, Double, Double)] = []
        let dt = 1 / reportRate
        var cx = 0.0, cy = 0.0, t = start
        while t < start + duration - 1e-9 {
            let s = rps * countsPerRev * dt
            cx += s * cos(axisAngle); cy += s * sin(axisAngle)
            let ix = cx.rounded(.towardZero), iy = cy.rounded(.towardZero)
            cx -= ix; cy -= iy; t += dt
            out.append((ix, iy, t))
        }
        return out
    }
}

func engine(axis: Double = 0.3, cpr: Double = 4000, mode: TouchMode = .auto) -> JogEngine {
    var s = JogSettings()
    s.axisX = cos(axis); s.axisY = sin(axis)
    s.countsPerRevolution = cpr
    s.ticksPerRevolution = 512
    s.touchMode = mode
    return JogEngine(settings: s)
}

func run(_ e: JogEngine, _ reports: [(Double, Double, Double)]) -> [JogEvent] {
    var ev: [JogEvent] = []
    for (dx, dy, t) in reports {
        ev += e.inputCounts(dx: dx, dy: 0, at: t)   // X e Y separados, como o IOHIDManager
        ev += e.inputCounts(dx: 0, dy: dy, at: t)
        ev += e.tick(at: t)
    }
    return ev
}

func turnSum(_ ev: [JogEvent]) -> Double {
    Double(ev.reduce(0) { if case .turn(let n) = $1 { return $0 + n }; return $0 })
}

// MARK: - Calibração

print("── Calibração ──")
test("Uma volta limpa") {
    let disc = SimulatedDisc(axisAngle: 0.6, countsPerRev: 3800)
    var cal = AxisCalibrator()
    for (dx, dy, _) in disc.reports(rps: 0.5, duration: 2) { cal.add(dx: dx, dy: dy) }
    guard let r = cal.finish() else { check(false, "sem resultado"); return }
    near(atan2(r.axisY, r.axisX), 0.6, 0.01, "eixo (rad)")
    near(r.countsPerRevolution, 3800, 38, "contagens/volta")
    check(r.isReliable, "deveria ser confiável")
}
test("Calibração girando para trás inverte o eixo") {
    let disc = SimulatedDisc(axisAngle: 1.0, countsPerRev: 2000)
    var cal = AxisCalibrator()
    for (dx, dy, _) in disc.reports(rps: -1, duration: 1) { cal.add(dx: dx, dy: dy) }
    guard let r = cal.finish() else { check(false, "sem resultado"); return }
    near(r.axisX, -cos(1.0), 0.01, "axisX"); near(r.axisY, -sin(1.0), 0.01, "axisY")
}
test("Vai-e-volta é marcado como não confiável") {
    let disc = SimulatedDisc(axisAngle: 0, countsPerRev: 2000)
    var cal = AxisCalibrator()
    for (dx, dy, _) in disc.reports(rps: 1, duration: 0.5) { cal.add(dx: dx, dy: dy) }
    for (dx, dy, _) in disc.reports(rps: -1, duration: 0.45) { cal.add(dx: dx, dy: dy) }
    check(cal.finish().map { !$0.isReliable } ?? false, "deveria ser não confiável")
}
test("Estimativa teórica (1000 CPI, r = 25,4 mm)") {
    near(AxisCalibrator.theoreticalCountsPerRevolution(cpi: 1000, radiusMM: 25.4), 6283.18, 0.1, "contagens")
}

// MARK: - Motor

print("── Motor de jog ──")
test("1 volta = 512 ticks e touch no início") {
    let e = engine()
    let ev = run(e, SimulatedDisc(axisAngle: 0.3, countsPerRev: 4000).reports(rps: 0.55, duration: 1 / 0.55))
    near(turnSum(ev), 512, 3, "ticks")
    near(e.telemetry.revolutions, 1, 0.01, "voltas")
    check(ev.first == .touch(true), "primeiro evento deveria ser touch ON")
}
test("Ida e volta retorna a zero") {
    let e = engine()
    let d = SimulatedDisc(axisAngle: 0.3, countsPerRev: 4000)
    var ev = run(e, d.reports(rps: 2, duration: 0.25))
    ev += run(e, d.reports(rps: -2, duration: 0.25, start: 0.25))
    near(turnSum(ev), 0, 3, "ticks")
    check(e.telemetry.reversals >= 1, "reversão não detectada")
}
test("Scratch rápido divide mensagens em no máx. ±63") {
    let e = engine()
    let ev = run(e, SimulatedDisc(axisAngle: 0.3, countsPerRev: 4000, reportRate: 15).reports(rps: 5, duration: 0.4))
    for case .turn(let n) in ev { check(abs(n) <= 63, "mensagem com \(n)") }
    near(turnSum(ev), 1024, 70, "ticks")
}
test("Giro muito lento não perde ticks") {
    let e = engine()
    let ev = run(e, SimulatedDisc(axisAngle: 0.3, countsPerRev: 4000).reports(rps: 0.05, duration: 4))
    near(turnSum(ev), 102.4, 4, "ticks")
}
test("Movimento perpendicular é ignorado") {
    let e = engine(axis: 0)
    var ev: [JogEvent] = []
    for i in 1...50 { ev += e.inputCounts(dx: 0, dy: 10, at: Double(i) * 0.008) }
    near(turnSum(ev), 0, 0, "ticks")
    check(e.telemetry.offAxisRatio > 0.5, "offAxis deveria ser alto")
}
test("Tremida com prato parado não gera MIDI") {
    let e = engine(axis: 0)
    var ev: [JogEvent] = []
    for i in 0..<40 {
        let t = Double(i) * 0.3
        ev += e.inputCounts(dx: i % 2 == 0 ? 1 : -1, dy: 0, at: t)
        ev += e.tick(at: t + 0.15)
    }
    check(ev.isEmpty, "gerou \(ev.count) eventos")
}
test("Touch automático solta após a pausa") {
    let e = engine()
    _ = run(e, SimulatedDisc(axisAngle: 0.3, countsPerRev: 4000).reports(rps: 1, duration: 0.2))
    check(e.telemetry.touching, "deveria estar tocando")
    check(!e.tick(at: 0.25).contains(.touch(false)), "soltou cedo demais")
    check(e.tick(at: 0.4) == [.touch(false)], "não soltou")
    near(e.telemetry.revPerSecond, 0, 0, "velocidade")
}
test("Modo botão: touch segue o botão") {
    let e = engine(mode: .button)
    check(e.setButton(true, at: 0) == [.touch(true)], "botão ↓")
    let ev = run(e, SimulatedDisc(axisAngle: 0.3, countsPerRev: 4000).reports(rps: 1, duration: 0.1, start: 0.01))
    check(!ev.contains(.touch(true)), "touch duplicado")
    check(e.setButton(false, at: 0.5) == [.touch(false)], "botão ↑")
}
test("Inverter sentido") {
    let e = engine(axis: 0)
    e.settings.invert = true
    check(turnSum(e.inputCounts(dx: 400, dy: 0, at: 0)) < 0, "deveria ser negativo")
}
test("Velocidade com entrada angular direta") {
    let e = engine()
    var ev: [JogEvent] = []
    for i in 1...200 { ev += e.inputRevolutions(0.005, at: Double(i) * 0.005) }
    near(turnSum(ev), 512, 1, "ticks")
    near(e.telemetry.revPerSecond, 1, 0.05, "voltas/s")
    check(e.telemetry.direction == 1, "sentido")
}

// MARK: - MIDI

print("── Codificação MIDI ──")
test("Encoder 7Fh/01h e 3Fh/41h ida e volta") {
    for mode in EncoderMode.allCases {
        for v in [-63, -10, -1, 1, 10, 63] {
            check(MIDIEncoding.decodeEncoder(MIDIEncoding.encoderValue(v, mode: mode), mode: mode) == v, "\(mode) \(v)")
        }
    }
    check(MIDIEncoding.encoderValue(-1, mode: .mode7F01) == 0x7F, "-1 em 7F01")
    check(MIDIEncoding.encoderValue(1, mode: .mode3F41) == 0x41, "+1 em 3F41")
}
test("Mensagens canal 2") {
    var s = JogSettings()
    s.midiChannel = 2; s.turnCC = 20; s.touchNote = 20
    check(MIDIEncoding.bytes(for: .turn(-2), settings: s) == [0xB1, 20, 126], "turn")
    check(MIDIEncoding.bytes(for: .touch(true), settings: s) == [0x91, 20, 127], "touch on")
    check(MIDIEncoding.bytes(for: .touch(false), settings: s) == [0x91, 20, 0], "touch off")
}

print("\n\(checks) verificações, \(failures) falha(s)")
exit(failures == 0 ? 0 : 1)
