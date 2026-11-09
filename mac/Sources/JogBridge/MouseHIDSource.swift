import Foundation
import IOKit
import IOKit.hid

/// Descrição de um dispositivo apontador encontrado pelo IOHIDManager.
struct PointerDeviceInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let manufacturer: String
    let transport: String
    let vendorID: Int
    let productID: Int

    var isBluetooth: Bool { transport.lowercased().contains("bluetooth") }
    /// Mouse externo (receptor USB 2.4 GHz ou Bluetooth), não o trackpad.
    var isExternal: Bool {
        let t = transport.lowercased()
        return t.contains("usb") || t.contains("bluetooth")
    }
    var label: String {
        let t = transport.isEmpty ? "?" : transport
        return "\(name) — \(t) [\(String(format: "%04lX:%04lX", vendorID, productID))]"
    }
}

/// Lê deslocamentos **brutos** (relatório HID, antes da aceleração do
/// cursor do macOS) e o estado dos botões de um mouse.
///
/// - Usa IOHIDManager (não CGEvent), então a aceleração do ponteiro não
///   interfere na precisão.
/// - Tenta abrir o mouse em modo *seize* (exclusivo): o cursor não se move
///   e os cliques não chegam ao macOS/Traktor. Se o sistema negar, abre em
///   modo compartilhado e avisa.
/// - Requer a permissão "Monitoramento de Entrada" (Input Monitoring).
final class MouseHIDSource {
    enum State: Equatable {
        case idle
        case connected(seized: Bool)
        case error(String)
    }

    var onCounts: ((Double, Double, Double) -> Void)?   // dx, dy, tempo
    var onButton: ((Int, Bool, Double) -> Void)?        // botão (1…), pressionado, tempo
    var onWheel: ((Int, Double) -> Void)?
    var onDevicesChanged: (() -> Void)?
    var onStateChanged: ((State) -> Void)?

    private let thread: RunLoopThread
    private let manager: IOHIDManager
    private var devices: [String: IOHIDDevice] = [:]
    private var infos: [String: PointerDeviceInfo] = [:]
    private var openDevices: [IOHIDDevice] = []
    private(set) var openDeviceID: String?
    private let infoLock = NSLock()
    private var managerOpened = false

    init(thread: RunLoopThread) {
        self.thread = thread
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matches: [[String: Any]] = [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            Unmanaged<MouseHIDSource>.fromOpaque(ctx).takeUnretainedValue().added(device)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            Unmanaged<MouseHIDSource>.fromOpaque(ctx).takeUnretainedValue().removed(device)
        }, ctx)

        thread.perform { [manager] in
            IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }
        refresh()
    }

    // MARK: Permissão

    static var hasInputMonitoringAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    @discardableResult
    static func requestInputMonitoringAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    // MARK: Dispositivos

    var deviceList: [PointerDeviceInfo] {
        infoLock.lock(); defer { infoLock.unlock() }
        return infos.values.sorted { ($0.isExternal ? 0 : 1, $0.name) < ($1.isExternal ? 0 : 1, $1.name) }
    }

    /// Reenumera (útil se o mouse foi ligado depois do app).
    func refresh() {
        thread.perform { [weak self] in
            guard let self else { return }
            var set = IOHIDManagerCopyDevices(self.manager) as? Set<IOHIDDevice> ?? []
            if set.isEmpty && !self.managerOpened {
                // Algumas versões do macOS só enumeram após abrir o manager.
                IOHIDManagerOpen(self.manager, IOOptionBits(kIOHIDOptionsTypeNone))
                self.managerOpened = true
                set = IOHIDManagerCopyDevices(self.manager) as? Set<IOHIDDevice> ?? []
            }
            for d in set { self.added(d) }
        }
    }

    func connect(id: String) {
        thread.perform { [weak self] in self?.connectOnThread(id: id) }
    }

    func disconnect() {
        thread.perform { [weak self] in self?.closeOnThread(notify: true) }
    }

    // MARK: Interno (thread de tempo real)

    private func connectOnThread(id: String) {
        closeOnThread(notify: false)
        guard let chosen = infos[id], devices[id] != nil else {
            onStateChanged?(.error("Dispositivo não encontrado"))
            return
        }
        // Receptores 2,4 GHz expõem mais de uma interface HID. Se só uma for
        // presa, o macOS continua movendo o cursor pela outra: abrimos todas
        // as interfaces com o mesmo VID:PID.
        let siblingIDs = infos.values
            .filter { $0.vendorID == chosen.vendorID && $0.productID == chosen.productID && $0.vendorID != 0 }
            .map(\.id)
        let ids = siblingIDs.isEmpty ? [id] : siblingIDs

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        var allSeized = true
        var lastError: IOReturn = kIOReturnSuccess
        for devID in ids {
            guard let dev = devices[devID] else { continue }
            // Testes de 08/11 (macOS 26.5): seize, CGEventTap e warp NÃO impedem
            // o cursor de andar. Abrimos em modo compartilhado (só leitura).
            allSeized = false
            let result = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            guard result == kIOReturnSuccess else { lastError = result; continue }
            IOHIDDeviceRegisterInputValueCallback(dev, { ctx, _, _, value in
                guard let ctx else { return }
                Unmanaged<MouseHIDSource>.fromOpaque(ctx).takeUnretainedValue().handle(value)
            }, ctx)
            IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            openDevices.append(dev)
        }

        guard !openDevices.isEmpty else {
            let hint = Self.hasInputMonitoringAccess ? "" :
                " — conceda Monitoramento de Entrada em Ajustes do Sistema ▸ Privacidade e Segurança"
            onStateChanged?(.error(String(format: "Falha ao abrir (0x%08X)%@", lastError, hint)))
            return
        }
        openDeviceID = id
        onStateChanged?(.connected(seized: allSeized))
    }

    private func closeOnThread(notify: Bool) {
        for dev in openDevices {
            IOHIDDeviceRegisterInputValueCallback(dev, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        openDevices.removeAll()
        openDeviceID = nil
        if notify { onStateChanged?(.idle) }
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let v = IOHIDValueGetIntegerValue(value)
        let t = Clock.seconds(fromMach: IOHIDValueGetTimeStamp(value))

        switch (Int(page), Int(usage)) {
        case (kHIDPage_GenericDesktop, kHIDUsage_GD_X):
            if v != 0 { onCounts?(Double(v), 0, t) }
        case (kHIDPage_GenericDesktop, kHIDUsage_GD_Y):
            if v != 0 { onCounts?(0, Double(v), t) }
        case (kHIDPage_GenericDesktop, kHIDUsage_GD_Wheel):
            if v != 0 { onWheel?(v, t) }
        case (kHIDPage_Button, let b) where b >= 1 && b <= 8:
            onButton?(b, v != 0, t)
        default:
            break
        }
    }

    private func added(_ device: IOHIDDevice) {
        let info = Self.describe(device)
        let isNew: Bool
        infoLock.lock()
        isNew = infos[info.id] == nil
        infos[info.id] = info
        infoLock.unlock()
        devices[info.id] = device
        if isNew { onDevicesChanged?() }
    }

    private func removed(_ device: IOHIDDevice) {
        let id = devices.first(where: { $0.value == device })?.key ?? Self.describe(device).id
        infoLock.lock()
        infos[id] = nil
        infoLock.unlock()
        devices[id] = nil
        openDevices.removeAll { $0 == device }
        if openDeviceID == id {
            closeOnThread(notify: false)
            onStateChanged?(.error("Mouse desconectado"))
        }
        onDevicesChanged?()
    }

    private static func describe(_ d: IOHIDDevice) -> PointerDeviceInfo {
        func str(_ key: String) -> String {
            (IOHIDDeviceGetProperty(d, key as CFString) as? String) ?? ""
        }
        func num(_ key: String) -> Int {
            (IOHIDDeviceGetProperty(d, key as CFString) as? NSNumber)?.intValue ?? 0
        }
        let vid = num(kIOHIDVendorIDKey), pid = num(kIOHIDProductIDKey)
        let loc = num(kIOHIDLocationIDKey)
        let serial = str(kIOHIDSerialNumberKey)
        let name = str(kIOHIDProductKey)
        return PointerDeviceInfo(
            id: "\(vid)-\(pid)-\(loc)-\(serial)",
            name: name.isEmpty ? "Dispositivo sem nome" : name,
            manufacturer: str(kIOHIDManufacturerKey),
            transport: str(kIOHIDTransportKey),
            vendorID: vid, productID: pid
        )
    }
}
