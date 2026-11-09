# Mapeamento no Traktor Pro 4

O JogBridge cria a porta MIDI virtual **"Optical Jog"**. Ela fica separada da Z1 e da APC Key 25. Os mapeamentos delas não mudam.

## Valores padrão enviados pelo app

| Função | Mensagem | Deck A | Deck B |
|---|---|---|---|
| Jog Turn | CC 20, encoder relativo (7Fh/01h) | canal 1 | canal 2 |
| Jog Touch | Note 20 (vel 127 = encosta, 0 = solta) | canal 1 | canal 2 |

Esses valores podem ser alterados no app (seção 3).

## Passo a passo

1. Abra o **JogBridge** primeiro, para a porta virtual existir. Depois abra o Traktor.
2. **Preferences ▸ Controller Manager ▸ Device ▸ Add… ▸ Generic MIDI**.
3. Renomeie (Edit… ▸ Rename) para `Optical Jog`.
4. **In-Port:** `Optical Jog` · **Out-Port:** `None`.

### Jog Turn (Deck A)

1. **Add In… ▸ Deck Common ▸ Jog Turn**.
2. Clique em **Learn**. No app, clique em **"Learn: Jog Turn +1"**. Deve aparecer `Ch01.CC.020`. Desligue o Learn.
3. **Assignment:** `Deck A`.
4. **Type of Controller:** `Encoder` · **Interaction Mode:** `Relative`.
5. **Enc.-Mode:** `7Fh/01h` (o mesmo valor que estiver selecionado no app).
6. **Rotary Sensitivity:** comece em `100%`. **Rotary Acceleration:** `0%`. A aceleração deforma o scratch; a resposta deve ser linear.

### Jog Touch (Deck A)

1. **Add In… ▸ Deck Common ▸ Jog Touch** (em algumas versões aparece como *Jog Touch On*).
2. **Learn** e, no app, clique em **"Learn: Touch ON"**. Deve aparecer `Ch01.Note.G#0` ou similar (nota 20).
3. **Assignment:** `Deck A` · **Type:** `Button` · **Interaction Mode:** `Hold`.

### Deck B (opcional)

Duplique os dois comandos (**Duplicate**). Troque o canal para `Ch02` e o Assignment para `Deck B`. No app, escolha o deck no seletor ou ative "Botão direito alterna Deck A/B".

> Alternativa: use Assignment `Focus Deck` com um único canal. Assim o jog controla o deck em foco, e você troca o foco pela Z1 ou pela APC.

4. **Exporte** o mapeamento: Edit… ▸ Export ▸ `OpticalJog.tsi`.

## Calibrar a "sensação de vinil"

Num toca-discos de 33⅓ RPM, uma volta equivale a 1,8 s de áudio.

1. Carregue uma faixa com transientes claros (bumbo a cada batida). Pause.
2. No app, modo **Sempre scratch**. Gire **exatamente 1 volta** usando a marca 0° da tampa.
3. Veja quanto a agulha do Traktor andou. Se passou de 1,8 s (quase 1 compasso a 128 BPM), diminua **Ticks por volta** no app. Se andou menos, aumente.
4. Para ajuste fino, use **Rotary Sensitivity** no Traktor.

Use só um dos dois controles para o ajuste grosso (de preferência *Ticks por volta*). Assim os resultados ficam reprodutíveis.

## Modos de touch e o que o Traktor faz

| Modo no app | Girar sem botão | Girar com botão | Parar |
|---|---|---|---|
| Automático | scratch | scratch | faixa volta a tocar após 140 ms |
| Botão esquerdo | **pitch bend** (empurra/freia) | **scratch** | — |
| Sempre scratch | scratch | scratch | faixa fica parada (mão no vinil) |
| Só pitch bend | pitch bend | pitch bend | — |

O modo **Botão esquerdo** é o mais próximo de um jog de controladora. Ele só funciona bem se o mouse estiver em **modo exclusivo** (cadeado verde no app). Sem isso, o clique também chega ao macOS e pode arrastar coisas na tela do Traktor.
