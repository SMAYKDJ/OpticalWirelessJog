import Foundation

/// Como o estado "mão no prato" (Jog Touch) é gerado.
///
/// No Traktor, `Jog Turn` com `Jog Touch` desligado faz *tempo bend*
/// (empurrar/segurar a música); com `Jog Touch` ligado faz *scratch*.
public enum TouchMode: String, Codable, CaseIterable, Sendable {
    /// Touch liga no primeiro movimento e desliga após `touchReleaseMs`
    /// sem movimento. Simula a mão encostando/soltando o vinil.
    case auto
    /// Touch segue o botão esquerdo do mouse .
    /// Botão solto = pitch bend; botão pressionado = scratch.
    case button
    /// Touch sempre ligado enquanto o jog estiver ativo (scratch puro).
    case always
    /// Nunca envia touch: só pitch bend / navegação.
    case off
}

/// Formato do encoder relativo enviado no CC de `Jog Turn`.
/// Os nomes batem com o menu "Enc.-Mode" do Controller Manager do Traktor.
public enum EncoderMode: String, Codable, CaseIterable, Sendable {
    /// +n => n, -n => 128-n  (Traktor: "7Fh/01h")
    case mode7F01
    /// +n => 64+n, -n => 64-n (Traktor: "3Fh/41h")
    case mode3F41
}

public struct JogSettings: Codable, Equatable, Sendable {
    // --- Calibração óptica ---------------------------------------------
    /// Direção tangencial (vetor unitário) no referencial do sensor.
    public var axisX: Double = 1
    public var axisY: Double = 0
    /// Contagens do sensor projetadas no eixo por volta completa do prato (tampa).
    public var countsPerRevolution: Double = 17300  // ~1000 CPI a 70 mm do centro
    /// Inverte o sentido (útil se o mouse foi montado ao contrário).
    public var invert: Bool = false

    // --- Resposta do jog -----------------------------------------------
    /// Ticks MIDI enviados por volta do prato antes da sensibilidade.
    public var ticksPerRevolution: Double = 512
    /// Multiplicador geral (1.0 = neutro).
    public var sensitivity: Double = 1.0
    /// Contagens projetadas abaixo disso, com o prato parado, são ruído.
    public var jitterGateCounts: Double = 1.5
    /// Tempo sem movimento para considerar o prato parado.
    public var stopTimeoutMs: Double = 60

    // --- Touch -----------------------------------------------------------
    public var touchMode: TouchMode = .auto
    public var touchReleaseMs: Double = 140

    // --- MIDI -----------------------------------------------------------
    /// Canal MIDI 1–16 (deck A = 1, deck B = 2 por padrão).
    public var midiChannel: Int = 1
    public var turnCC: Int = 20
    public var touchNote: Int = 20
    public var encoderMode: EncoderMode = .mode7F01
    /// Valor máximo por mensagem (1–63). Movimentos maiores são divididos.
    public var maxStepPerMessage: Int = 63

    public init() {}

    public var axisLength: Double { (axisX * axisX + axisY * axisY).squareRoot() }
}
