import Foundation
import Darwin

/// Relógio monotônico em segundos, na mesma base dos timestamps HID
/// (mach_absolute_time), para que velocidade e timeouts sejam coerentes.
enum Clock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func seconds(fromMach t: UInt64) -> Double {
        Double(t) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }

    static func now() -> Double { seconds(fromMach: mach_absolute_time()) }
}

/// Thread dedicada com run loop próprio. A leitura HID, o motor de jog e a
/// saída MIDI rodam aqui, longe da interface gráfica, para minimizar latência.
final class RunLoopThread: Thread {
    private(set) var runLoop: CFRunLoop!
    private let ready = DispatchSemaphore(value: 0)

    override func main() {
        runLoop = CFRunLoopGetCurrent()
        // Mantém o run loop vivo mesmo sem fontes.
        let keepAlive = Timer(timeInterval: 3600, repeats: true) { _ in }
        RunLoop.current.add(keepAlive, forMode: .default)
        ready.signal()
        CFRunLoopRun()
    }

    func startAndWait() {
        qualityOfService = .userInteractive
        name = "OpticalJog.realtime"
        start()
        ready.wait()
    }

    func perform(_ block: @escaping () -> Void) {
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    func addTimer(interval: TimeInterval, _ block: @escaping () -> Void) {
        perform {
            let t = Timer(timeInterval: interval, repeats: true) { _ in block() }
            t.tolerance = 0
            RunLoop.current.add(t, forMode: .default)
        }
    }
}

/// Log em texto para os testes (evita digitar valores à mão).
/// Grava em <pasta do projeto>/logs/jogbridge-AAAAMMDD.log quando a pasta
/// existe na Mesa; senão, em ~/Library/Logs/OpticalWirelessJog/.
enum AppLog {
    private static let queue = DispatchQueue(label: "OpticalJog.log")
    private static let url: URL = {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let project = home.appendingPathComponent("Desktop/OpticalWirelessJog/logs")
        let dir = fm.fileExists(atPath: project.path) ? project
            : home.appendingPathComponent("Library/Logs/OpticalWirelessJog")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return dir.appendingPathComponent("jogbridge-\(f.string(from: Date())).log")
    }()
    private static let stamp: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    static var path: String { url.path }

    static func write(_ line: String) {
        let text = "\(stamp.string(from: Date()))  \(line)\n"
        queue.async {
            guard let data = text.data(using: .utf8) else { return }
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}
