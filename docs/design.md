# O Síndico: design e ferramentas

Como o jogo funciona por dentro, para quem quer entender o código ou escrever cartas. Para instalar e jogar, veja o [README](../README.md).

## Estrutura do plugin

```
sindico_game.koplugin/
  _meta.lua, main.lua          registro no KOReader
  sindico_game/
    engine.lua                 regras, sem depender do KOReader
    content.lua                carrega data/
    ui/screen.lua              telas
    ui/meter_bar.lua           barra dos medidores
    ui/title_case.lua          maiúsculas iniciais dos botões
  data/
    manifest.lua               lista dos decks
    characters.lua, endings.lua, help.lua
    decks/*.lua                cartas
  assets/                      retratos, ícones SVG e prédio
  tools/, tests/, docs/        desenvolvimento, fora do pacote publicado
```

Código, nomes de arquivo, ids de cartas, flags e chaves em inglês. Nomes de personagens e todo texto exibido, em português. O nome do jogo é **O Síndico**; `sindico_game` é o identificador do plugin, escolhido para deixar claro que é um jogo.

## Premissa

Você acaba de ser eleito síndico do Edifício Primavera, um prédio de 12 andares. Cada carta é um morador, funcionário ou fornecedor com um pedido, e você decide por uma de duas respostas. O tom é comédia de costumes: reconhecível, seco, sem crueldade, sem política partidária, sem pessoas reais nem marcas.

## Regras

- **Quatro medidores**, de 0 a 100, começando em 50: **Moradores** (aprovação), **Caixa** (dinheiro do condomínio), **Prédio** (estado da construção) e **Paciência** (a sua sanidade).
- **Chegar a 0 em qualquer medidor encerra o jogo**, com um final próprio. Não há perda por valor alto: medidor muito alto só libera cartas específicas (por exemplo, caixa cheio atrai desconfiança e pedidos de obra).
- **Tempo:** cada decisão avança 12 dias, salvo indicação da carta. Um mandato tem 720 dias.
- **Assembleias:** prestação de contas no dia 360 e eleição no dia 720. Na eleição, é preciso ter Moradores em 50 ou mais para ser reeleito.
- **Mandatos:** a cada reeleição, os medidores voltam um terço do caminho para 50, as cartas voltam ao baralho e os efeitos negativos ficam 15% mais fortes. Vencer 5 mandatos leva ao final de síndico vitalício.
- **Memória:** decisões marcam fatos (flags) que liberam cartas futuras e agendam consequências, às vezes meses depois.
- **Ata:** registro das decisões marcantes (o campo `minutes` das escolhas, cerca de um quarto delas), com mandato e mês. Dá para ler durante o jogo, pelo rodapé da carta, e na tela de final. É o resumo da história da partida.
- **Progresso:** o jogo salva a cada decisão em `koreader/settings/sindico_game.lua`, com a partida e os recordes. Ao reabrir, o botão Continuar retoma de onde parou.
- **Galeria:** os finais descobertos ficam guardados entre partidas, junto com os recordes.

## Formato das cartas

Os decks ficam em `data/decks/` como tabelas Lua puras, carregadas em ambiente isolado. `data/manifest.lua` lista os arquivos de cartas.

```lua
{
    id = "chickens_302",            -- único, snake_case, em inglês
    char = "neide",                 -- chave em data/characters.lua
    text = "O vizinho de cima está criando galinhas na varanda. Ou você resolve, ou eu resolvo.",
    left = {
        label = "Multar",           -- rótulo do botão
        result = "A multa chegou. As galinhas ficaram.",  -- aparece no topo da carta seguinte
        effects = { funds = 5, residents = -5 },           -- residents, funds, building, patience
        set = { "chicken_war" },                           -- flags a ligar (opcional)
        clear = { "x" },                                  -- flags a desligar (opcional)
        next = "another_card",                             -- carta seguinte imediata (opcional)
        schedule = { card = "egg_in_elevator", days = 60 }, -- consequência agendada (opcional)
        minutes = "Multou o criador de galinhas do 402.",  -- entra na ata (opcional)
        ending = "ending_id",                               -- encerra o jogo (opcional)
    },
    right = { label = "Conversar antes", result = "...", effects = { patience = -8 } },
    requires = {                    -- opcional
        flags = { "a" }, not_flags = { "b" },
        min = { funds = 70 }, max = { residents = 30 },
        day_min = 100, day_max = 500, mandate_min = 2,
    },
    weight = 1,                     -- chance relativa no sorteio (padrão 1)
    days = 12,                      -- dias que a decisão consome (padrão 12)
    chain = true,                   -- só aparece por next ou schedule, nunca no sorteio
    at_day = 360,                   -- carta obrigatória a partir desse dia do mandato
    once_ever = true,               -- só aparece uma vez em toda a partida
}
```

Uma carta aparece no máximo uma vez por mandato. A carta de eleição usa `resolve = "election"` nas duas escolhas.

**Limites de texto,** conferidos pelo validador: `text` até 240 caracteres, `label` até 22, `result` até 90, `minutes` até 80.

**Finais** (`data/endings.lua`):

```lua
{ id = "bankruptcy", trigger = "zero:funds", title = "...", text = "...", requires = { flags = {...}, not_flags = {...} } }
```

`trigger` é um de `zero:residents`, `zero:funds`, `zero:building`, `zero:patience`, `election_lost`, `all_mandates`, `no_cards`, ou nenhum (quando o final só é alcançado por `ending` numa escolha). Para o mesmo gatilho, vale o primeiro da lista cujos requisitos batem, então os específicos vêm antes do genérico.

## Interface

- Medidores no topo, com ícones em SVG no mesmo estilo (`assets/icons/`) e setas depois de cada decisão: uma seta para mudança pequena, duas para 10 pontos ou mais.
- Rótulos dos botões das cartas em maiúsculas iniciais, aplicadas na tela, com palavras curtas como "de" e "a" em minúsculas. Nos arquivos de cartas, os rótulos ficam como frase comum.
- Galeria, ata, como jogar e sobre usam a mesma tela de lista paginada, com cada item em sua própria caixa. Muda de página pelos botões ou deslizando o dedo.
- Na tela de título, a imagem do prédio se ajusta ao número de botões, então nada fica para fora.
- O jogo é sempre em retrato. Aberto em paisagem, ele gira a tela e restaura a rotação ao fechar; pedidos de rotação durante a partida são ignorados.

## Ferramentas

Todas rodam a partir da raiz do repositório.

Só com `luajit` (são as que rodam na CI):

- `luajit tools/validate.lua`: confere referências, limites de texto e alcançabilidade.
- `luajit tools/simulate.lua [partidas]`: joga milhares de partidas com escolhas aleatórias e mostra duração, finais e cartas nunca vistas.
- `luajit tests/engine_spec.lua`: testes do motor.

Com uma cópia do KOReader para desktop, indicada em `KOREADER_DIR` (a pasta que contém `luajit` e `reader.lua`; no Mac, `KOReader.app/Contents/koreader`):

- `tools/koreader/run_emulator.sh`: abre o KOReader numa janela de 600x800, com o plugin carregado. O jogo fica em Ferramentas. As configurações ficam em `.ko-home/`.
- `tools/koreader/check_all_sizes.sh`: mede todos os textos contra a tela, joga 40 partidas pela interface e confere a abertura em paisagem, em quatro tamanhos de tela. Rodar antes de cada versão.
- `tools/koreader/run_headless.sh <script.lua> [largura] [altura] [dpi]`: roda um script sem janela. Com `OUTPUT_DIR` definido, `tools/koreader/check_layout.lua` salva as telas em PNG ali.
- `OUTPUT_DIR=docs/screenshots tools/koreader/run_headless.sh tools/koreader/render_screens.lua`: atualiza as capturas de tela do README.

Outras:

- `python3 -I tools/make_art.py`: gera os retratos e o prédio em `assets/`. Precisa do Pillow. Este script guarda a arte como código de desenho, por isso fica sob a licença do conteúdo (`NOTICE`). Os ícones são SVG escritos à mão, em `assets/icons/`.
- `tools/package.sh`: gera `dist/sindico_game.koplugin.zip` e o `.sha256`, só com os arquivos que o jogo usa e os de licença.

O emulador não mostra o que é próprio do e-ink nem a velocidade do aparelho: a conferência final é num aparelho real.

## Como publicar uma versão

1. Atualizar `version` em `_meta.lua` e criar a seção da versão em `CHANGELOG.md`, no formato `## [1.2.3]`.
2. Rodar `tools/koreader/check_all_sizes.sh` e testar num aparelho.
3. Criar a tag `v1.2.3` e enviá-la. O workflow `release.yml` confere se a tag bate com o `_meta.lua`, roda as verificações e publica o zip e o checksum, com as notas do `CHANGELOG.md`.

## Conteúdo

266 cartas em 8 decks (`assembly`, `residents`, `repairs`, `money`, `front_desk`, `arcs`, `meters`, `veteran`), 18 personagens, 15 arcos com consequências agendadas e 25 finais. Retratos, ícones e o prédio são desenhados por código em `tools/make_art.py`.

Simulação com 5.000 partidas: um jogador aleatório dura cerca de 38 decisões (mediana) e raramente passa do primeiro mandato; um jogador que cuida dos medidores chega em geral ao 4º ou 5º mandato e vence todos em cerca de 11% das partidas. O final de `no_cards` é só rede de segurança e não aparece na prática.

## Cuidados ao escrever cartas

- Cartas `at_day` disparam em sequência depois que uma variante é usada, porque o motor só marca a carta específica. Variantes de uma mesma assembleia usam uma flag própria, ligada na prestação de contas e limpa na eleição.
- A fila de `schedule` é zerada na reeleição. Cartas que abrem arcos têm `day_max` e `once_ever` para o desfecho caber no mandato.
- `clear` roda antes de `resolve_election`. Para o final de derrota variar com uma flag, limpe a flag numa carta do mandato seguinte, não na eleição.
- Escolhas que levam a final especial têm efeitos ruins de propósito, senão o jogador cuidadoso as prefere.
