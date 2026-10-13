# Segunda opinião: Pong Arcade by Jair Lima

Revisão feita pelo Grok (DeepSeek Pro, via WSL, somente texto, com o código dentro do prompt) em 2026-10-13. A primeira tentativa falhou (a resposta estourou o limite de tokens do modelo); a segunda, com pedido mais enxuto (máx. 900 palavras), funcionou. Cada achado foi conferido contra o código. Estado atual: `pong.exe --selftest` com 48 verificações e 0 falhas, bot completo nos dois builds.

## Achados do Grok e veredito

| # | Achado | Veredito | Ação |
|---|--------|----------|------|
| A1 | Face da raquete direita (`XR = 75`) fica dentro das colunas da raquete (75 e 76): a bola some atrás dela na rebatida; a esquerda (`XL = 5`) fica livre | **Real** | `XR := 74.0`, saque na coluna da rede; teste de simetria |
| A2 | Zona de acerto vai 0,6 linha além da raquete | **Falso (0,1)**: o centro é ±2,0 e a zona ±2,1; o teste cobre as bordas | Nada |
| A3 | Rebatida perto da parede reflete de novo no mesmo tick | **Falso**: a rebatida seguida da parede é a física correta | Nada |
| A4 | Pausa na contagem do saque "perde" um tick de contagem | **Falso**: o bloco de pausa roda antes do decremento e `nNext` é refeito | Nada |
| A5 | Placar só aparece 1,1 s depois do ponto (a pausa vinha antes de atualizar) | **Real, menor** | Placar e `HudAll` antes da pausa, mensagem "PONTO" depois |
| A6 | `Inkey(nSec)` do fim do ponto engole ESC/P | Real, menor | Não aplicado (pausa de 1,1 s) |
| A7 | Fallback de teclado: jogador 2 congela e as duas teclas movem o jogador 1 | **Real** | Eventos separados (W/S = J1, setas = J2); no modo 1 jogador as duas movem o J1; passo 1,5 por evento |
| A8 | `s_nAsync` global: 8 falhas de qualquer tecla jogam os dois para o fallback | Real, baixo | Mantido (histerese de 8 eventos e religa sozinho) |
| B | Colisão de nomes com comandos do Harbour | **Nenhum** | Conferido também por mim (Wait já havia sido renomeada) |
| C | Balanceamento: velocidade 0,9 para 0,75, passo 0,05, máx 1,7, VY 0,85, IA mais rápida | Opinião sem teste | Aguardando o teste de jogabilidade do usuário |
| D1 | `DrawBall` redesenha a bola parada a cada tick (flicker na contagem) | **Real** | Não redesenha na mesma célula |
| D2 | Rede apaga um frame ao cruzar a coluna central | Falso: o mesmo critério de `DrawNet` já é usado | Nada |
| D3 | `wall` com prioridade 1 é descartado perto da rebatida | Plausível, aceitável | Mantido |
| E | Attract mode, iniciais do melhor rally, flash de cor, tom da rebatida por ponto de contato | Melhorias | **Tom da rebatida aplicado** (3 WAVs: centro grave, pontas agudas); o resto fica como ideia |

## O que o teste achou e nenhum revisor viu

1. **`Wait( 1.1 )` virou o comando `WAIT`** (espera uma tecla): o jogo parava depois do primeiro ponto. Achado só pelo modo bot e pelo `gdb` (pilha com `HB_FUN___WAIT`). O Grok, mesmo avisado, não viu: o código estava sintaticamente correto.
2. **A IA nunca errava** (erro de mira ±1,2 dentro da zona de acerto ±2,1): 300 de 300 pontos CPU x CPU não terminavam. Achado pela simulação do autoteste.
3. Statics sem valor inicial derrubavam o autoteste (`s_nHits++` em `NIL`).
4. Uma hora de diagnóstico foi gasta em pistas falsas (relógio do sistema, pipe do Windows Terminal, gravações de log, som, leitura de teclado) antes de achar o `WAIT`. Lição registrada no guia.

## Pendentes

- Ajustar balanceamento depois do teste do usuário (CPU difícil contra CPU fácil: 0 pontos em 7 partidas, ou seja, o "difícil" pode estar forte demais contra humano).
- ESC/P durante a pausa pós-ponto (baixa prioridade).
- Modo attract CPU x CPU no menu e iniciais para o melhor rally.
