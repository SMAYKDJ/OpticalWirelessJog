# Solução de problemas

**A lista de mouses aparece vazia**
- Ajustes do Sistema ▸ Privacidade e Segurança ▸ **Monitoramento de Entrada**: habilite o JogBridge (e o Terminal, para o `jogprobe`). Reabra o app.
- Clique no botão de atualizar (↻). O receptor precisa estar plugado e o mouse ligado (com pilha).

**"Conectado (compartilhado)": o cursor anda junto com a tampa**
- O macOS negou o modo exclusivo. Teste `sudo swift run jogprobe monitor N --seize`. Se funcionar com sudo, rode o app com `sudo build/JogBridge.app/Contents/MacOS/JogBridge`.
- Alternativa: use o modo de touch **Automático** e deixe o cursor sobre uma área neutra (não sobre a forma de onda).

**O Traktor não vê a porta "Optical Jog"**
- Abra o JogBridge **antes** do Traktor. Confira em Audio MIDI Setup ▸ Janela ▸ Mostrar Estúdio MIDI.

**O jog só anda para um lado**
- Enc.-Mode diferente entre o app e o Traktor. Use os dois em `7Fh/01h` (ou os dois em `3Fh/41h`).

**O sentido está invertido**
- Marque "Inverter sentido" no app, ou recalibre girando no sentido play.

**Calibração com selo laranja**
- Você voltou a tampa durante a volta, o mouse girou/escorregou na gaiola ou o sensor perdeu leitura. Repita devagar e de forma contínua.

**Leitura falha ou "fora do eixo" alto (> 20 %)**
- Superfície brilhante: cubra a faixa com o anel impresso ou fita crepe.
- O mouse está levantando: confira se a gaiola não está segurando o mouse para cima. Ele deve ficar apoiado pelo próprio peso.
- A tampa bambeia muito na caneca: calce o pegador com um pano dobrado para centralizar.

**Jog trava ou dá saltos de vez em quando**
- Interferência 2,4 GHz: aproxime o receptor da tampa (use o hub/extensão) e afaste-o do roteador.
- Pilha fraca no mouse.
- Mouse entrando em economia de energia depois de parado (teste 4.9).

**Scratch "em degraus"**
- Aumente *Ticks por volta* e reduza *Rotary Sensitivity* no Traktor (mais mensagens, cada uma menor). Confira se a taxa de relatórios está ≥ 100 Hz.
- Limite físico do MIDI relativo: veja `limitacoes-e-comparativo.md`.
