# Roteiro de testes

Faça na ordem. Não avance de etapa se a anterior falhar. Preencha a coluna **Resultado** e me mande a tabela (ou um print do app).

Mouse usado: ____________________ · CPI (se souber): _____ · Tampa: Ø ____ mm · Raio do sensor: ____ mm · Superfície: anel impresso / fita crepe

## T0 — Software

| # | Teste | Como | Critério | Resultado |
|---|---|---|---|---|
| 0.1 | Compilação | `cd mac && swift build` | Sem erros | |
| 0.2 | Testes do motor | `swift run jogselftest` | "0 falha(s)" | |
| 0.3 | Empacotamento | `./scripts/make-app.sh` | `build/JogBridge.app` criado | |

## T1 — Identificação do mouse (Etapa 1)

| # | Teste | Como | Critério | Resultado |
|---|---|---|---|---|
| 1.1 | Listagem | `swift run jogprobe` com o receptor plugado | O mouse aparece com transporte USB | |
| 1.2 | X/Y relativos | ver a saída de 1.1 | X e Y com `relativo=true` | |
| 1.3 | Taxa | `jogprobe monitor N`, mexer o mouse na mesa, Ctrl+C | ≥ 80 Hz (anote) | ___ Hz |

## T2 — Captura bruta (Etapa 2)

| # | Teste | Como | Critério | Resultado |
|---|---|---|---|---|
| 2.1 | Sem aceleração | Arraste 10 cm devagar e 10 cm rápido sobre uma régua | ΣX parecido nos dois (±5 %) | |
| 2.2 | Modo exclusivo | `monitor N --seize` | Cursor não se move. Se negar, testar com `sudo` | |
| 2.3 | Parado | Mouse imóvel 30 s | Nenhuma (ou quase nenhuma) linha impressa | |

## T3 — Leitura na tampa (Etapa 4)

| # | Teste | Como | Critério | Resultado |
|---|---|---|---|---|
| 3.1 | Uma volta | `monitor N`, 1 volta pela marca 0°, Ctrl+C | Deslocamento líquido estável | ___ contagens |
| 3.2 | Repetibilidade | Repita 3.1 cinco vezes | Variação < 2 % | |
| 3.3 | Sentido inverso | 1 volta ao contrário | Mesmo valor, sinal oposto | |
| 3.4 | Superfícies | Compare anel impresso × fita crepe × tampa nua | Escolher a de menor variação | |
| 3.5 | Balanço da tampa | Gire apoiando a mão com força na borda | Leitura não falha (o mouse acompanha a tampa) | |
| 3.6 | Mouse travado | Gire rápido 10 voltas | Mouse não gira nem escorrega na gaiola | |

## T4 — App e calibração (Etapa 5)

| # | Teste | Como | Critério | Resultado |
|---|---|---|---|---|
| 4.1 | Conexão | Conectar no app | Cadeado verde (exclusivo) | |
| 4.2 | Calibração | 1 volta, Finalizar | Selo verde · fora do eixo < 15 % | |
| 4.3 | Contador | Zerar, 10 voltas pela marca | Voltas = 10,00 ± 0,05 | |
| 4.4 | Ida e volta | Zerar, 3 voltas para frente e 3 para trás | Volta a 0,00 ± 0,03 | |
| 4.5 | Parada | Girar e soltar | Velocidade vai a 0 em < 100 ms; touch solta | |
| 4.6 | Reversão | Vai e vem rápido 10× | Reversões = ~20 | |
| 4.7 | Velocidade máxima | Girar cada vez mais rápido | Anote o RPM em que as voltas começam a "sumir" | ___ RPM |
| 4.8 | Ruído parado | Tampa parada 60 s | Nenhuma mensagem MIDI no monitor | |
| 4.9 | Mouse "acordando" | Deixe parado 1 min e gire 1/4 de volta | Anote se o início do movimento se perde | |

## T5 — Traktor (Etapas 6 e 7)

| # | Teste | Como | Critério | Resultado |
|---|---|---|---|---|
| 5.1 | Porta | Controller Manager | "Optical Jog" aparece como In-Port | |
| 5.2 | Learn | Botões de Learn do app | Comandos aprendidos | |
| 5.3 | Z1/APC intactas | Usar mixer e pads | Tudo funciona como antes | |
| 5.4 | Escala | 1 volta = 1,8 s de áudio (ver mapeamento) | Ajustado | Ticks/volta = ___ |
| 5.5 | Scratch para frente/trás | Baby scratch sobre um bumbo | Som acompanha a mão nos dois sentidos | |
| 5.6 | Soltar | Scratch e soltar | Música retoma no tempo certo | |
| 5.7 | Pitch bend | Modo Botão, girar sem botão | Faixa acelera/freia suavemente | |
| 5.8 | Scratch rápido | Chirps/transformers | Anote se fica "degrau" | |

## T6 — Latência e ajuste fino (Etapa 8)

| # | Teste | Como | Critério | Resultado |
|---|---|---|---|---|
| 6.1 | Latência ponta a ponta | Grave com o celular em câmera lenta (240 fps) a tampa + a tela do Traktor. Conte quadros entre o início do giro e o movimento da forma de onda. Cada quadro ≈ 4,2 ms | < 30 ms bom · < 50 ms aceitável | ___ ms |
| 6.2 | Estabilidade sem fio | 30 min de uso | Sem desconexão nem travadas | |
| 6.3 | Interferência | Usar com Wi-Fi ativo e receptor em portas diferentes do hub | Sem quedas | |
