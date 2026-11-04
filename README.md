# O Síndico

[Read this in English](README_en.md)

Você foi eleito síndico. Sentimos muito.

Jogo de decisões por cartas para o [KOReader](https://koreader.rocks), em português.

Você acaba de ser eleito síndico do Edifício Primavera, um prédio de 12 andares. Cada carta é um morador, funcionário ou fornecedor com um pedido, e você decide por uma de duas respostas. A galinha na varanda, o vazamento sem origem e a assembleia de quatro horas são todos problema seu.

Um jogo da [Beater Studios](https://beaterstudios.com/).

| Início | Carta | Final |
|---|---|---|
| ![Tela inicial com o prédio e o menu](docs/screenshots/title.png) | ![Carta do zelador com duas respostas e os quatro medidores](docs/screenshots/card.png) | ![Tela de final com o prédio rachado](docs/screenshots/ending.png) |

## Como é o jogo

- **Quatro medidores:** Moradores, Caixa, Prédio e Paciência. Se qualquer um chegar a 0, o jogo acaba, cada um com seu final.
- **Mandatos:** há prestação de contas no meio do mandato e eleição no fim. A cada reeleição, fica mais difícil. Vencer 5 mandatos leva ao final de síndico vitalício.
- **Memória:** suas decisões liberam cartas futuras e voltam a cobrar a conta meses depois.
- **Conteúdo:** 266 cartas, 18 personagens, 15 arcos e 24 finais para descobrir, guardados numa galeria.
- **Ata:** o registro das suas decisões marcantes, que resume a história de cada partida.
- **Sem internet:** funciona offline e não coleta dados. O progresso é salvo a cada decisão.

## Instalação

1. Baixe `sindico_game.koplugin.zip` na [última versão](https://github.com/beater-studios/sindico_game.koplugin/releases/latest).
2. Extraia em `koreader/plugins/`, de modo que exista o arquivo `koreader/plugins/sindico_game.koplugin/main.lua`.
3. Reinicie o KOReader. O jogo fica em Ferramentas, como **O Síndico**.

O progresso fica em `koreader/settings/sindico_game.lua`. Para desinstalar, apague a pasta do plugin e, se quiser, esse arquivo.

## Compatibilidade

- Testado com o KOReader 2026.07 num Kindle básico da 10ª geração (firmware 5.18.1).
- Layout conferido no emulador em 600x800, 758x1024, 1072x1448 e 1264x1680.
- Precisa de tela sensível ao toque.
- O jogo é sempre em retrato. Aberto em paisagem, ele gira a tela e restaura a rotação ao fechar.
- Os textos estão só em português por enquanto.

## Roadmap

- [ ] Tradução para inglês
- [ ] Tradução para espanhol

## Desenvolvimento

Com [LuaJIT](https://luajit.org) instalado, a partir da raiz do repositório:

```sh
luajit tools/validate.lua
luajit tests/engine_spec.lua
luajit tools/simulate.lua
```

O formato das cartas, as regras do motor, as demais ferramentas e o processo de publicação estão em [docs/design.md](docs/design.md). Ao propor cartas novas, rode o validador e siga os cuidados descritos lá. Contribuições entram sob as mesmas licenças do projeto.

## Licença

O projeto tem duas licenças. Os detalhes estão em [NOTICE](NOTICE).

- **Código:** [GPL-3.0](LICENSE), somente a versão 3. Você pode usar, estudar, modificar e redistribuir, mantendo o código aberto sob a mesma licença.
- **Conteúdo:** [CC BY-NC-SA 4.0](LICENSE-CONTENT) para cartas, personagens, história e arte (`data/`, `assets/`, `docs/screenshots/`, `docs/social-preview.png` e `tools/make_art.py`). Você pode compartilhar e adaptar, com crédito e a mesma licença, sem uso comercial.

As licenças não dão direito de uso sobre os nomes "O Síndico" e "Beater Studios". Para outros usos, fale com a [Beater Studios](https://beaterstudios.com/).
