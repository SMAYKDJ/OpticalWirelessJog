import CoreMIDI
import Foundation

/// Porta MIDI virtual "Optical Jog". Aparece no Traktor como In-Port
/// (Preferences ▸ Controller Manager ▸ Add… ▸ Generic MIDI).
/// Não interfere com a Z1 nem com a APC Key 25: é uma porta separada.
final class MIDIOutput {
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private(set) var isReady = false
    private(set) var statusText = "MIDI não iniciado"

    init(name: String = "Optical Jog") {
        var status = MIDIClientCreateWithBlock("OpticalJogClient" as CFString, &client) { _ in }
        guard status == noErr else {
            statusText = "Erro ao criar cliente MIDI (\(status))"
            return
        }
        status = MIDISourceCreate(client, name as CFString, &source)
        guard status == noErr else {
            statusText = "Erro ao criar porta virtual (\(status))"
            return
        }
        // ID estável: o Traktor reconhece a mesma porta após reiniciar o app.
        MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, 0x4F4A_4731) // "OJG1"
        isReady = true
        statusText = "Porta virtual \"\(name)\" ativa"
    }

    deinit {
        if source != 0 { MIDIEndpointDispose(source) }
        if client != 0 { MIDIClientDispose(client) }
    }

    /// Envia várias mensagens curtas (3 bytes) num único MIDIPacketList.
    func send(_ messages: [[UInt8]]) {
        guard isReady, !messages.isEmpty else { return }
        let bufferSize = 64 + messages.count * 16
        let raw = UnsafeMutableRawPointer.allocate(byteCount: bufferSize,
                                                   alignment: MemoryLayout<MIDIPacketList>.alignment)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: MIDIPacketList.self, capacity: 1)
        var packet = MIDIPacketListInit(list)
        for msg in messages where !msg.isEmpty {
            packet = MIDIPacketListAdd(list, bufferSize, packet, 0, msg.count, msg)
        }
        MIDIReceived(source, list)
    }
}
