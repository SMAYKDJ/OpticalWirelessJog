# Montagem mecânica: tampa de panela + mouse no "braço de agulha"

Sem comprar nada: só o mouse sem fio com o receptor dele, uma tampa de panela reta e coisas de casa.

## Conceito

A tampa vira o prato e gira sobre um eixo. O mouse fica **apoiado sobre a face lisa da tampa, na posição normal** (sensor para baixo), preso por um braço que sai de uma base do lado de fora, como a agulha de um toca-discos. A tampa gira por baixo, o mouse fica parado e o sensor lê a textura passando.

```
 Vista lateral

         braço (régua) ─────────────┐
   ┌──────┐                    ┌────┴────┐  ← "gaiola" de papelão em volta do mouse
   │ base │                    │  MOUSE  │     (folga de 1–2 mm, aberta em cima e embaixo)
   │(livros)                   └─▲───────┘
   │      │      ══════════════════════════════  ← face lisa da tampa + anel de textura
   │      │                   ▲  sensor     ║
   └──────┘                   r ≈ 70 mm     ║  pegador da tampa = eixo
 ───────────────────────────────────── [caneca] ───  mesa

 Vista de cima

            ┌─────────── tampa ───────────┐
           ╱      ░░░ anel de textura ░░░   ╲
          │    ░░                    ░░  ┌───┐   braço
          │   ░░          ●           ░░ │ M │═══════════[ base ]
          │    ░░       centro       ░░  └───┘
           ╲      ░░░░░░░░░░░░░░░░░░░░    ╱
            └─────────────────────────────┘
```

## Por que o mouse fica *apoiado* (e não suspenso)

O sensor óptico só lê a 1–2 mm da superfície. Se o mouse ficar suspenso, qualquer folga ou balanço da tampa tira o sensor de foco. Apoiado pelo próprio peso, sobre os pezinhos de deslizar dele, a distância fica sempre certa, mesmo se a tampa balançar um pouco. Por isso o braço precisa:

- **travar** o mouse na horizontal (não pode andar nem girar junto com a tampa);
- **deixar livre** na vertical (o mouse sobe e desce acompanhando a tampa).

É exatamente o que um braço de toca-discos faz.

## Materiais

- Tampa de panela **reta**, de metal. Se for de vidro, o anel de papel é obrigatório: o sensor não lê vidro transparente.
- Anel de textura: `mechanical/anel-textura-tampa.pdf` (3 setores para recortar) **ou** fita crepe
- Eixo: o próprio pegador da tampa encaixado numa **caneca** ou num copo grosso
- Base do braço: pilha de livros, tijolo ou pote cheio
- Braço: régua, colher de pau ou tira de papelão dobrada (rígida)
- Gaiola do mouse: papelão + fita
- Fita crepe e fita dupla-face

## Passo a passo

### 1. Prato (a tampa)
1. Vire a tampa com o **pegador para baixo**. A face lisa (o "fundo" interno) fica para cima, virada para o mouse.
2. Encaixe o pegador dentro de uma caneca. O fundo da caneca segura o peso e as paredes centralizam. A borda da tampa deve ficar **1–2 cm acima da mesa**. Se a tampa inclinar, a borda encosta na mesa e serve de batente. Se o pegador for curto, ponha um pano dobrado embaixo da caneca. Se for longo, use um copo mais baixo.
3. Gire com o dedo. A tampa deve girar livre e voltar a parar sozinha. Para mais inércia, distribua moedas com fita perto da borda, embaixo.

### 2. Superfície de leitura
Escolha uma opção:
- **Anel impresso (recomendado):** imprima em 100% e confira a régua de 100 mm. Recorte os setores A, B e C e cole formando um anel centrado (raio interno 50 mm, externo 95 mm).
- **Fita crepe:** cole tiras radiais curtas, lado a lado, cobrindo a faixa de 50 a 95 mm do centro. Faça riscos aleatórios de caneta preta por cima: o sensor gosta de contraste.

Nos dois casos, superfície **fosca**. Metal polido ou inox brilhante sem cobertura dá leituras falhas.

**Marca de calibração:** a marca vermelha 0° do setor A, ou um traço de caneta na borda da tampa. Faça também um traço de referência fixo na base.

### 3. Base e braço
1. Coloque a base do lado de fora da tampa, a uns 3–5 cm da borda.
2. Fixe a régua **rígida** no topo da base (fita crepe em várias voltas, ou um livro por cima prendendo). Ela avança por cima da tampa, acima da altura do mouse.
3. Na ponta, faça uma **gaiola de papelão**: um "U" ou retângulo em volta do mouse, com 1–2 mm de folga, preso na régua. Aberto embaixo (o mouse toca a tampa) e em cima.
4. Posicione de modo que o **sensor fique a ~70 mm do centro da tampa** (sobre a trilha azul). Anote a medida real.

### 4. Conferência antes de ligar
- Com a tampa girando, o mouse não pode girar nem escorregar dentro da gaiola.
- A gaiola não pode prender os botões do mouse.
- A roda do mouse e os botões continuam acessíveis: o botão esquerdo pode ser o "touch/scratch" (modo Botão no app).
- O receptor está ligado no MacBook. Se o Mac só tiver USB-C, use o adaptador ou hub que já liga a Z1 e a APC. De preferência, deixe o receptor perto do prato (a menos de 1 m).

## Raio do sensor: precisão × velocidade

| Raio do sensor | Contagens/volta (mouse 1000 CPI) | Velocidade linear a 33⅓ RPM | A 3 voltas/s (scratch forte) |
|---|---|---|---|
| 50 mm | ≈ 12.400 | 6,9 pol/s | 37 pol/s |
| 70 mm (padrão) | ≈ 17.300 | 9,6 pol/s | 52 pol/s |
| 90 mm | ≈ 22.300 | 12,4 pol/s | 67 pol/s |

Qualquer raio dá resolução de sobra: o Traktor usa ~512 ticks por volta. O limite real é a **velocidade máxima de rastreamento** do sensor. Mouses de escritório costumam aguentar algo entre 30 e 60 pol/s; o valor exato do seu é desconhecido e será medido no teste 4.7. Se perder leitura em scratch rápido, **aproxime o mouse do centro** e recalibre.

## Calibração no app (resumo)
1. Alinhe a marca 0° da tampa com o traço da base.
2. JogBridge ▸ **Iniciar calibração**.
3. Gire **1 volta inteira no sentido horário** (sentido "play"), sem voltar, e pare na marca.
4. **Finalizar**. O selo verde indica que deu certo. Confira se o valor de contagens/volta bate com a tabela acima (±20%).

A orientação do mouse na gaiola não importa (reto, torto, de lado): a calibração descobre a direção do movimento. Só não pode mudar depois. Se mexer no mouse ou no braço, recalibre.
