# Pong Arcade by Jair Lima

Pong em modo texto, escrito em Harbour 3.0 (estilo Clipper), com a experiência de fliperama:

- 1 jogador contra a CPU (fácil, normal ou difícil) ou 2 jogadores no mesmo teclado
- A bola sai da raquete com ângulo conforme o ponto de contato e acelera a cada rebatida
- Placar grande em blocos, contagem 3-2-1 no saque, primeiro a 7 pontos, rally e melhor rally gravado
- Efeitos sonoros sintetizados na hora, com prioridade (canal único): rebatida, parede, contagem, ponto, vitória, derrota
- Autoteste sem interface (`pong.exe --selftest`, 48 verificações) e modo bot CPU x CPU (`pong_bot.exe --bot`)

## Controles

- 1 jogador: W/S ou setas
- 2 jogadores: jogador 1 com W/S, jogador 2 com as setas (leitura real das teclas, os dois ao mesmo tempo)
- `P` pausa, `M` liga/desliga o som, `ESC` sai. Terminal mínimo 80x25.

## Compilar

Requer Harbour 3.0.0 em `C:\hb30\bin`:

```
build.bat                       REM pong.exe (jogo, GT win)
hbmk2 pongbot.hbp               REM pong_bot.exe (teste, GT nulo, sem console)
```

## Documentação

- `PROJECT.md`: estado do projeto e decisões
- `REVIEW.md`: segunda opinião (Grok) conferida por testes
- `BEST_PRACTICES.md`: boas práticas para jogos ASCII em Harbour/Clipper (Snake, Space Invaders e Pong)

Licença MIT.
