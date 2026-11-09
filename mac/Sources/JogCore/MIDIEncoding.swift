import Foundation

/// Converte `JogEvent` em bytes MIDI 1.0 crus.
public enum MIDIEncoding {
    /// Codifica um passo relativo (-63…63, ≠0) para o modo de encoder.
    public static func encoderValue(_ step: Int, mode: EncoderMode) -> UInt8 {
        let s = max(-63, min(63, step))
        switch mode {
        case .mode7F01:
            return UInt8(s >= 0 ? s : 128 + s)
        case .mode3F41:
            return UInt8(64 + s)
        }
    }

    /// Decodifica (para testes e para o monitor).
    public static func decodeEncoder(_ value: UInt8, mode: EncoderMode) -> Int {
        switch mode {
        case .mode7F01:
            return value < 64 ? Int(value) : Int(value) - 128
        case .mode3F41:
            return Int(value) - 64
        }
    }

    public static func bytes(for event: JogEvent, settings: JogSettings) -> [UInt8] {
        let ch = UInt8(max(0, min(15, settings.midiChannel - 1)))
        switch event {
        case .turn(let step):
            guard step != 0 else { return [] }
            return [0xB0 | ch,
                    UInt8(settings.turnCC & 0x7F),
                    encoderValue(step, mode: settings.encoderMode)]
        case .touch(let on):
            // Note On vel 127 = encostou; Note On vel 0 = soltou
            // (o Traktor trata vel 0 como Note Off).
            return [0x90 | ch, UInt8(settings.touchNote & 0x7F), on ? 0x7F : 0x00]
        }
    }
}
