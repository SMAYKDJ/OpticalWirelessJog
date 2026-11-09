import Foundation

/// Calibração do sensor óptico em um único gesto:
/// o usuário alinha a marca da tampa com a referência da base, inicia a calibração,
/// gira **uma volta completa no sentido de "play"** e finaliza.
///
/// Tanto com o mouse fixo e o prato girando (montagem atual) quanto com o mouse
/// girando sobre uma superfície fixa, o ponto lido pelo sensor
/// se move sempre na mesma direção *no referencial do sensor*: a tangente.
/// Por isso:
///   - a soma dos deslocamentos aponta na direção tangencial (eixo);
///   - o módulo da soma projetada é o número de contagens por volta.
///
/// A análise de componentes principais (PCA) é usada como verificação:
/// se o usuário fizer vai-e-volta, a soma fica pequena, mas o eixo
/// principal continua correto — e o resultado é marcado como suspeito.
public struct AxisCalibrator: Sendable {
    public struct Result: Equatable, Sendable {
        public var axisX: Double
        public var axisY: Double
        public var countsPerRevolution: Double
        /// 0–1: fração do movimento que ficou fora do eixo (escorregamento,
        /// desalinhamento, vai-e-volta). Abaixo de ~0.15 é bom.
        public var offAxisRatio: Double
        /// Razão entre deslocamento líquido e caminho total. ~1 = volta limpa.
        public var straightness: Double
        public var sampleCount: Int
        public var isReliable: Bool {
            offAxisRatio < 0.25 && straightness > 0.8 && countsPerRevolution > 50
        }
    }

    private var sumX = 0.0, sumY = 0.0
    private var sxx = 0.0, syy = 0.0, sxy = 0.0
    private var pathLength = 0.0
    private var n = 0

    public init() {}

    public private(set) var lastDirection: Int = 0

    public mutating func add(dx: Double, dy: Double) {
        guard dx != 0 || dy != 0 else { return }
        let net = (sumX * sumX + sumY * sumY).squareRoot()
        if net > 5 {
            let dot = dx * sumX + dy * sumY
            lastDirection = dot >= 0 ? 1 : -1
        } else {
            lastDirection = 1
        }
        sumX += dx; sumY += dy
        sxx += dx * dx; syy += dy * dy; sxy += dx * dy
        pathLength += (dx * dx + dy * dy).squareRoot()
        n += 1
    }

    public var sampleCount: Int { n }

    /// Deslocamento líquido acumulado (módulo do vetor soma).
    public var currentCounts: Double {
        (sumX * sumX + sumY * sumY).squareRoot()
    }

    /// Comprimento total da trajetória percorrida (soma das distâncias de cada amostra).
    public var totalPathLength: Double {
        pathLength
    }

    public func finish(revolutions: Double = 1.0) -> Result? {
        guard n >= 5, revolutions > 0 else { return nil }
        let net = (sumX * sumX + sumY * sumY).squareRoot()

        // Eixo principal (autovetor de maior autovalor da matriz de 2º momento).
        let theta = 0.5 * atan2(2 * sxy, sxx - syy)
        var ax = cos(theta), ay = sin(theta)

        // Orientação: o sentido "play" é o sentido da soma.
        if net > 0 {
            if ax * sumX + ay * sumY < 0 { ax = -ax; ay = -ay }
        }

        // Quando a volta é limpa, a direção da soma é a melhor estimativa.
        if net > 0, pathLength > 0, net / pathLength > 0.8 {
            ax = sumX / net; ay = sumY / net
        }

        // Energia fora do eixo.
        let onAxis = ax * ax * sxx + 2 * ax * ay * sxy + ay * ay * syy
        let total = sxx + syy
        let off = total > 0 ? max(0, (total - onAxis) / total) : 1

        let projected = abs(ax * sumX + ay * sumY)
        return Result(
            axisX: ax, axisY: ay,
            countsPerRevolution: projected / revolutions,
            offAxisRatio: off.squareRoot(),
            straightness: pathLength > 0 ? net / pathLength : 0,
            sampleCount: n
        )
    }

    /// Estimativa teórica, sem calibração física:
    /// contagens/volta = CPI × perímetro(pol) = CPI × 2πr / 25,4.
    public static func theoreticalCountsPerRevolution(cpi: Double, radiusMM: Double) -> Double {
        cpi * 2 * Double.pi * radiusMM / 25.4
    }
}
