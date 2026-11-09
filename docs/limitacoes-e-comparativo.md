# Limitações conhecidas

## MIDI (este projeto) × DVS com timecode

| Aspecto | Jog via MIDI (Jog Turn + Touch) | DVS (timecode de áudio) |
|---|---|---|
| O que chega ao Traktor | Ticks relativos (7 bits, ±63 por mensagem) | Sinal de áudio contínuo com posição e velocidade |
| Resolução temporal | Limitada pela taxa de relatórios do mouse (tipicamente 125 Hz em receptores 2,4 GHz) | Amostral (44,1/48 kHz) |
| Som do scratch | Bom para baby/chirp; pode soar "em degraus" em técnicas rápidas | Referência de mercado |
| Posição absoluta | Não (só relativa) | Sim |
| Hardware extra | Nenhum | Gerar timecode compatível + entrada estéreo (2i2) + DVS habilitado no Traktor |

**Conclusão:** MIDI cobre jog, nudge/pitch bend e scratch básico sem comprar nada. Um caminho DVS seria um app que sintetiza o timecode a partir do ângulo e o entrega ao Traktor por loopback ou pela 2i2. Não foi verificado se o Traktor Pro 4 aceita timecode sintetizado; isso fica como estudo futuro.

## Limitações do mouse como sensor

| Limitação | Efeito | O que fazer |
|---|---|---|
| **Velocidade máxima de rastreamento** do sensor (desconhecida; tipicamente 30–60 pol/s em mouses de escritório) | Em scratch muito rápido, o sensor "pula" e perde voltas | Aproximar o mouse do centro (raio menor) e medir no teste 4.7 |
| **Modo de economia do mouse sem fio** | Depois de alguns segundos parado, o mouse "dorme". O primeiro movimento pode ser perdido ou atrasado | Medir no teste 4.9. Se incomodar, não há correção por software; dá para manter um leve movimento ou deixar a mão na tampa |
| **Taxa de relatórios** (125 Hz típico = um a cada 8 ms) | Define a granularidade do scratch e parte da latência | Medida no teste 1.3 |
| **Superfície** (metal polido, vidro) | Leituras falhas | Anel impresso ou fita crepe |
| **Interferência 2,4 GHz** (Wi-Fi, outros receptores) | Travadas ocasionais | Receptor perto da tampa, de preferência num hub/extensão |
| **Pilha do mouse** | Mouse sem pilha = jog parado | Pilha nova antes de tocar |

## Limitações do código atual

- **Modo exclusivo (seize):** o macOS pode negar para processos sem privilégio, e então o cursor se mexe junto. Solução: rodar com `sudo` ou usar o modo de touch automático com o cursor numa área neutra.
- **Permissões ligadas à assinatura:** cada `make-app.sh` gera assinatura ad-hoc nova, e o macOS pode pedir de novo o Monitoramento de Entrada.
- **Um deck por vez:** troque pelo app ou pelo botão direito do mouse.
- O **app Swift não foi compilado** no ambiente de desenvolvimento (sem macOS).
