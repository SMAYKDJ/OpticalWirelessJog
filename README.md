# Optical Wireless Jog 🎧

> **Transforme qualquer mouse óptico sem fio em um Jog Wheel / Pitch Bend profissional para o Traktor Pro 4 no macOS.**

O **Optical Wireless Jog** é uma ponte de software de ultra-baixa latência construída em Swift puro que lê deslocamentos brutos de um sensor óptico (via IOHIDManager em modo exclusivo), processa a inércia e rotação em tempo real e emite comandos MIDI para o Traktor Pro 4 através de uma porta virtual nativa (`CoreMIDI`).

Pode ser usado de duas formas:
1. **Modo Nudge de Mesa (ao lado do Traktor Kontrol Z1):** O mouse corre em linha reta na mesa. Empurrar para frente acelera o tempo (+); puxar para trás atrasa (-).
2. **Modo Disco / Tampa de Panela:** O mouse lê o movimento tangencial de uma tampa ou prato giratório, proporcionando controle no estilo vinil/CDJ sem gastar nada.

---

## 🚀 Funcionalidades

- **Design DJ Profissional em 3 Abas:**
  - **🎛️ Performance:** Mostrador de vinil animado, medidor vertical de Pitch Bend (Nudge) ao vivo, ajuste de sensibilidade e inversão de sentido.
  - **⚙️ Calibração Guiada:** Calibração óptica em um único gesto de 1 volta completa com mostrador animado, leitura em tempo real e botões `[-]` e `[+]` de ajuste fino.
  - **📊 Técnico & MIDI:** Mapeamento de canais, simulação de sinais para o *Learn* do Traktor (`Jog Turn +1/-1` e `Touch ON/OFF`), console MIDI em tempo real e telemetria de sensores (100–120 Hz).
- **Controle Duplo de Decks (Deck A & Deck B):**
  - **Deck A** no Canal MIDI 1
  - **Deck B** no Canal MIDI 2
  - **Alternância Instantânea:** Clique com o botão direito do mouse para comutar entre os Decks sem sair do Traktor!
- **Modos de Operação do Jog:**
  - `⇄ PITCH BEND (Nudge Suave)`: Acelera e atrasa suavemente sem interromper a música.
  - `💿 HÍBRIDO (Botão = Scratch)`: Movimento livre faz pitch bend; segurar o botão esquerdo para o som e faz scratch.
  - `💿 SCRATCH PURO (Auto)`: Segura e solta a música automaticamente como um vinil.
- **Porta MIDI Virtual Nativa:** Cria automaticamente a porta `"Optical Jog"` reconhecida diretamente pelo Traktor Pro 4 sem necessidade de drivers de terceiros.
- **Modo Exclusivo (HID Seize):** Bloqueia o cursor do mouse no macOS enquanto o jog estiver ativo, evitando cliques acidentais na interface.

---

## 📦 Instalação Rápida (1 Clique)

### Pré-requisitos
- macOS 13.0 (Ventura) ou superior
- Traktor Pro 4 (ou Traktor Pro 3)
- Command Line Tools da Apple (`xcode-select --install`)

### Como Instalar e Iniciar:
1. Clone o repositório ou baixe o arquivo ZIP:
   ```bash
   git clone https://github.com/SEU_USUARIO/OpticalWirelessJog.git
   cd OpticalWirelessJog
   ```
2. Dê **duplo clique** no arquivo **`Iniciar Optical Jog.command`** (ou execute `./install.sh` no Terminal).
3. Na primeira execução, o macOS solicitará permissão em:
   **Ajustes do Sistema ▸ Privacidade e Segurança ▸ Monitoramento de Entrada**.
   Ative a chavinha para o **JogBridge**.

---

## 🎛️ Configuração no Traktor Pro 4

Você pode importar diretamente o arquivo de configurações incluído (**`Settings.tsi`**) ou configurar manualmente no **Preferences ▸ Controller Manager**:

### 1. Criando o dispositivo
1. Vá em **Preferences ▸ Controller Manager**.
2. Clique em **Add... ▸ Generic MIDI**.
3. Em **In-Port** e **Out-Port**, selecione **`Optical Jog`**.

### 2. Comandos para o Deck A (Canal 1)
- **Comando:** `Add In... ▸ Deck Common ▸ Jog Turn` (ou `Tempo Bend (Stepless)`)
  - **Assignment:** `Deck A`
  - **Device Mapping:**
    - Type: `Encoder`
    - Mode: `Relative`
    - Enc.-Mode: `7Fh/01h`
    - Rotary Sensitivity: `100%`
    - Rotary Acceleration: `0%`
  - **MIDI:** `Ch01.CC.020`

### 3. Comandos para o Deck B (Canal 2)
- **Comando:** `Add In... ▸ Deck Common ▸ Jog Turn` (ou `Tempo Bend (Stepless)`)
  - **Assignment:** `Deck B`
  - **Device Mapping:** *(mesmas configurações acima)*
  - **MIDI:** `Ch02.CC.020`

---

## 🛠️ Arquitetura do Código

```
OpticalWirelessJog/
├── Iniciar Optical Jog.command    # Inicializador de duplo clique no macOS
├── install.sh                     # Script de compilação e instalação automática
├── Settings.tsi                   # Mapeamento pré-configurado para o Traktor Pro 4
├── docs/                          # Manuais técnicos e guias de montagem
└── mac/                           # Código-fonte nativo em Swift
    ├── Package.swift              # Configuração do Swift Package Manager
    ├── Sources/
    │   ├── JogCore/               # Motor matemático determinístico, filtros e codificação MIDI
    │   └── JogBridge/             # App SwiftUI com interface profissional e integração IOHID
    └── scripts/
        ├── make-app.sh            # Empacotador e assinador ad-hoc com Designated Requirement
        └── sw                     # Wrapper do Swift fora do cache de sincronização
```

---

## 🤝 Licença e Créditos

Desenvolvido por **Smayk DJ**. Distribuído sob a licença MIT. Sinta-se livre para utilizar, modificar e contribuir!
