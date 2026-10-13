# Pong Arcade by Jair Lima

Pong em modo texto (terminal), Harbour 3.0.0 + GTWIN, terceiro jogo da série de fliperama ASCII (Snake, Space Invaders, Pong).

## Stack e dependências

- Harbour 3.0.0 (Rev. 16951) em `C:\hb30\bin`, GT `-gtwin` (jogo) e `-gtnul` (variante de teste), `hbwin.hbc` (`wapi_PlaySound`)
- Bloco C embutido (`#pragma BEGINDUMP`): `TIMERRES`, `SLEEPMS`, `TICKMS` (QueryPerformanceCounter), `KEYRAW`, `KEYFOCUS`, `CONSOLEQUIET`
- Sem dependências externas; WAVs sintetizados em `%TEMP%\pong_*.wav` a cada execução

## Estrutura

```
pong.prg       - todo o jogo (menu, partida, física, IA, desenho, recordes, som, C embutido, autoteste, bot)
pong.hbp       - jogo (GT win) -> pong.exe
pongbot.hbp    - variante de teste (GT nulo) -> pong_bot.exe, so para --bot
build.bat      - compila pong.exe
pong.sco       - melhor rally (criado ao lado do .exe)
REVIEW.md / BEST_PRACTICES.md - segunda opinião e guia de reuso
```

## Comandos

```
build.bat                       REM compila pong.exe
pong.exe                        REM joga (menu: 1 jogador, 2 jogadores, dificuldade, som)
pong.exe --play1 | --play2      REM pula o menu (depuração)
pong.exe --selftest             REM 48 verificações, grava pong_selftest.log, código de saída 0/1
pong_bot.exe --bot              REM CPU fácil x CPU difícil, sem console, ~90 s (pong_bot.log)
pong.exe --bot                  REM o mesmo, desenhando no console real (prova o desenho)
```

Se o jogo cair: ler `pong_crash.log` ao lado do `.exe`.

## Decisões arquiteturais

- Física em colunas por tick com `float`: `StepBall()` faz varredura de cruzamento da face da raquete (sem tunelamento até a velocidade máxima de 2,0), refletindo `y` com `ReflectY` (onda triangular).
- Ângulo de saída = deslocamento do contato (-1 a +1) x velocidade x 0,65; a velocidade sobe 0,07 por rebatida até 2,0.
- IA em 3 níveis (`AiStep`): prevê o ponto de chegada com `PredictY` (com quicadas), soma erro de mira sorteado a cada rebatida do adversário. O erro máximo é MAIOR que a zona de acerto (±2,1 linhas), senão a IA nunca erra e o ponto não termina (descoberto pela simulação do autoteste).
- Dois jogadores simultâneos: `GetAsyncKeyState` (W/S e setas); vale com foco do console OU evento de teclado há menos de 2,5 s (foco não é identificável no Windows Terminal). Sem isso cai para eventos de `Inkey` (W/S = jogador 1, setas = jogador 2, mas sem teclas simultâneas).
- Tick de 25 ms por relógio monotônico (`TickMs`) + `Sleep` nativo + `timeBeginPeriod(1)`.
- Som com prioridade e duração (canal único), efeito de menor prioridade descartado.
- Bot sem console (`-gtnul`): o fluxo real roda sem depender de terminal.

## Estado atual (2026-10-13)

Compila sem avisos, autoteste 48/48, bot completa partidas nos dois builds. Aguarda teste de jogabilidade do usuário (sensação de velocidade, dificuldade da CPU, dois jogadores no mesmo teclado, sons).

## Próximos passos

- Teste do usuário; ajustar velocidade, ganho por rebatida e erro da IA
- Revisão do Grok aplicada (ver REVIEW.md)
- Próximo jogo da série: Tetris

## Problemas conhecidos

- No modo de reserva por eventos (auto-repeat do teclado) os dois jogadores funcionam, mas nao ao mesmo tempo com fluidez; o modo direto e o recomendado.
- `pong.exe --bot` dentro de terminal automatizado pode congelar se a janela não é consumida; usar `pong_bot.exe` (GT nulo).
