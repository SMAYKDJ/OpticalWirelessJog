// jogprobe — Etapas 1 e 2 do projeto Optical Wireless Jog.
//
//   swift run jogprobe                 lista mouses/apontadores HID
//   swift run jogprobe monitor 0       mostra ΔX/ΔY brutos do dispositivo 0
//   swift run jogprobe monitor 0 --seize   idem, bloqueando o cursor
//   swift run jogprobe monitor 0 --seize --segundos 15   para sozinho após 15 s
//   swift run jogprobe monitor 0 --bloquear-cursor   protótipo do filtro de eventos
//        (descarta os eventos de cursor gerados pelo mouse do jog; pede Acessibilidade)
//
// Durante o monitor, gire a tampa UMA volta e pressione Ctrl+C:
// o resumo mostra contagens totais, taxa de relatórios e o eixo estimado.

import Foundation
import IOKit
import IOKit.hid
import ApplicationServices

setvbuf(stdout, nil, _IOLBF, 0)

func prop(_ d: IOHIDDevice, _ key: String) -> Any? { IOHIDDeviceGetProperty(d, key as CFString) }
func str(_ d: IOHIDDevice, _ key: String) -> String { (prop(d, key) as? String) ?? "" }
func num(_ d: IOHIDDevice, _ key: String) -> Int { (prop(d, key) as? NSNumber)?.intValue ?? 0 }
func registryID(_ d: IOHIDDevice) -> UInt64 {
    var id: UInt64 = 0
    IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(d), &id)
    return id
}

let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
if access != kIOHIDAccessTypeGranted {
    print("⚠️  Sem permissão de Monitoramento de Entrada para este terminal.")
    print("   Ajustes do Sistema ▸ Privacidade e Segurança ▸ Monitoramento de Entrada ▸ habilite o Terminal (ou iTerm) e reabra-o.")
    _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matches: [[String: Any]] = [
    [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
    [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer],
]
IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
let deviceSet = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
// O mesmo dispositivo pode aparecer 2× (casa com "Mouse" e com "Pointer"):
// remove duplicatas pelo ID do registro de E/S.
var seenIDs = Set<UInt64>()
let devices = deviceSet
    .sorted { num($0, kIOHIDLocationIDKey) < num($1, kIOHIDLocationIDKey) }
    .filter { seenIDs.insert(registryID($0)).inserted }

let args = CommandLine.arguments
if args.count < 3 || args[1] != "monitor" {
    print("Dispositivos apontadores encontrados: \(devices.count)\n")
    for (i, d) in devices.enumerated() {
        print(String(format: "[%ld] %@", i, str(d, kIOHIDProductKey)))
        print("    Fabricante: \(str(d, kIOHIDManufacturerKey))")
        print(String(format: "    ID no registro: 0x%llX · uso primário %ld:%ld · interface %ld",
                     registryID(d), num(d, kIOHIDPrimaryUsagePageKey), num(d, kIOHIDPrimaryUsageKey),
                     num(d, "bInterfaceNumber")))
        print("    Transporte: \(str(d, kIOHIDTransportKey))")
        print(String(format: "    VID:PID     %04lX:%04lX", num(d, kIOHIDVendorIDKey), num(d, kIOHIDProductIDKey)))
        print("    Intervalo de relatório: \(num(d, kIOHIDReportIntervalKey)) µs")
        print("    Tamanho máx. do relatório: \(num(d, kIOHIDMaxInputReportSizeKey)) bytes")
        // Elementos relevantes (resolução lógica de X/Y)
        if let elements = IOHIDDeviceCopyMatchingElements(d, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] {
            for e in elements where Int(IOHIDElementGetUsagePage(e)) == kHIDPage_GenericDesktop {
                let u = Int(IOHIDElementGetUsage(e))
                guard u == kHIDUsage_GD_X || u == kHIDUsage_GD_Y || u == kHIDUsage_GD_Wheel else { continue }
                let name = u == kHIDUsage_GD_X ? "X" : (u == kHIDUsage_GD_Y ? "Y" : "Roda")
                print("    \(name): \(IOHIDElementGetReportSize(e)) bits, lógico \(IOHIDElementGetLogicalMin(e))…\(IOHIDElementGetLogicalMax(e)), relativo=\(IOHIDElementIsRelative(e))")
            }
        }
        print("")
    }
    print("Uso: jogprobe monitor <índice> [--seize] [--segundos N]")
    exit(0)
}

guard let index = Int(args[2]), devices.indices.contains(index) else {
    print("Índice inválido."); exit(1)
}
let device = devices[index]
let seize = args.contains("--seize")

// O receptor 2,4 GHz expõe mais de uma interface HID (aparece 2×). Se só uma
// for "presa", o macOS continua movendo o cursor pela outra. Por isso abrimos
// todas as interfaces com o mesmo VID:PID.
let vid = num(device, kIOHIDVendorIDKey), pid = num(device, kIOHIDProductIDKey)
let group = devices.enumerated().filter { num($0.element, kIOHIDVendorIDKey) == vid && num($0.element, kIOHIDProductIDKey) == pid }
var opened: [(Int, IOHIDDevice)] = []
for (i, d) in group {
    var r = IOHIDDeviceOpen(d, IOOptionBits(seize ? kIOHIDOptionsTypeSeizeDevice : kIOHIDOptionsTypeNone))
    var mode = seize ? "exclusivo" : "compartilhado"
    if r != kIOReturnSuccess && seize {
        print(String(format: "[%ld] seize negado (0x%08X) — tente com sudo; abrindo compartilhado", i, r))
        r = IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone))
        mode = "compartilhado"
    }
    if r == kIOReturnSuccess {
        opened.append((i, d))
        print("Interface [\(i)] aberta: \(mode)")
    } else {
        print(String(format: "[%ld] falha ao abrir: 0x%08X", i, r))
    }
}
guard !opened.isEmpty else { exit(1) }
print("Executando como root: \(getuid() == 0 ? "sim" : "não")")

final class Stats {
    var sumX = 0, sumY = 0, sxx = 0.0, syy = 0.0, sxy = 0.0
    var reports = 0
    var lastT: Double = 0
    var firstT: Double = 0
    var minGap = Double.infinity, maxGap = 0.0
    var buttons: [Int: Bool] = [:]
    var gaps: [Double] = []
    // Filtro de cursor (protótipo)
    var lastJogMotion = 0.0, lastJogButton = 0.0, lastJogWheel = 0.0
    var anchor: CGPoint?
    var dropped = 0, droppedClicks = 0, droppedWheel = 0, passed = 0, warps = 0
    var tap: CFMachPort?
    var timebase = mach_timebase_info_data_t()
    init() { mach_timebase_info(&timebase) }
    func seconds(_ t: UInt64) -> Double { Double(t) * Double(timebase.numer) / Double(timebase.denom) / 1e9 }
    func now() -> Double { seconds(mach_absolute_time()) }
}
let stats = Stats()

print("Monitorando \(str(device, kIOHIDProductKey)) — interfaces \(opened.map { $0.0 }). Ctrl+C para o resumo.")
print(">>> Observe se o CURSOR se move enquanto você mexe o mouse.\n")
print("  if    tempo(ms)    ΔX     ΔY     ΣX      ΣY")

let callback: IOHIDValueCallback = { ctx, _, _, value in
    let iface = Int(bitPattern: ctx) - 1
    let e = IOHIDValueGetElement(value)
    let page = Int(IOHIDElementGetUsagePage(e)), usage = Int(IOHIDElementGetUsage(e))
    let v = IOHIDValueGetIntegerValue(value)
    // Este receptor envia "roda 0" e "botão 0" em todo relatório, às vezes
    // com timestamp antigo: valores zero são ignorados.
    if v == 0 && page != kHIDPage_Button { return }
    let t = stats.seconds(IOHIDValueGetTimeStamp(value))
    var dx = 0, dy = 0
    if page == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_X { dx = v }
    else if page == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Y { dy = v }
    else if page == kHIDPage_Button {
        let previous = stats.buttons[usage] ?? false
        if previous == (v != 0) { return }
        stats.buttons[usage] = (v != 0)
        stats.lastJogButton = stats.now()
        if stats.firstT == 0 { stats.firstT = t }
        print(String(format: "[%ld] %12.1f   botão %ld %@", iface, (t - stats.firstT) * 1000, usage, v != 0 ? "↓" : "↑"))
        return
    } else if page == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Wheel {
        stats.lastJogWheel = stats.now()
        if stats.firstT == 0 { stats.firstT = t }
        print(String(format: "[%ld] %12.1f   roda %+ld", iface, (t - stats.firstT) * 1000, v))
        return
    } else { return }
    if dx == 0 && dy == 0 { return }
    stats.lastJogMotion = stats.now()
    if stats.firstT == 0 { stats.firstT = t }
    if t != stats.lastT {
        if stats.lastT > 0 {
            let gap = t - stats.lastT
            stats.minGap = min(stats.minGap, gap); stats.maxGap = max(stats.maxGap, gap)
            stats.gaps.append(gap)
        }
        stats.reports += 1
        stats.lastT = t
    }
    stats.sumX += dx; stats.sumY += dy
    stats.sxx += Double(dx * dx); stats.syy += Double(dy * dy); stats.sxy += Double(dx * dy)
    print(String(format: "[%ld] %12.1f  %+5ld  %+5ld  %+7ld %+7ld", iface, (t - stats.firstT) * 1000, dx, dy, stats.sumX, stats.sumY))
}
for (i, d) in opened {
    IOHIDDeviceRegisterInputValueCallback(d, callback, UnsafeMutableRawPointer(bitPattern: i + 1))
    IOHIDDeviceScheduleWithRunLoop(d, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
}

// ───────── Protótipo: filtro de eventos de cursor ─────────
// O macOS 26 move o cursor mesmo com o mouse "preso" (seize). Aqui, um
// CGEventTap descarta os eventos de cursor que chegam até 40 ms depois de um
// relatório do mouse do jog e devolve o cursor à posição de antes.
let jogWindow = 0.040
let blockCursor = args.contains("--bloquear-cursor")

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = stats.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let now = stats.now()
    let jogMoving = now - stats.lastJogMotion < jogWindow
    switch type {
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
        if jogMoving {
            stats.dropped += 1
            // Teste 1 mostrou: descartar o evento NÃO segura o cursor visível,
            // e a posição lida pelo CoreGraphics não muda (warps = 0). Então
            // reposicionamos o cursor SEMPRE que um movimento do jog é descartado.
            if let a = stats.anchor {
                CGWarpMouseCursorPosition(a)
                stats.warps += 1
            }
            return nil
        }
        stats.passed += 1
        stats.anchor = event.location
    case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
        if now - stats.lastJogButton < jogWindow {
            stats.droppedClicks += 1
            return nil
        }
    case .scrollWheel:
        if now - stats.lastJogWheel < jogWindow || jogMoving {
            stats.droppedWheel += 1
            return nil
        }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

if blockCursor {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(opts)
    print("Acessibilidade concedida: \(trusted ? "sim" : "NÃO")")
    var mask: CGEventMask = 0
    for t: CGEventType in [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                           .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                           .otherMouseDown, .otherMouseUp, .scrollWheel] {
        mask |= CGEventMask(1) << CGEventMask(t.rawValue)
    }
    if let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                   options: .defaultTap, eventsOfInterest: mask,
                                   callback: tapCallback, userInfo: nil) {
        stats.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        // Sem isso, o macOS ignora o mouse por 250 ms após cada "warp".
        CGEventSource(stateID: .combinedSessionState)?.localEventsSuppressionInterval = 0
        stats.anchor = CGEvent(source: nil)?.location
        print("Filtro de cursor ATIVO (janela de \(Int(jogWindow * 1000)) ms).")
    } else {
        print("⚠️  Não foi possível criar o filtro de eventos.")
        print("   Ajustes do Sistema ▸ Privacidade e Segurança ▸ Acessibilidade ▸ habilite o Terminal e reabra-o.")
    }
}

func printSummaryAndExit() {
    let dur = stats.lastT - stats.firstT
    let net = (Double(stats.sumX * stats.sumX + stats.sumY * stats.sumY)).squareRoot()
    let theta = 0.5 * atan2(2 * stats.sxy, stats.sxx - stats.syy)
    print("\n──────── Resumo ────────")
    print("Relatórios: \(stats.reports) em \(String(format: "%.2f", dur)) s → \(String(format: "%.0f", dur > 0 ? Double(stats.reports) / dur : 0)) Hz")
    if stats.maxGap > 0 {
        let moving = stats.gaps.filter { $0 < 0.02 }.sorted()
        let median = moving.isEmpty ? 0 : moving[moving.count / 2]
        print(String(format: "Intervalo entre relatórios: %.1f–%.1f ms · mediana em movimento %.1f ms (≈ %.0f Hz)",
                     stats.minGap * 1000, stats.maxGap * 1000, median * 1000, median > 0 ? 1 / median : 0))
    }
    print("ΣX = \(stats.sumX), ΣY = \(stats.sumY), deslocamento líquido = \(String(format: "%.0f", net)) contagens")
    print(String(format: "Eixo principal: %.1f°  (direção da soma: %.1f°)", theta * 180 / .pi,
                 atan2(Double(stats.sumY), Double(stats.sumX)) * 180 / .pi))
    print("Se você girou exatamente 1 volta: ≈ \(String(format: "%.0f", net)) contagens/volta.")
    if blockCursor {
        print("Filtro: \(stats.dropped) movimentos descartados · \(stats.passed) liberados · \(stats.warps) reposicionamentos · \(stats.droppedClicks) cliques e \(stats.droppedWheel) roda descartados")
    }
    for (_, d) in opened { IOHIDDeviceClose(d, IOOptionBits(kIOHIDOptionsTypeNone)) }
    exit(0)
}

signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler { printSummaryAndExit() }
sigint.resume()

// --segundos N: encerra sozinho e imprime o resumo (bom para gravar log).
if let i = args.firstIndex(of: "--segundos"), i + 1 < args.count, let secs = Double(args[i + 1]) {
    print("(encerra automaticamente em \(Int(secs)) s)")
    DispatchQueue.main.asyncAfter(deadline: .now() + secs) { printSummaryAndExit() }
}
CFRunLoopRun()
