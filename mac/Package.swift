// swift-tools-version:5.9
// Optical Wireless Jog — ponte macOS entre sensores de movimento e o Traktor Pro 4.
import PackageDescription

let package = Package(
    name: "OpticalWirelessJog",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "JogBridge", targets: ["JogBridge"]),
        .executable(name: "jogprobe", targets: ["jogprobe"]),
        .executable(name: "jogselftest", targets: ["jogselftest"]),
        .library(name: "JogCore", targets: ["JogCore"]),
    ],
    targets: [
        // Lógica pura (sem dependência de macOS): calibração, conversão em
        // ângulo, ticks de jog, máquina de estados do "touch", codificação MIDI.
        .target(name: "JogCore"),

        // App com interface de diagnóstico: leitura HID do mouse e saída
        // MIDI virtual.
        .executableTarget(
            name: "JogBridge",
            dependencies: ["JogCore"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreMIDI"),
            ]
        ),

        // Ferramenta de linha de comando para as Etapas 1 e 2:
        // lista dispositivos HID e mostra os deslocamentos brutos.
        .executableTarget(
            name: "jogprobe",
            linkerSettings: [.linkedFramework("IOKit")]
        ),

        // Testes do motor sem XCTest (funciona só com Command Line Tools):
        //   swift run jogselftest
        .executableTarget(name: "jogselftest", dependencies: ["JogCore"]),
    ]
)
