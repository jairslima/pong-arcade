# Boas práticas: jogos ASCII em Harbour/Clipper

Notas reutilizáveis para novos jogos ASCII (Snake, Space Invaders, Pong, Tetris e Arkanoid já seguem este guia), considerando Harbour 3.0.0 em console Windows com GTWIN.

## 1. Estrutura do código

- Separe estado do jogo, regras da simulação, entrada, desenho, áudio e armazenamento. Uma regra como colisão ou pontuação deve poder ser testada sem abrir tela, tocar som ou gravar arquivo.
- Prefira funções pequenas, parâmetros explícitos e regras puras para movimento, colisão, spawn e pontuação. Reserve efeitos colaterais para as camadas de I/O.
- Defina constantes para dimensões, limites, tick e regras. Centralize regras repetidas, como concessão de vida extra.
- Em Harbour, documente os índices de arrays que representam estado ou use acessores nomeados. Evite que vários procedimentos alterem o mesmo estado global sem uma razão clara.
- Mantenha fonte ASCII quando o build depende de console OEM antigo. Comentários e nomes também podem ser ASCII para evitar dependência desnecessária da codepage.

## 2. Loop de jogo por tick e relógio

- O tick é definido pelas regras, não pela chegada de teclas. Leia a entrada em intervalos curtos e avance a simulação somente quando vencer o prazo do próximo tick. Assim, uma tecla não acelera o personagem.
- Em cada tick, consuma a entrada pendente, atualize o estado, resolva colisões e pontuação, atualize temporizadores e, por fim, desenhe as diferenças.
- Defina como lidar com atrasos. Para jogos simples, avançar um passo e agendar o próximo tick a partir do instante atual evita uma série longa de passos de recuperação. Para simulação determinista, use acumulador de tempo e limite de passos por frame.
- **[testado em Harbour 3.0.0]** `hb_MilliSeconds()` é absoluto (inclui a data, ~2.1e14) e NÃO reinicia à meia-noite: o padrão `nNext := hb_MilliSeconds() + nDelay` com `DO WHILE hb_MilliSeconds() < nNext` é seguro. Já `Seconds()` (segundos desde 00:00) reinicia, então não use `Seconds()` para prazos. A primeira revisão do Copilot afirmou o contrário sem testar.
- Durações de bônus e power-ups em milissegundos reais convertidos para ticks (`ms / nDelay`), nunca um número fixo de ticks, que encurta nas fases rápidas.
- A pausa deve suspender tanto a simulação como os temporizadores de jogo, a menos que a regra diga o contrário. Ao voltar, redefina o prazo do próximo tick para que a pausa não seja interpretada como atraso.
- Meça a velocidade com relógio, não com o número de iterações do loop de renderização. Aplique um limite que preserve legibilidade e capacidade de resposta do console.

## 3. Entrada e fila de teclas

- Use `Inkey()` para polling curto e `K_*` de `inkey.ch` para teclas especiais. Teste a combinação no GT efetivamente usado: códigos de setas, repetição do teclado e sequências de ESC podem variar com o terminal.
- Separe comandos de controle, como pausa e saída, das direções que afetam o próximo tick. Não deixe comandos da tela de abertura ou do nome de recorde vazarem para a primeira jogada; limpe a fila somente em transições intencionais.
- Em jogos de movimento, uma fila pequena permite registrar uma curva antes do próximo passo. Elimine repetições e rejeite reversões comparando com a direção final pendente, não somente com a direção atual.
- Defina o comportamento quando a fila está cheia. Descarte repetições antes de lotá-la e prefira a entrada de direção válida mais recente em vez de ignorar curvas sem indicação.
- Teste sequências rápidas, duas curvas pendentes, reversão, pausa e ESC cancelado ou confirmado.

## 4. Desenho incremental e flicker

- Desenhe a moldura e o fundo uma vez. Guarde o estado visual anterior e redesenhe somente células alteradas: posição anterior e atual de cada entidade, comida, projéteis e campos do HUD que mudaram.
- Para jogos com muitas células, mantenha um buffer lógico do tabuleiro e compare-o com o buffer anterior. Agrupe escritas de células contíguas em vez de emitir uma chamada por caractere.
- Ao limpar uma célula, desenhe um espaço com a cor de fundo correta. Desenho parcial sem apagar o estado anterior deixa rastros; redesenhar a tela toda a cada tick causa flicker e saída excessiva.
- Evite reescrever o HUD constante a cada tick. Atualize score quando pontuar, vidas quando mudarem e relógio ou bônus somente quando o valor visível mudar.
- Meça no terminal alvo. Uma chamada de saída para cada segmento pode parecer suave no console local e cintilar sobre sessão remota ou terminal lento.
- Valide as dimensões antes de iniciar. Considere os índices de `MaxRow()`/`MaxCol()` e reserve espaço para borda, HUD, mensagens e cursor.

## 5. GT, glifos e codepage

- Escolha o GT no projeto e teste no mesmo tipo de console usado pelo jogador. Este projeto seleciona GTWIN com `-gtwin`; não assuma que posicionamento, cores ou entrada se comportam igual em outro GT.
- Use `hb_DispOutAt()` para posicionamento, evitando misturar rotinas de saída que alterem cursor e atributos sem previsibilidade.
- `Chr()` em bytes de blocos e moldura só funciona como esperado quando GT, fonte e codepage estão alinhados. `Chr(219)` em codepage OEM não é o mesmo que um glifo Unicode independente do ambiente.
- Documente a dimensão mínima, a fonte e a codepage suportadas. Ofereça caracteres ASCII simples como alternativa de diagnóstico.
- A grade lógica pode ter largura diferente da grade de caracteres. Se cada célula do jogo ocupar duas colunas do terminal para aproximar proporções, centralize essa conversão nos helpers de desenho e teste todas as bordas.

## 6. Som assíncrono e WAV

- Gere ou disponibilize os sons antes de tocar, verifique erros de escrita e valide cabeçalho e tamanho dos arquivos. Não presuma que uma chamada aceita pelo compilador garante um dispositivo de áudio ou um WAV válido.
- `wapi_PlaySound()` é a interface usada por este projeto. O teste local traduziu uma chamada com `hbwin.hbc` configurado, mas não verificou a vinculação do executável, a reprodução ou o comportamento do dispositivo.
- Com `SND_ASYNC`, a reprodução não deve bloquear o loop, mas o modelo usual de `PlaySound` usa um canal: tocar um efeito novo pode interromper o anterior. Projete efeitos curtos e priorizados; não planeje música e efeitos simultâneos como se fossem mixados.
- Um canal pode ser suficiente para efeitos de arcade. Para música de fundo e efeitos independentes, use um mecanismo com mixagem de canais e teste-o separadamente.
- Evite gerar todos os WAVs em cada inicialização se forem idênticos. Crie-os sob demanda, mantenha arquivos temporários com nome de execução, trate uma pasta temporária indisponível e remova somente arquivos criados pelo próprio jogo.
- Não use o diretório atual como fallback silencioso. Uma aplicação iniciada por atalho, menu ou pasta protegida pode ter diretório corrente inesperado ou sem permissão.

## 7. Spawn, colisão, bônus e dificuldade

- Para spawn, enumere células ou posições válidas e escolha uma delas. Repetir sorteios um número fixo de vezes e retornar uma posição inventada não é um fallback correto quando o mapa está cheio.
- Defina explicitamente se entrar na posição da cauda é permitido. Em Snake, só é permitido quando a cauda realmente sai nesse tick; com crescimento pendente, ela permanece e a colisão deve contar.
- Resolva colisão com base no estado que existirá após o movimento, não na ordem visual do desenho. Teste parede, obstáculo, corpo, cauda e crescimento em casos deterministas.
- Valide que obstáculos não ocupem a posição inicial, comida ou bônus e que o mapa continue jogável. Se um spawn aleatório falhar, regenere com limite e mapa seguro de reserva.
- Meça a curva de dificuldade em movimentos por segundo e tempo real. Se a duração do bônus for baseada em ticks, ela muda com a velocidade; use tempo real se a regra for em segundos, ou explicite que dura uma quantidade fixa de movimentos.
- Centralize a tabela de pontuação e os marcos de vida. Trate múltiplos limites cruzados num único prêmio e respeite o limite de vidas sem deixar marcos pendentes acumularem.
- Defina teto e formato para score, nível, vidas e bônus. Os campos de tela e o arquivo de recordes precisam suportar o mesmo intervalo que o motor permite.

## 8. Recordes confiáveis

- Prefira armazenamento por usuário em local gravável; a pasta do executável não é necessariamente gravável. O caminho-base do executável é conveniente para uma versão portátil, mas deve ser tratado como opção, não como promessa.
- Verifique leitura e escrita e comunique falhas sem apagar o placar em memória. Valide cada linha: iniciais, separador, número, intervalo e quantidade máxima.
- Preserve entradas válidas de arquivos incompletos, ordene antes de exibir e defina uma regra para empates.
- Para reduzir o risco de arquivo truncado, escreva uma cópia temporária, verifique o sucesso e substitua o arquivo anterior somente depois. Mantenha backup ou recuperação simples se o formato for importante.
- Teste arquivo ausente, vazio, parcial, malformado, com pontuações negativas ou altas e pasta sem permissão.

## 9. Autoteste sem UI

- Mantenha a lógica do motor independente de GT e áudio para executar testes sem janela de jogo, entrada humana ou dispositivo de som.
- Torne spawn e mapas deterministas no autoteste. Teste limites e casos extremos, não apenas repita mapas aleatórios e confira se um resultado parece razoável.
- Cubra fila de teclas cheia, colisão com a cauda, tabuleiro cheio, expiração e coleta do bônus, limite de vidas, empate de recorde e erro de gravação.
- Valide os WAVs com bytes do cabeçalho, canais, frequência, profundidade e tamanho esperado. A existência do arquivo só prova que um caminho foi criado, não que os dados estejam corretos.
- O comando `--selftest` deve terminar com código de falha quando uma verificação falhar e não deve depender de som. Um teste de áudio separado pode criar ou tocar WAV quando solicitado explicitamente.
- Não chame inicializadores caros antes de reconhecer o modo de teste. Separar argumentos, testes de lógica e testes de hardware reduz falsos negativos e acelera a iteração.

## 10. Build e distribuição

- Mantenha as opções de plataforma no `.hbp`: GT, warnings, bibliotecas como `hbwin.hbc` e fontes do programa. Reproduza o build com o mesmo Harbour e toolchain usados para publicar.
- Execute `hbmk2` com caminho e projeto conhecidos e confira o código de saída. Não confunda tradução de PRG para C com vinculação do executável e teste no console.
- Valide em máquina e terminal limpos: executável, runtime ou distribuição Harbour necessária, permissão de `%TEMP%`, codepage e áudio. Separe falha do motor de falha do dispositivo.
- Guarde autotestes reproduzíveis e execute build/testes após alterar interfaces Harbour, flags do GT ou dependências. Mudança de GT é mudança de plataforma, não apenas ajuste visual.
- Antes de publicar, teste tabuleiro mínimo, teclado, pausa, saída, WAV ausente, diretório sem permissão e arquivo de recordes corrompido.

## Armadilhas observadas neste Snake

- (Descartada) A suspeita de que `hb_MilliSeconds()` falha à meia-noite era falsa, refutada por teste compilado.
- `NewFood()` retorna `{ 0, 0 }` após esgotar tentativas; a comida pode aparecer sobre cobra ou obstáculo.
- A fila de duas direções aceita duplicatas e a fila cheia descarta curvas.
- Bônus de 70 ticks dura menos segundos nas fases rápidas e perde um tick na criação.
- A vida extra usa um `IF` por evento, tem código duplicado e tratamento sonoro inconsistente.
- O autoteste atual verifica spawn básico e faixa segura, mas não testa as regras centrais de colisão e pontuação.
- O HUD usa larguras mínimas, mas score e nível não têm limite máximo.
- O recorde fica ao lado do executável e falhas de gravação não são reportadas.
- Os WAVs são gerados em toda inicialização, inclusive antes de selecionar `--selftest`, e as gravações não são verificadas.
- Glifos `Chr()` dependem da codepage OEM e da fonte em uso.

## Processo de revisão (aprendido na revisão do Snake)

- Peça a segunda opinião a outro agente (Codex, Copilot, agy) com a instrução "valide qualquer afirmação sobre API compilando um teste".
- Mesmo assim, confira cada achado: um deles (rollover de `hb_MilliSeconds()`) era falso e um teste de 5 linhas o refutou.
- Se o agente estiver sem cota (o Codex bateu o limite em 2026-10-08), troque de agente na hora e avise.
- Releia o arquivo gerado antes de sobrescrevê-lo: o agente pode continuar editando depois de o processo parecer concluído.

## Lições do Space Invaders (2026-10-08)

Itens medidos ou verificados em Harbour 3.0.0 no Windows 11.

### Tempo e tick
- **[testado]** `hb_idleSleep( 0.002 )` NÃO dorme 2 ms: 50 chamadas levaram 1548 ms (~31 ms cada). Mesmo com `timeBeginPeriod(1)` ainda levou ~21 ms por chamada, porque `hb_idleSleep` dorme em passos grandes. `Inkey( 0.01 )` sofre do mesmo mal.
- **Solução** (função C embutida, `#pragma BEGINDUMP`): `timeBeginPeriod(1)` na partida e `Sleep()` nativo no laço de espera. **[testado]** 30 chamadas de `SleepMs( 2 )` levaram 88 ms (~3 ms cada).
- O autoteste mede isso (`TimerRes(1) + Sleep nativo`) e falha se a resolução voltar a ser grosseira.
- O Snake ainda usa `Inkey( 0.01 )` na espera do tick; funciona porque o tick dele é lento (40 a 140 ms), mas em jogos com tick de 30 ms use o `Sleep` nativo.

### Teclado: andar e atirar ao mesmo tempo
- O console não informa "tecla solta". Com eventos de `Inkey`, segurar uma seta e apertar espaço faz o auto-repeat trocar de tecla.
- **[testado]** `hbwin` do Harbour 3.0.0 NÃO tem `wapi_GetAsyncKeyState`, `wapi_GetForegroundWindow`, `wapi_GetConsoleWindow` nem `DllCall` (erro de link). Solução: função C embutida `KEYDOWN( nVk )` com `GetAsyncKeyState`, `GetConsoleWindow`, `GetForegroundWindow` e `GetAncestor( hCon, GA_ROOTOWNER )` (cobre conhost e Windows Terminal) e só vale com a janela em foco.
- Sempre com fallback: cada evento de seta do `Inkey` é comparado com `KeyDown`. Se a tecla aparece pressionada, liga o modo direto; só volta ao fallback após 8 eventos seguidos sem nenhum visto como pressionado (toques rápidos não desligam o modo). Toque já solto no instante da leitura ainda move 1 célula.
- Incluir `#include <mmsystem.h>` no bloco C para `timeBeginPeriod`; o `winmm` já é linkado pelo hbmk2.

### Colisões com vários objetos
- Checar colisão a cada tick para todo par que se move em velocidades diferentes. Bomba andando a cada 3 ticks e tiro a cada tick: checar só quando a bomba anda deixa o tiro atravessar a bomba. O autoteste varre as 3 defasagens possíveis.
- Se o objeto nasce dentro de outro (tiro nasce na célula de um invasor), checar a colisão já no nascimento.
- Rechecar tiro x invasor depois que a formação anda (o invasor pode descer para a célula do tiro).
- Ao redesenhar uma célula depois de um acerto, não apagá-la de novo: o tratamento do acerto já redesenhou.
- Ordem de desenho de elementos sobrepostos: limpar o que será destruído, desenhar a formação, redesenhar os sobreviventes (bunkers).

### Som com prioridade (canal único)
- Cada efeito tem prioridade e duração (tabela `s_hDur` preenchida na geração do WAV). Efeito de prioridade igual ou maior substitui o que toca; de prioridade menor é DESCARTADO, não enfileirado.
- Ordem usada: marcha 1, tiro/bunker/UFO 2, acerto no invasor 3, acerto no UFO 4, morte/onda/fim de jogo 5.
- Efeito em laço (warble do UFO) deve repetir antes do fim do WAV, senão há silêncio entre as repetições.
- Ruído (explosões): onda quadrada com valor aleatório mantido por N amostras, N derivado da "frequência".

### Dificuldade
- Aceleração da formação limitada: piso de 2 ticks por passo (22x entre 55 invasores e 1). Sem piso, o último invasor fica impossível de acertar.
- Teto de chance de bomba por tick (8%) e intervalo mínimo de movimento da bomba (2 ticks), senão as ondas altas viram parede.
- Prêmio máximo do UFO raro (1 em 8).
- HUD: contar as colunas do pior caso (5 vidas de 3 colunas + espaço = 19 colunas).

### Processo de revisão com o Grok (texto apenas)
- Passar o código dentro do prompt (arquivo lido com `$(cat ...)`) e pedir "responda somente em texto, não use ferramentas" dispensa `--always-approve`: o Grok devolve a revisão e não toca nos arquivos. 40 KB de prompt funcionou.
- O Grok errou em 2 pontos que o build refutou (disse que `L2Bin`/`I2Bin`/`Bin2L` não estavam definidas, e que `hb_keyClear()` rodava a cada laço). Por outro lado, achou 6 bugs reais. Conferir tudo, como sempre.
- A lista "NAO VERIFICADO" do Grok é útil: vários itens foram fechados por teste (`hb_RandomInt( a, b )` inclusivo nas duas pontas, `hb_DirBase()` com separador final, `hb_MemoWrit` binário, `hb_ADel`/`hb_AIns` com `.T.`), e o teste dos tempos achou o problema do `hb_idleSleep` que nenhum revisor viu.

### O bug que o autoteste não pegou: `%` + `hb_ntos` (2026-10-09)

O Space Invaders foi entregue com autoteste verde e **fechou sozinho depois do ENTER**. Causa: em Harbour, `s_nMarch % 4 + 1` devolve um número com casas decimais, e `hb_ntos( 2.00 )` vira `"2.00"`. O nome do efeito virou `march2.00`, que não existe na tabela de durações, e o acesso à tabela deu *Bound error* na segunda passada da marcha.

- **Regra:** sempre `Int( a % b )` quando o resultado vira texto (`hb_ntos`, `Str`, chave de hash, nome de arquivo). Comparações e índices de array toleram o decimal, texto não.
- **Regra:** nome montado em tempo de execução (`"march" + n`) precisa de teste que percorra todos os valores possíveis e confira que cada nome existe (teste `NextMarch gera march1..4 em ciclo, todos com WAV`).
- **Regra:** funções de utilidade que consultam tabela (`PlaySfx`) devem ignorar nome inexistente em vez de derrubar o jogo.
- **Falha de processo:** o autoteste cobria só as regras puras. O fluxo real (abertura, ENTER, laço do jogo, sons) nunca tinha rodado. **Nunca declarar "pronto" sem exercitar o fluxo real.**

### Como diagnosticar crash em app GTWIN

- O erro de execução do Harbour é escrito no console e a janela fecha em seguida: não aparece em stderr/stdout redirecionado nem fica visível.
- Instalar um `ErrorBlock` que grava `invaders_crash.log` (descrição, operação, subsistema e pilha com `ProcName`/`ProcLine`) e dá `QUIT`. Com isso o crash do ENTER foi achado em uma execução (`Bound error / array access / PLAYSFX / PLAYGAME`).
- Argumento `--play` (pula a abertura) acelera reproduzir.

### Modo bot: teste de fluxo real sem humano

- `--bot`: o jogo joga sozinho (mira na coluna viva mais próxima, atira sempre), tick acelerado (3 ms), invulnerável e com a formação 4x mais lenta, para limpar ondas. Grava `invaders_bot.log` com ticks, ondas limpas, pontos, vidas e o perfil de tempo por seção. Resultado: 5 ondas limpas em 107 s sem erro.
- `--botdie`: sem invulnerabilidade, até o game over (cobre morte, perda de vidas, tela de fim e a saída).
- O bot passa por abertura de onda, marcha, tiro, bombas, bunkers, UFO, vidas extras, morte e game over. Só o teclado real e a leitura de `KeyDown` ficam para o teste humano.
- Perfil: acumular `hb_MilliSeconds()` por seção do tick (entrada, nave, tiro, formação, bombas, UFO/efeitos/HUD, espera). Medido: ~3 a 8 ms por tick de processamento, bem abaixo dos 30 ms do tick normal; a seção mais cara é "bombas" (varredura de bunkers e redesenho).
- Cuidado ao interpretar o bot: a partida pode acabar por pouso dos invasores (bot lento), não por falha. Conferir sempre o motivo do fim.

## Lições do Pong (2026-10-13)

### Nunca dar a uma função o nome de um comando do Clipper/Harbour

- `STATIC PROCEDURE Wait( nSec )` compila sem erro, mas a chamada `Wait( 1.1 )` é reescrita pelo pré-processador no comando `WAIT` (`__Wait`), que mostra a mensagem e **espera uma tecla**. O jogo ficava parado depois do primeiro ponto. Pelo `gdb` a pilha mostrava `HB_FUN___WAIT` ← `HB_FUN_INKEY` ← `hb_idleState`.
- Evitar como nome de função, procedimento ou variável: `Wait`, `Accept`, `Input`, `Clear`, `Quit`, `Set`, `Release`, `Store`, `Count`, `Sort`, `Total`, `Keyboard`, `Replace`, `Erase`, `Copy`, `Delete`, `Zap`, `Pack`, `List`, `Display`, `Say`, `Get`, `Read`, `Public`, `Private`, `Seek`, `Skip`, `Go`, `Use`, `Index`, `Append`, `Locate`, `Continue`, `Return`, `Cancel`, `Close`. Use prefixos de domínio: `PauseSec`, `GameQuit`, `ShowMenu`.
- Dica de diagnóstico: se um jogo "trava" e a thread principal está em `Inkey` ou `hb_idleState`, procure no código uma função com nome de comando.

### Como achar a causa de um processo congelado (técnica que funcionou)

1. Confirmar o estado das threads (`Get-Process -Id N | Select Threads`): `Ready` repetido = a thread acorda de um `Sleep` em laço, não está presa em E/S.
2. `gdb.exe -q -batch -p PID -ex "thread 1" -ex "x/160a $esp"` (o `gdb` fica em `C:\hb30\comp\mingw\bin`). A pilha de memória mostra os retornos com os nomes das funções internas do Harbour (`hb_inkey`, `HB_FUN___WAIT`) mesmo sem símbolos do PRG.
3. Desconfiar dos nomes do `gdb` quando o executável não tem símbolos: ele atribui o endereço ao símbolo vizinho (aqui "ReadKey" era outra coisa).
4. Descartar hipóteses medindo, não supondo: foram testadas e refutadas relógio do sistema, pipe do Windows Terminal, gravação de logs, som e leitura de teclado antes de achar o `WAIT`.

### Rodar o bot sem console

- O bot (`--bot`) joga CPU x CPU sem teclado e sem desenho. Compilar uma variante `pongbot.hbp` com `-gtnul` (GT nulo): nenhuma saída de console, nada para travar em terminal automatizado, e é a forma correta de testar o fluxo real em CI.
- O mesmo código rodou também no console real (`pong.exe --bot`) para provar o desenho.

### Simulação revela IA que nunca erra

- A simulação CPU x CPU do autoteste mostrou 300 de 300 pontos sem fim: o erro de mira da IA era menor que a zona de acerto da raquete (±2,1 linhas), então a IA nunca errava. Regra: erro máximo da IA **maior** que a zona de acerto, e testar com simulação que todo ponto termina. Chance de erro: fácil ~42%, normal ~19%, difícil ~9%.

### Relógio de tick

- Usar relógio monotônico (`QueryPerformanceCounter` via função C `TICKMS`) para o pacing; `hb_MilliSeconds()` vem do relógio do sistema e pode saltar.
- Teste de tempo no autoteste: medir 3 vezes e usar a melhor (uma amostra varia com a carga do computador, 85 ms a 233 ms para o mesmo teste).

### Estado e testes

- Todo `STATIC` de estado deve ter valor inicial na declaração: o autoteste chama regras direto, sem passar pelo início da partida, e `s_nHits++` em `NIL` derrubou o teste.
- Console "quieto" (`ConsoleQuiet`): desligar mouse, eventos de janela e QuickEdit (clique no console congela toda a saída) no início do jogo.

### Fluxo de revisão (3º jogo)

- Tempo gasto: o `Wait` custou mais de uma hora de diagnóstico porque os sintomas pareciam de ambiente. Se um jogo "congela" só no bot, **olhar primeiro o código do fluxo** (nomes, comandos, esperas) antes do ambiente.

## Lições do Tetris (2026-10-13)

### Música em paralelo aos efeitos (MCI)

- O `PlaySound` tem canal único: efeito novo corta o anterior, e música junto com efeitos não é possível. A saída é tocar a música pelo **MCI** (`mciSendStringA`, função C embutida `MCSEND`) e deixar os efeitos no `PlaySound`: **[testado]** os dois tocam ao mesmo tempo (o autoteste abre e toca o WAV real, `open=0 play=0`).
- Comandos usados: `open "arq.wav" type waveaudio alias bgm`, `setaudio bgm volume to 350`, `play bgm`, `pause bgm`, `resume bgm`, `stop bgm`, `close bgm`, `play bgm from 0`, `status bgm mode`.
- `waveaudio` **não tem `repeat`**: um laço confere `status bgm mode` a cada 1 s e reinicia com `play bgm from 0` quando volta `stopped`.
- **Bug clássico de estado:** pausar a música no game over e, ao voltar ao menu, `StartMusic()` retornar cedo ("já está ligada") deixa a música pausada para sempre. Quem liga deve também retomar. Testar com o MCI real: `paused` vira `playing` (teste `StartMusic retoma a musica que ficou pausada`).
- Sem dispositivo de áudio o `open` falha e a música simplesmente não toca; o teste registra `info` em vez de falhar.
- Música de 12 s, 8 bits, 11025 Hz: gerar nota por nota em blocos (`cNote += Chr()` e depois `cData += cNote`) para não copiar a string inteira a cada amostra, e **gerar uma vez e reaproveitar o arquivo** (`tet_bgm.wav`). Música sempre **desligada por padrão**, ligada pelo menu ou por uma tecla.

### Rotação SRS e peças

- 4 rotações por peça em caixa 4x4 descritas como strings de 16 caracteres (`"X"` ocupa); cada peça fica auditável a olho. O teste confere 28 formas, 4 células cada, dentro da caixa.
- Tabelas de wall kick SRS em hash por `"deparaX"` (`"01"`, `"12"`...). A tabela original tem **y para cima**; com y para baixo o sinal de y é invertido na aplicação (`s_nPy - k[2]`).
- Teste forte: todas as rotações, de todas as peças, em todas as posições válidas, nunca terminam em colisão (mais de 1000 rotações no teste).
- **7-bag**: embaralhar `{1..7}` (Fisher-Yates) e consumir com `hb_ADel( aBag, 1, .T. )`; teste de 50 sacos com as 7 peças cada.
- Remoção de linhas: `hb_ADel( aBoard, nLinha, .T. )` e `hb_AIns( aBoard, 1, linhaVazia, .T. )` em ordem crescente mantém os índices corretos e o tamanho do tabuleiro.

### Entrada: o mesmo toque não pode contar duas vezes

- Com teclado direto (`GetAsyncKeyState`) **e** eventos do `Inkey` ativos ao mesmo tempo, cada giro contava em dobro. No modo direto, descartar as ações vindas dos eventos (`ClearActions()`); no fallback por eventos, usar só os eventos.
- DAS/ARR próprios (repetição lateral): atraso inicial 160 ms e intervalo 40 ms contados pelo relógio do jogo, não pelo auto-repeat do Windows.
- Giros, queda instantânea e reserva por **borda de subida** (compara com o estado do tick anterior).
- Travamento: peça apoiada trava após 500 ms; mover/girar adia até 12 vezes; queda instantânea trava na hora.

### IA do bot

- Heurística clássica: `-0.51 x altura agregada + 0.76 x linhas - 0.36 x buracos - 0.18 x irregularidade`, avaliando todas as rotações e colunas em uma cópia do tabuleiro (`CloneBoard` clona linha a linha, `AClone` raso não basta).
- Dois bots: `--bot` (joga bem: 301 peças, 120 linhas, nível 13) e `--botdie` (joga mal: chega ao game over em ~19 peças). Juntos exercitam queda, travamento, linhas, nível, próxima peça, hold, game over e recordes (sem entrada de iniciais). Build `tetrisbot.hbp` com `-gtnul`.
- Se o bot depende de `hb_keyClear()`/`Inkey()` ou de `Banner` com `Inkey( n )`, trocar por versão que não bloqueia no modo bot (`KeyFlush`, `PauseSec`).

### Revisão antes de compilar

- Reler o código recém-escrito antes de compilar achou 5 defeitos reais (variável de estado não declarada, nome com prefixo `hb_`, entrada contada em dobro, logo do menu, expectativa errada em um teste). Vale como etapa fixa: **escrever, reler com olho de revisor, só então compilar**.
- Revisão externa (Grok, texto puro, máx. 900 palavras) sempre mistura achados reais e falsos: neste jogo 1 de 5 era real. Conferir cada um contra o código.

## Lições do Arkanoid (2026-10-13)

### Cores: no Harbour 3.0 as letras C, M e Y NÃO existem

- **[testado com `hb_ColorToN`]** `"C+/N"` vira 8 (cinza escuro), `"M+/N"` vira 8, `"Y+/N"` vira 8 e `"Y/N"` e `"C/N"` viram 0 (preto). Valem apenas `N B G R W` e as combinações `BG` (ciano), `RB` (magenta) e `GR` (amarelo/marrom), com `+` para brilhante: `BG+/N`, `RB+/N`, `GR+/N`.
- Foi um erro presente nos cinco jogos desde o Snake (79 ocorrências): o amarelo, o ciano e o magenta apareciam cinza ou invisíveis. Só foi notado quando o usuário mandou um **print** do Arkanoid: a fileira marrom dos tijolos sumia e a ciano aparecia cinza.
- **Regra:** só usar `N B G R W BG RB GR` (mais `U I X`) nas strings de cor. Cada autoteste agora tem a verificação `cores validas no fonte`: a função `ColorLint( arquivo )` lê o próprio `.prg`, acha toda string do formato `XXX/YYY` e reprova qualquer lado que não esteja na lista. Ela já pegou o próprio comentário que continha exemplos de cor inválida (aspas dentro de comentário contam): escrever exemplos sem aspas.
- Como conferir à mão: `hb_ColorToN( "BG+/N" )` deve dar 11 (ciano brilhante); se der 8 ou 0 a letra foi ignorada.

### Print do usuário é diagnóstico

- Ler os prints da pasta de capturas (a mais recente primeiro) antes de supor: no mesmo print apareceram a cola ativa (raquete verde e larga com a bola presa), o erro de cor e resíduos de desenho.
- Capturar também ajuda a validar cada correção depois: o que o autoteste e o bot não veem (cor, posição, rótulo cortado) só aparece na tela.

### Experiência de poderes (UX)

- Poder que muda as regras (cola que prende a bola a cada rebatida) precisa de **três coisas**: indicação visível com o tempo restante (painel `COLA 12s  GRANDE 9s  LASER 3s` na moldura de cima), cor própria da raquete (laser vermelho, cola verde) e **soltura automática** (a bola colada solta sozinha em ~1,75 s; espaço solta antes). Sem isso, o jogador acha que a bola "trava" e que é bug.
- Cor da raquete e posição são cacheadas para não redesenhar a cada tick: **a cor entra no cache** (senão o poder expira e a raquete continua verde).

### Física de bola com tijolos

- Bola em sub-passos (no máximo 0,5 coluna e 0,4 linha por sub-passo): testar o eixo X e depois o eixo Y separadamente e, por fim, a célula diagonal (desfaz e inverte os dois eixos). Teste: 72 posições e ângulos na velocidade máxima, sempre quebra tijolo.
- Anti-travamento: reescalar a bola para a velocidade global e impedir `|vy|` abaixo de 22% dela (nunca fica horizontal); depois de 1200 ticks sem quebrar tijolo, empurrar o ângulo.
- As colunas valem metade de uma linha: `vx` tem o dobro (`vx = 2 x v x sen(a)`, `vy = v x cos(a)`) para o ângulo parecer certo.
- Apagar a bola não pode estragar o que está na mesma célula (tijolo, raquete); apagar cápsulas em queda também restaura os tijolos que elas cobriam. Ao apagar na linha da raquete, forçar o redesenho dela.
- `Sin`, `Cos` e `Atan` NÃO são do núcleo do Harbour 3.0: linkar `hbct.hbc`.

### Simulação com o mesmo código do jogo

- O passo do mundo (`StepWorld`: poderes, saque, bolas, cápsulas, tiros, anti-travamento) é uma função só, usada pelo jogo e pela simulação do autoteste. Assim a simulação (IA joga as 5 fases em memória, 1,4 mil a 9,9 mil ticks cada) testa o código de verdade e achou, antes do teste humano, o deadlock da cola (a bola colada nunca soltava no bot).
- Todo desenho passa por uma função `Put()` que o autoteste desliga: nenhum desenho dentro das regras.
- Duplicar a lógica do jogo dentro do teste é a receita para o teste passar com o jogo quebrado.

### Revisão do Grok (Arkanoid)

- 5 de 6 achados de lógica eram reais (D com 2 bolas virava 4, cor da raquete não voltava ao normal, laser acima do limite, 5ª vida cortada no HUD, ordem fim de fase x perda de bola). O pedido enxuto (máx. 900 palavras) segue funcionando.
- Os falsos positivos continuam sendo "NAO VERIFICADO" sobre funções que o build já prova.
