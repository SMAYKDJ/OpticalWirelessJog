import JogCore
import SwiftUI

// MARK: - Janela Principal com Abas DJ

struct DiagnosticsView: View {
    @EnvironmentObject var c: BridgeController
    @State private var selectedTab: DJTab = .performance

    enum DJTab: String, CaseIterable, Identifiable {
        case performance = "Performance"
        case calibration = "Calibração"
        case technical = "Técnico & MIDI"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .performance: return "waveform.circle.fill"
            case .calibration: return "dial.low.fill"
            case .technical: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(selectedTab: $selectedTab)

            Divider()

            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                switch selectedTab {
                case .performance:
                    PerformanceTabView()
                case .calibration:
                    CalibrationTabView()
                case .technical:
                    TechnicalTabView()
                }
            }
        }
        .frame(minWidth: 960, minHeight: 700)
    }
}

// MARK: - Barra Superior (Status, Dispositivo e Abas)

private struct HeaderBar: View {
    @EnvironmentObject var c: BridgeController
    @Binding var selectedTab: DiagnosticsView.DJTab

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                // Logo & Título
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("OPTICAL WIRELESS JOG")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(0.5)
                        Text("Traktor Pro 4 Bridge")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().frame(height: 24)

                // Status da Conexão
                connectionStatusBadge

                // Seletor de Dispositivo
                HStack(spacing: 6) {
                    Picker("", selection: $c.selectedDeviceID) {
                        Text("Selecione o mouse...").tag(String?.none)
                        ForEach(c.devices) { d in
                            Text(d.label).tag(Optional(d.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    Button { c.refreshDevices() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Atualizar lista de dispositivos USB/Bluetooth")

                    connectButton
                }

                Spacer()

                // Master Toggle do Jog
                Toggle(isOn: $c.jogEnabled) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(c.jogEnabled ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text("JOG ATIVO")
                            .font(.caption.bold())
                    }
                }
                .toggleStyle(.switch)
            }

            // Barra de Abas Estilo DJ
            HStack(spacing: 8) {
                ForEach(DiagnosticsView.DJTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline.bold())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor : Color.primary.opacity(0.06))
                        )
                        .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                // Indicador rápido de Porta MIDI
                Text(c.midiStatus)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder private var connectionStatusBadge: some View {
        switch c.mouseState {
        case .connected(let seized):
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text(seized ? "Conectado (Exclusivo)" : "Conectado")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.12))
            .clipShape(Capsule())

        case .idle:
            HStack(spacing: 6) {
                Circle().fill(Color.secondary).frame(width: 8, height: 8)
                Text("Desconectado")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())

        case .error(let msg):
            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Text(msg)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder private var connectButton: some View {
        switch c.mouseState {
        case .connected:
            Button("Desconectar") { c.disconnectMouse() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .idle, .error:
            Button("Conectar") { c.connectSelectedMouse() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(c.selectedDeviceID == nil)
        }
    }
}

// MARK: - ABA 1: PERFORMANCE (Tocar / Pitch Bend / Scratch)

private struct PerformanceTabView: View {
    @EnvironmentObject var c: BridgeController

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Linha 1: Seletor de Deck e Modos Rápidos de Jog
                HStack(alignment: .top, spacing: 16) {
                    deckSelectorCard
                    jogModeSelectorCard
                }

                // Linha 2: Visualizador Central (Prato + Barra de Nudge Vertical)
                livePerformanceDisplay

                // Linha 3: Ajustes Rápidos de Performance
                quickSettingsBar
            }
            .padding(20)
        }
    }

    // Seletor de Deck A / B
    private var deckSelectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DECK ATIVO NO TRAKTOR")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                // Botão Deck A
                Button {
                    c.setDeck(1)
                } label: {
                    VStack(spacing: 4) {
                        Text("DECK A")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text("Canal MIDI 1")
                            .font(.caption2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(c.settings.midiChannel == 1 ? Color.cyan.opacity(0.25) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(c.settings.midiChannel == 1 ? Color.cyan : Color.clear, lineWidth: 2)
                    )
                    .foregroundStyle(c.settings.midiChannel == 1 ? Color.cyan : Color.primary)
                }
                .buttonStyle(.plain)

                // Botão Deck B
                Button {
                    c.setDeck(2)
                } label: {
                    VStack(spacing: 4) {
                        Text("DECK B")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text("Canal MIDI 2")
                            .font(.caption2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(c.settings.midiChannel == 2 ? Color.orange.opacity(0.25) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(c.settings.midiChannel == 2 ? Color.orange : Color.clear, lineWidth: 2)
                    )
                    .foregroundStyle(c.settings.midiChannel == 2 ? Color.orange : Color.primary)
                }
                .buttonStyle(.plain)
            }

            Toggle("Botão direito do mouse alterna Deck A ↔ B", isOn: $c.rightButtonTogglesDeck)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // Modo do Jog (Pitch Bend vs Scratch)
    private var jogModeSelectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODO DE OPERAÇÃO DO JOG")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                modeOption(
                    title: "⇄ PITCH BEND (Nudge Suave)",
                    subtitle: "Empurrar para cima acelera (+), puxar para trás atrasa (-). A música não para.",
                    mode: .off
                )

                modeOption(
                    title: "💿 HÍBRIDO (Botão = Scratch)",
                    subtitle: "Mouse solto = Pitch Bend suave. Segurando botão esquerdo = Scratch/Parar vinil.",
                    mode: .button
                )

                modeOption(
                    title: "💿 SCRATCH PURO (Auto)",
                    subtitle: "Qualquer movimento segura a música e dá scratch imediatamente.",
                    mode: .auto
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func modeOption(title: String, subtitle: String, mode: TouchMode) -> some View {
        let isSelected = c.settings.touchMode == mode
        return Button {
            var s = c.settings
            s.touchMode = mode
            c.settings = s
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // Display Principal: Prato + Medidor de Nudge Vertical
    private var livePerformanceDisplay: some View {
        HStack(spacing: 24) {
            // Prato Virtual
            VStack(spacing: 12) {
                Text("ROTAÇÃO DO VINIL / JOG")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Dial(
                    revolutions: c.telemetry.revolutions,
                    touching: c.telemetry.touching,
                    direction: c.telemetry.direction
                )
                .frame(width: 220, height: 220)

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("VELOCIDADE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%+.0f RPM", c.telemetry.rpm))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    Divider().frame(height: 24)
                    VStack(spacing: 2) {
                        Text("PICO")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f RPM", c.peakRPM))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    Divider().frame(height: 24)
                    VStack(spacing: 2) {
                        Text("STATUS")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(c.telemetry.touching ? "SCRATCH" : "BEND (SOLTO)")
                            .font(.caption.bold())
                            .foregroundStyle(c.telemetry.touching ? Color.orange : Color.green)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))

            // Medidor Vertical de Pitch Bend (Nudge)
            VStack(spacing: 12) {
                HStack {
                    Text("NUDGE (EMPURRAR / PUXAR)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("AO LADO DA Z1")
                        .font(.caption2.bold())
                        .foregroundStyle(.cyan)
                }

                HStack(spacing: 20) {
                    // Barra Vertical
                    VerticalNudgeBar(displacement: c.telemetry.lastProjected)
                        .frame(width: 44, height: 220)

                    // Leituras e Instruções
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(Color.green)
                                Text("EMPURRAR (Frente)")
                                    .font(.caption.bold())
                            }
                            Text("Acelera o tempo (+)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("DESLOCAMENTO ATUAL")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.0f", c.telemetry.lastProjected))
                                .font(.system(size: 26, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    c.telemetry.lastProjected > 0 ? Color.green : (c.telemetry.lastProjected < 0 ? Color.orange : Color.secondary)
                                )
                            Text(c.telemetry.lastProjected > 0 ? "▲ ACELERANDO" : (c.telemetry.lastProjected < 0 ? "▼ ATRASANDO" : "■ EM REPOUSO"))
                                .font(.caption.bold())
                                .foregroundStyle(
                                    c.telemetry.lastProjected > 0 ? Color.green : (c.telemetry.lastProjected < 0 ? Color.orange : Color.secondary)
                                )
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(Color.orange)
                                Text("PUXAR (Corpo)")
                                    .font(.caption.bold())
                            }
                            Text("Atrasa o tempo (-)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(width: 380)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    // Barra de Ajustes Rápidos
    private var quickSettingsBar: some View {
        HStack(spacing: 20) {
            // Sensibilidade
            HStack(spacing: 12) {
                Text("Sensibilidade:")
                    .font(.subheadline.bold())
                Slider(value: $c.settings.sensitivity, in: 0.2...3.0)
                    .frame(width: 160)
                Text(String(format: "%.2f×", c.settings.sensitivity))
                    .font(.subheadline.monospacedDigit().bold())
                    .frame(width: 50, alignment: .trailing)
            }

            Divider().frame(height: 24)

            // Inverter Sentido
            Toggle("Inverter Sentido (Frente/Trás)", isOn: $c.settings.invert)
                .font(.subheadline.bold())

            Spacer()

            // Zerar Contadores
            Button("Zerar Posição do Disco") {
                c.resetCounters()
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

// MARK: - Barra Vertical de Nudge (Acelerar/Atrasar)

private struct VerticalNudgeBar: View {
    let displacement: Double // lastProjected: positivo sobe, negativo desce

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let midY = h / 2
            let maxDisp: Double = 60 // escala máxima visual
            let norm = max(-1.0, min(1.0, displacement / maxDisp))
            let barH = abs(norm) * (midY - 10)

            ZStack(alignment: .top) {
                // Trilho de fundo
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.08))

                // Marca central (Zero)
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(height: 2)
                    .offset(y: midY - 1)

                // Barra ativa
                if norm > 0.05 {
                    // Acelerando (Verde subindo)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.5), Color.green],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: w - 8, height: barH)
                        .offset(x: 4, y: midY - barH)
                } else if norm < -0.05 {
                    // Atrasando (Laranja/Vermelho descendo)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.5), Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: w - 8, height: barH)
                        .offset(x: 4, y: midY)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

// MARK: - ABA 2: CALIBRAÇÃO GUIADA

private struct CalibrationTabView: View {
    @EnvironmentObject var c: BridgeController
    @State private var targetReference: Double = 1000

    var isMouseConnected: Bool {
        if case .connected = c.mouseState { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status da Conexão do Mouse
                connectionBanner

                // Card de Instruções
                instructionCard

                // Área de Ação e Mostrador Central
                if c.calibrating {
                    activeCalibrationCard
                } else {
                    idleCalibrationCard
                }

                // Ajuste Rápido com Botões [-] e [+] (O que o usuário pediu!)
                manualAdjustmentCard

                // Resultado da Última Calibração (se houver)
                if let r = c.lastCalibration {
                    calibrationResultCard(r)
                }
            }
            .padding(20)
        }
    }

    // Banner de Conexão
    @ViewBuilder private var connectionBanner: some View {
        if isMouseConnected {
            HStack(spacing: 10) {
                Circle().fill(Color.green).frame(width: 10, height: 10)
                Text("Sensor do Mouse Conectado e Pronto para Calibrar")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Spacer()
                Text(String(format: "Taxa: %.0f Hz", c.telemetry.reportRateHz))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
        } else {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MOUSE NÃO CONECTADO")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text("Conecte o mouse antes de iniciar a calibração para que os movimentos sejam lidos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Conectar Agora") {
                    c.connectSelectedMouse()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        }
    }

    // Card de Instruções
    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("COMO CALIBRAR (1 VOLTA COMPLETA)")
                    .font(.subheadline.bold())
            }

            Text("1. Posicione a tampa na marca 0° (ou o mouse na lateral da Z1).\n2. Clique em **Iniciar Calibração**.\n3. Gire até completar 1 volta completa. O disco na tela girará junto indicando o progresso.\n4. Ao completar a volta, clique em **Finalizar Calibração**.\n💡 *Dica:* Se você passar do ponto (ex: passar de 1000 contagens), você pode usar os botões **[-]** e **[+]** abaixo para ajustar com precisão!")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // Card Ativo durante a Calibração
    private var activeCalibrationCard: some View {
        let dialRevs = targetReference > 0 ? (c.calibrationCounts / targetReference) : c.telemetry.revolutions
        return VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 32) {
                // Prato girando em tempo real conforme as contagens entram
                Dial(
                    revolutions: dialRevs,
                    touching: true,
                    direction: c.telemetry.direction
                )
                .frame(width: 190, height: 190)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(c.telemetry.direction > 0 ? Color.green : (c.telemetry.direction < 0 ? Color.red : Color.orange))
                            .frame(width: 10, height: 10)
                        Text(c.telemetry.direction > 0 ? "GIRANDO (AVANÇO)" : (c.telemetry.direction < 0 ? "REVERSO (VOLTANDO)" : "PARADO NA MARCA"))
                            .font(.subheadline.bold())
                            .foregroundStyle(c.telemetry.direction > 0 ? Color.green : (c.telemetry.direction < 0 ? Color.red : Color.orange))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f", c.calibrationCounts))
                            .font(.system(size: 46, weight: .black, design: .monospaced))
                            .foregroundStyle(c.calibrationCounts >= targetReference ? Color.green : Color.primary)
                        Text("contagens registradas (meta de 1 volta: \(Int(targetReference)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Label(String(format: "%.2f volta(s)", dialRevs), systemImage: "arrow.triangle.2.circlepath")
                        Label("\(c.calibrationSamples) amostras", systemImage: "waveform.path")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.4), lineWidth: 2))

            HStack(spacing: 16) {
                Button("Cancelar") { c.cancelCalibration() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Spacer()

                Button("Finalizar Calibração (1 volta feita)") {
                    c.finishCalibration()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // Card Ocioso para Iniciar
    private var idleCalibrationCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "dial.low.fill")
                .font(.system(size: 48))
                .foregroundStyle(isMouseConnected ? Color.accentColor : Color.secondary)

            Text("Pronto para Calibrar")
                .font(.title3.bold())

            Text(isMouseConnected ? "Clique abaixo, faça o movimento de 1 volta e veja o disco girar junto." : "Conecte o mouse primeiro para poder calibrar.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Iniciar Calibração") {
                c.startCalibration()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isMouseConnected)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // Ajuste Manual com Botões [-] e [+] (Solicitado pelo usuário!)
    private var manualAdjustmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AJUSTE FINO DE CONTAGENS POR VOLTA")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("VALOR ATUAL SALVO")
                    .font(.caption2.bold())
                    .foregroundStyle(.cyan)
            }

            HStack(spacing: 12) {
                // Botões de Diminuir
                Group {
                    Button("- 50") { c.adjustCounts(by: -50) }
                    Button("- 10") { c.adjustCounts(by: -10) }
                    Button("- 1") { c.adjustCounts(by: -1) }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                // Valor Central Destacado
                HStack(spacing: 6) {
                    TextField("", value: $c.settings.countsPerRevolution, format: .number.precision(.fractionLength(0)))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .frame(width: 90)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)

                    Text("contagens")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                // Botões de Aumentar
                Group {
                    Button("+ 1") { c.adjustCounts(by: +1) }
                    Button("+ 10") { c.adjustCounts(by: +10) }
                    Button("+ 50") { c.adjustCounts(by: +50) }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                // Botão de Atalho para Exatos 1000
                Button("Definir 1000") {
                    c.setCountsDirectly(1000)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .help("Define exatamente 1000 contagens por volta")
            }

            Divider()

            HStack {
                Toggle("Inverter Sentido de Rotação", isOn: $c.settings.invert)
                    .font(.callout.bold())
                Spacer()
                Text("Se o disco estiver girando para trás, ative a inversão.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // Card com Resultado da Última Calibração
    private func calibrationResultCard(_ r: AxisCalibrator.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: r.isReliable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(r.isReliable ? Color.green : Color.orange)
                Text(r.isReliable ? "RESULTADO DA CALIBRAÇÃO: CONFIÁVEL" : "RESULTADO DA CALIBRAÇÃO: ATENÇÃO")
                    .font(.subheadline.bold())
                    .foregroundStyle(r.isReliable ? Color.green : Color.orange)
            }

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                GridRow {
                    Text("Contagens medidas:").foregroundStyle(.secondary)
                    Text(String(format: "%.0f", r.countsPerRevolution)).bold()
                    Text("Ângulo do eixo:").foregroundStyle(.secondary)
                    Text(String(format: "%.1f°", atan2(r.axisY, r.axisX) * 180 / .pi)).bold()
                }
                GridRow {
                    Text("Retidão:").foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", r.straightness * 100)).bold()
                    Text("Desvio fora do eixo:").foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", r.offAxisRatio * 100)).bold()
                }
            }
            .font(.callout.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

// MARK: - ABA 3: TÉCNICO & MIDI

private struct TechnicalTabView: View {
    @EnvironmentObject var c: BridgeController

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Coluna Esquerda: Mapeamento MIDI e Botões de Learn do Traktor
            VStack(alignment: .leading, spacing: 16) {
                traktorMappingSection
                traktorLearnSection
                macosPermissionSection
            }
            .frame(maxWidth: .infinity)

            // Coluna Direita: Monitor MIDI e Telemetria Bruta
            VStack(alignment: .leading, spacing: 16) {
                midiMonitorSection
                rawTelemetrySection
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
    }

    // Mapeamento MIDI
    private var traktorMappingSection: some View {
        GroupBox("Mapeamento MIDI (Porta 'Optical Jog')") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Canal MIDI:")
                    Picker("", selection: Binding(get: { c.settings.midiChannel }, set: { c.setDeck($0) })) {
                        Text("Canal 1 (Deck A)").tag(1)
                        Text("Canal 2 (Deck B)").tag(2)
                        Text("Canal 3 (Deck C)").tag(3)
                        Text("Canal 4 (Deck D)").tag(4)
                    }
                    .frame(width: 170)
                }

                HStack {
                    Text("Modo Encoder:")
                    Picker("", selection: $c.settings.encoderMode) {
                        Text("7Fh/01h (Padrão Traktor)").tag(EncoderMode.mode7F01)
                        Text("3Fh/41h").tag(EncoderMode.mode3F41)
                    }
                    .frame(width: 210)
                }

                Divider()

                HStack(spacing: 16) {
                    Text("CC Jog Turn:")
                    TextField("", value: $c.settings.turnCC, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)

                    Text("Nota Jog Touch:")
                    TextField("", value: $c.settings.touchNote, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Ticks por volta:")
                    Slider(value: $c.settings.ticksPerRevolution, in: 64...4096)
                    Text(String(format: "%.0f", c.settings.ticksPerRevolution)).monospacedDigit().frame(width: 50)
                }
            }
            .font(.callout)
            .padding(6)
        }
    }

    // Botões didáticos para o Learn do Traktor
    private var traktorLearnSection: some View {
        GroupBox("Simulador de Sinais MIDI para o Traktor (Learn)") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quando estiver no Traktor em **Preferences ▸ Controller Manager**, selecione o comando, ative o botão **Learn** e clique em um dos botões abaixo para enviar o sinal exato:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Bloco 1: Giro do Disco (Jog Turn)
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. ROTAÇÃO DO PRATO (COMANDO 'JOG TURN' · CC 20)")
                        .font(.caption2.bold())
                        .foregroundStyle(.cyan)

                    HStack(spacing: 8) {
                        Button {
                            c.sendLearnTurn(true)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Girar p/ Frente (+1)")
                            }
                        }
                        .help("Simula girar a roda ou empurrar o mouse para frente (Avançar / Acelerar)")

                        Button {
                            c.sendLearnTurn(false)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Girar p/ Trás (-1)")
                            }
                        }
                        .help("Simula girar a roda ou puxar o mouse para trás (Retroceder / Atrasar)")
                    }
                    .controlSize(.small)

                    Text("• Use no Traktor com o comando: **Deck Common ▸ Jog Turn**")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.cyan.opacity(0.06)))

                // Bloco 2: Mão no Prato (Jog Touch)
                VStack(alignment: .leading, spacing: 6) {
                    Text("2. MÃO NO VINIL (COMANDO 'JOG TOUCH' · NOTA 20)")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)

                    HStack(spacing: 8) {
                        Button {
                            c.sendLearnTouch(true)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.raised.fill")
                                Text("Segurar Vinil (Touch ON)")
                            }
                        }
                        .help("Simula colocar a mão no prato: para o som imediatamente para permitir scratch")

                        Button {
                            c.sendLearnTouch(false)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.raised")
                                Text("Soltar Vinil (Touch OFF)")
                            }
                        }
                        .help("Simula tirar a mão do prato: libera a música para continuar tocando normalmente")
                    }
                    .controlSize(.small)

                    Text("• Use no Traktor com o comando: **Deck Common ▸ Jog Touch** (Modo: Hold)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.06)))
            }
            .padding(6)
        }
    }

    // Permissão macOS
    private var macosPermissionSection: some View {
        GroupBox("Permissão de Monitoramento de Entrada (macOS)") {
            HStack {
                Image(systemName: c.hasInputMonitoring ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(c.hasInputMonitoring ? Color.green : Color.orange)
                Text(c.hasInputMonitoring ? "Permissão de entrada concedida." : "Permissão necessária nos Ajustes.")
                    .font(.caption)
                Spacer()
                if !c.hasInputMonitoring {
                    Button("Solicitar") { c.requestInputMonitoring() }
                        .controlSize(.small)
                }
            }
            .padding(6)
        }
    }

    // Monitor MIDI
    private var midiMonitorSection: some View {
        GroupBox("Log de Mensagens MIDI Enviadas") {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if c.midiLog.isEmpty {
                        Text("Aguardando mensagens...").foregroundStyle(.secondary)
                    }
                    ForEach(c.midiLog.suffix(16).reversed()) { e in
                        Text(e.text)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: 160)
            .padding(4)
        }
    }

    // Telemetria Bruta
    private var rawTelemetrySection: some View {
        let t = c.telemetry
        return GroupBox("Telemetria em Tempo Real") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                GridRow {
                    Text("Δ X / Δ Y").foregroundStyle(.secondary)
                    Text(String(format: "%+.0f / %+.0f", t.lastDX, t.lastDY))
                    Text("Projetado / ⟂").foregroundStyle(.secondary)
                    Text(String(format: "%+.0f / %+.0f", t.lastProjected, t.lastPerpendicular))
                }
                GridRow {
                    Text("Taxa do Sensor").foregroundStyle(.secondary)
                    Text(String(format: "%.0f Hz", t.reportRateHz))
                    Text("Taxa MIDI").foregroundStyle(.secondary)
                    Text(String(format: "%.0f msg/s", t.turnMessagesPerSecond))
                }
                GridRow {
                    Text("Desvio Fora do Eixo").foregroundStyle(.secondary)
                    Text(String(format: "%.0f %%", t.offAxisRatio * 100))
                    Text("Scroll Wheel").foregroundStyle(.secondary)
                    Text("\(c.lastWheel)")
                }
            }
            .font(.caption.monospacedDigit())
            .padding(6)
        }
    }
}

// MARK: - Prato Virtual Estilizado (Dial)

private struct Dial: View {
    let revolutions: Double
    let touching: Bool
    let direction: Int

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2 - 6
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Base do Prato (Preto escuro estilo vinil)
            let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
            ctx.fill(disc, with: .color(.black.opacity(0.92)))

            // Sulcos do Vinil (Círculos concêntricos sutis)
            for k in stride(from: 0.30, to: 0.94, by: 0.07) {
                let rr = r * k
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr, width: 2 * rr, height: 2 * rr)),
                    with: .color(.white.opacity(0.06)),
                    lineWidth: 1
                )
            }

            // Aro Externo (Touch = Laranja, Solto = Cinza/Azul)
            ctx.stroke(disc, with: .color(touching ? .orange : Color.gray.opacity(0.5)), lineWidth: 3.5)

            // Agulha Marcadora Branca com sombra
            let a = revolutions * 2 * .pi - .pi / 2
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: CGPoint(x: center.x + cos(a) * r * 0.92, y: center.y + sin(a) * r * 0.92))
            ctx.stroke(needle, with: .color(.white), lineWidth: 3.5)

            // Núcleo Central (LED de Sentido: Verde = Play, Vermelho = Reverso, Cinza = Parado)
            let centerLED = Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))
            ctx.fill(centerLED, with: .color(direction == 0 ? .gray : (direction > 0 ? .green : .red)))
            ctx.stroke(centerLED, with: .color(.white), lineWidth: 1.5)
        }
        .overlay(alignment: .bottom) {
            Text(String(format: "%.2f voltas", revolutions))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .padding(.bottom, 22)
        }
    }
}
