/*
 * Pong Arcade by Jair Lima
 *
 * Pong em modo texto (Harbour 3.0 + GTWIN) no estilo fliperama: 1 jogador contra
 * a CPU (3 niveis) ou 2 jogadores no mesmo teclado, bola com angulo conforme o
 * ponto de contato na raquete, velocidade crescente a cada rebatida, placar
 * grande, rally e melhor rally gravado, efeitos sonoros sintetizados com
 * prioridade (canal unico).
 *
 * Teclado: estado real das teclas (GetAsyncKeyState via funcao C embutida) para
 * dois jogadores simultaneos; sem isso cai para eventos do Inkey (so 1 jogador).
 *
 * Testes sem humano: --selftest (regras), --bot (CPU x CPU acelerado, cobre o
 * fluxo real). Erro de execucao grava pong_crash.log ao lado do .exe.
 *
 * Fonte em ASCII puro: blocos/molduras via Chr() (codepage OEM).
 */

#include "inkey.ch"
#include "setcurs.ch"
#include "hbgtinfo.ch"

#define FL          2            // coluna inicial da quadra
#define FWID       76            // largura da quadra
#define FT          7            // primeira linha da quadra
#define FH         16            // altura da quadra (linhas FT .. FT+FH-1)
#define PH          4            // altura da raquete
#define XL        5.0            // face da raquete esquerda (ball.x <= XL = toque)
#define XR       74.0            // face da raquete direita (simetrica a XL: a bola nunca fica sob a raquete)
#define PL0         3            // colunas da raquete esquerda (3 e 4)
#define PR0        75            // colunas da raquete direita (75 e 76)
#define WIN_SCORE   7
#define TICK_MS    25
#define SPD0      0.9            // velocidade inicial da bola (colunas por tick)
#define SPD_STEP  0.07           // ganho por rebatida
#define SPD_MAX   2.0
#define VY_FACTOR 0.65           // vy maximo = fator * velocidade
#define PSPD      0.55           // velocidade da raquete humana (linhas por tick)
#define SND_FLAGS 131075         // SND_ASYNC + SND_FILENAME + SND_NODEFAULT
#define BEST_FILE "pong.sco"

#define VK_UP      38
#define VK_DOWN    40
#define VK_W       87
#define VK_S       83

#define BLK        Chr( 219 )
#define SHD        Chr( 178 )

STATIC s_cTmp
STATIC s_lSnd := .T.
STATIC s_hDur := { => }
STATIC s_nBusyUntil := 0
STATIC s_nBusyPrio := 0
STATIC s_nAsync := 1             // 1 teclado direto, -1 fallback por eventos
STATIC s_nMiss := 0
STATIC s_nLastKey := 0
STATIC s_nRallyDrawn := -1
STATIC s_cStage, s_nStageT := 0
STATIC s_hProf := { => }
STATIC s_nClkBase := 0          // diferenca inicial entre relogio do sistema e monotonico (diagnostico)
STATIC s_nTickMs := TICK_MS
STATIC s_lBot := .F.
STATIC s_nBotUntil := 0
STATIC s_aBotLog := { 0, 0, 0, 0, 0 }     // partidas, vitorias esq, vitorias dir, pontos, ticks

STATIC s_nBx := 0, s_nBy := 0, s_nVx := 0, s_nVy := 0, s_nSpd := 0     // bola
STATIC s_nP1 := 0, s_nP2 := 0                      // topo das raquetes (float)
STATIC s_nSc1 := 0, s_nSc2 := 0, s_nRally := 0, s_nBest := 0, s_nHits := 0
STATIC s_nPlayers := 1
STATIC s_nDiff := 2              // 1 facil, 2 normal, 3 dificil (CPU da direita no modo 1 jogador)
STATIC s_nDiffL := 2             // nivel da IA da esquerda (so modo bot)
STATIC s_nErr1 := 0, s_nErr2 := 0                  // erro de mira da IA em cada lado
STATIC s_nDrBr := -1, s_nDrBc := -1                // onde a bola esta desenhada
STATIC s_nDr1 := -1, s_nDr2 := -1                  // topo desenhado de cada raquete
STATIC s_nEvDy := 0, s_nEv1 := 0, s_nEv2 := 0
STATIC s_lReqPause := .F., s_lReqQuit := .F.
STATIC s_cModeShown := ""

STATIC s_aFont := { ;
   { "###", "# #", "# #", "# #", "###" }, ;
   { " # ", "## ", " # ", " # ", "###" }, ;
   { "###", "  #", "###", "#  ", "###" }, ;
   { "###", "  #", "###", "  #", "###" }, ;
   { "# #", "# #", "###", "  #", "  #" }, ;
   { "###", "#  ", "###", "  #", "###" }, ;
   { "###", "#  ", "###", "# #", "###" }, ;
   { "###", "  #", "  #", "  #", "  #" }, ;
   { "###", "# #", "###", "# #", "###" }, ;
   { "###", "# #", "###", "  #", "###" } }

PROCEDURE Main( cArg )

   hb_gtInfo( HB_GTI_WINTITLE, "Pong Arcade by Jair Lima" )

   ErrorBlock( {| oErr | CrashLog( oErr ) } )
   TimerRes( 1 )
   LoadBest()

   IF cArg != NIL .AND. Lower( cArg ) == "--selftest"
      SelfTest()
      RETURN
   ENDIF

   // modo bot: CPU x CPU acelerado, sem teclado e sem console (compilar com pongbot.hbp, GT nulo)
   IF cArg != NIL .AND. Lower( cArg ) == "--bot"
      InitSound()
      RunBot()
      RETURN
   ENDIF

   IF MaxRow() < 24 .OR. MaxCol() < 79
      ? "Pong Arcade by Jair Lima precisa de um terminal de pelo menos 80x25."
      RETURN
   ENDIF

   InitSound()
   SetCursor( SC_NONE )
   SetColor( "W/N" )
   hb_DispOutAt( 0, 0, " ", "W/N" )        // garante que o GT ja abriu o console
   ConsoleQuiet()

   IF cArg != NIL .AND. Lower( cArg ) == "--play1"
      PlayMatch( 1 )
   ELSEIF cArg != NIL .AND. Lower( cArg ) == "--play2"
      PlayMatch( 2 )
   ELSE
      RunMenu()
   ENDIF

   SetColor( "W/N" )
   CLS
   SetCursor( SC_NORMAL )
   ? "Obrigado por jogar Pong Arcade by Jair Lima!"
   ?

RETURN

// Erro de execucao: o console do GTWIN fecha logo em seguida, entao grava um log
// (descricao, operacao e pilha) ao lado do .exe antes de sair.
STATIC FUNCTION CrashLog( oErr )

   LOCAL cTxt := "Pong Arcade by Jair Lima - erro de execucao" + hb_eol() + ;
      "Descricao: " + oErr:description + hb_eol() + ;
      "Operacao : " + IIF( ValType( oErr:operation ) == "C", oErr:operation, "" ) + hb_eol() + ;
      "Subsist. : " + IIF( ValType( oErr:subSystem ) == "C", oErr:subSystem, "" ) + ;
      " cod " + hb_ntos( oErr:genCode ) + hb_eol() + "Pilha:" + hb_eol()
   LOCAL n := 1

   DO WHILE ! Empty( ProcName( n ) )
      cTxt += "  " + ProcName( n ) + "(" + hb_ntos( ProcLine( n ) ) + ")" + hb_eol()
      n++
   ENDDO
   hb_MemoWrit( hb_DirBase() + "pong_crash.log", cTxt )
   SetCursor( SC_NORMAL )
   QUIT

RETURN NIL

// ---------------------------------------------------------------------
// Menu / abertura
// ---------------------------------------------------------------------

STATIC PROCEDURE RunMenu()

   LOCAL nSel := 1, nTick := 0, k, i, r, cRow, nBx := 10, nDx := 1, nBy := 21, nDy := 1
   LOCAL aLet := { ;
      { "#### ", "#   #", "#### ", "#    ", "#    " }, ;
      { " ### ", "#   #", "#   #", "#   #", " ### " }, ;
      { "#   #", "##  #", "# # #", "#  ##", "#   #" }, ;
      { " ####", "#    ", "# ###", "#   #", " ### " } }
   LOCAL aClr := { "R+/N", "Y+/N", "G+/N", "C+/N" }
   LOCAL aLbl, cClr

   DO WHILE .T.

      SetColor( "W/N" )
      CLS
      hb_DispOutAt( 0, 0, PadC( "P O N G   A R C A D E   by Jair Lima", 80 ), "N/W" )
      hb_DispOutAt( 24, 0, PadC( "(c) Jair Lima - Harbour + GTWIN", 79 ), "N+/N" )

      DO WHILE .T.

         FOR i := 1 TO 4
            FOR r := 1 TO 5
               cRow := StrTran( aLet[ i ][ r ], "#", BLK + BLK )
               hb_DispOutAt( 2 + r, 15 + ( i - 1 ) * 13, cRow, aClr[ ( Int( nTick / 4 ) + i ) % 4 + 1 ] )
            NEXT
         NEXT

         aLbl := { "1 JOGADOR   (contra a CPU)", ;
                   "2 JOGADORES (mesmo teclado)", ;
                   "DIFICULDADE: " + { "FACIL  ", "NORMAL ", "DIFICIL" }[ s_nDiff ], ;
                   "SOM: " + IIF( s_lSnd, "LIGADO   ", "DESLIGADO" ), ;
                   "SAIR" }
         FOR i := 1 TO 5
            cClr := IIF( i == nSel, "N/W", "W/N" )
            hb_DispOutAt( 10 + i * 2 - 2, 24, PadR( IIF( i == nSel, " > ", "   " ) + aLbl[ i ], 32 ), cClr )
         NEXT

         hb_DispOutAt( 20, 0, PadC( "MELHOR RALLY: " + hb_ntos( s_nBest ), 80 ), "Y+/N" )
         hb_DispOutAt( 22, 0, PadC( "CIMA/BAIXO escolhe   ENTER confirma   ESQ/DIR muda   ESC sai", 80 ), "W/N" )

         // bolinha quicando na linha 21 e 23
         hb_DispOutAt( 21, 0, Space( 80 ), "W/N" )
         nBx += nDx
         IF nBx >= 78 .OR. nBx <= 1
            nDx := -nDx
            nBx += nDx
         ENDIF
         hb_DispOutAt( 21, nBx, BLK, "W+/N" )

         k := Inkey( 0.06 )
         nTick++

         DO CASE
         CASE k == K_UP .OR. k == Asc( "w" ) .OR. k == Asc( "W" )
            nSel := IIF( nSel == 1, 5, nSel - 1 )
            PlaySfx( "wall", 1 )
         CASE k == K_DOWN .OR. k == Asc( "s" ) .OR. k == Asc( "S" )
            nSel := IIF( nSel == 5, 1, nSel + 1 )
            PlaySfx( "wall", 1 )
         CASE k == K_LEFT .OR. k == K_RIGHT
            IF nSel == 3
               s_nDiff := IIF( k == K_RIGHT, Min( 3, s_nDiff + 1 ), Max( 1, s_nDiff - 1 ) )
               PlaySfx( "paddle2", 2 )
            ELSEIF nSel == 4
               s_lSnd := ! s_lSnd
            ENDIF
         CASE k == K_ENTER .OR. k == 32
            PlaySfx( "coin", 5 )
            DO CASE
            CASE nSel == 1
               Inkey( 0.4 )
               PlayMatch( 1 )
               EXIT
            CASE nSel == 2
               Inkey( 0.4 )
               PlayMatch( 2 )
               EXIT
            CASE nSel == 3
               s_nDiff := s_nDiff % 3 + 1
            CASE nSel == 4
               s_lSnd := ! s_lSnd
            CASE nSel == 5
               RETURN
            ENDCASE
         CASE k == K_ESC
            RETURN
         CASE k == Asc( "m" ) .OR. k == Asc( "M" )
            s_lSnd := ! s_lSnd
         ENDCASE

      ENDDO

   ENDDO

RETURN

// ---------------------------------------------------------------------
// Partida
// ---------------------------------------------------------------------

STATIC FUNCTION PlayMatch( nPl )

   LOCAL nDir, nRes, lQuit := .F., nWin := 0, cMsg

   s_nPlayers := nPl
   s_nSc1 := 0
   s_nSc2 := 0
   s_nRally := 0
   s_nHits := 0
   s_nP1 := FT + ( FH - PH ) / 2.0
   s_nP2 := FT + ( FH - PH ) / 2.0
   s_nErr1 := 0
   s_nErr2 := 0
   DrawFrame()
   HudAll()
   nDir := IIF( hb_RandomInt( 0, 1 ) == 0, 1, -1 )

   DO WHILE nWin == 0 .AND. ! lQuit
      nRes := PlayPoint( nDir, @lQuit )
      IF lQuit
         EXIT
      ENDIF
      IF nRes == 1
         s_nSc1++
         nDir := 1                    // saque vai para quem perdeu o ponto
      ELSE
         s_nSc2++
         nDir := -1
      ENDIF
      SaveBestIfNeeded()
      HudAll()                                   // o placar muda na hora, antes da pausa
      hb_DispOutAt( FT + 2, FL + Int( FWID / 2 ) - 6, PadC( IIF( nRes == 1, "PONTO P1", "PONTO P2" ), 12 ), "Y+/N" )
      PauseSec( 1.1 )
      hb_DispOutAt( FT + 2, FL + Int( FWID / 2 ) - 6, Space( 12 ), "W/N" )
      IF s_nSc1 >= WIN_SCORE
         nWin := 1
      ELSEIF s_nSc2 >= WIN_SCORE
         nWin := 2
      ENDIF
   ENDDO

   IF nWin > 0
      IF nPl == 1
         cMsg := IIF( nWin == 1, "VOCE VENCEU!", "A CPU VENCEU" )
      ELSE
         cMsg := "JOGADOR " + hb_ntos( nWin ) + " VENCEU!"
      ENDIF
      Banner( cMsg, IIF( nWin == 1 .OR. nPl == 2, "G+/N", "R+/N" ) )
      PlaySfx( IIF( nWin == 2 .AND. nPl == 1, "lose", "win" ), 5 )
      PauseSec( 3.5 )
      hb_keyClear()
   ENDIF

RETURN nWin

// um ponto: saque com contagem, troca de bolas ate alguem pontuar. Retorna 1 ou 2.
STATIC FUNCTION PlayPoint( nDir, lQuit )

   LOCAL nNext, nCount := 60, lPlay := .F., nRes := 0, nTick := 0, nLastNum := 0, nSpin := 0

   ServeBall( nDir )
   s_nRally := 0
   s_lReqPause := .F.
   s_lReqQuit := .F.
   IF ! s_lBot
      hb_keyClear()
   ENDIF
   RedrawAll()
   nNext := TickMs() + s_nTickMs

   DO WHILE nRes == 0

      Stage( "pollkeys" )
      IF ! s_lBot                    // o bot nao le o teclado (leitura de console bloqueia em terminal automatizado)
         PollKeys()
      ENDIF
      IF s_lReqQuit
         Banner( "SAIR DA PARTIDA? (S/N)", "R+/N" )
         DO WHILE .T.
            nRes := Inkey( 0 )
            IF nRes == Asc( "s" ) .OR. nRes == Asc( "S" ) .OR. nRes == Asc( "y" ) .OR. nRes == Asc( "Y" )
               lQuit := .T.
               RETURN 0
            ELSEIF nRes == Asc( "n" ) .OR. nRes == Asc( "N" ) .OR. nRes == K_ESC
               EXIT
            ENDIF
         ENDDO
         nRes := 0
         RedrawAll()
         nNext := TickMs() + s_nTickMs
      ENDIF
      IF s_lReqPause
         PlaySfx( "pause", 5 )
         Banner( "PAUSA - qualquer tecla", "Y+/N" )
         Inkey( 0 )
         RedrawAll()
         nNext := TickMs() + s_nTickMs
      ENDIF

      IF s_lBot
         s_aBotLog[ 5 ]++
         IF GetEnv( "PONG_BEAT" ) == "1" .AND. s_aBotLog[ 5 ] % 25 == 0           // batimento: mostra onde o bot esta se travar
            hb_MemoWrit( hb_DirBase() + "pong_bot_beat.log", "ticks=" + hb_ntos( s_aBotLog[ 5 ] ) + ;
               " placar=" + hb_ntos( s_nSc1 ) + "x" + hb_ntos( s_nSc2 ) + " rally=" + hb_ntos( s_nRally ) + ;
               " bola=" + hb_ntos( Round( s_nBx, 1 ) ) + "," + hb_ntos( Round( s_nBy, 1 ) ) + ;
               " v=" + hb_ntos( Round( s_nVx, 2 ) ) + "," + hb_ntos( Round( s_nVy, 2 ) ) + ;
               " jogando=" + IIF( lPlay, "sim", "nao" ) + " contagem=" + hb_ntos( nCount ) + ;
               " desvio_relogio_sistema_ms=" + hb_ntos( hb_MilliSeconds() - TickMs() - s_nClkBase ) + ;
               " perfil_ms=" + hb_ValToExp( s_hProf ) + hb_eol() )
         ENDIF
         IF TickMs() > s_nBotUntil
            lQuit := .T.
            RETURN 0
         ENDIF
      ENDIF

      nTick++
      Stage( "movepaddles" )
      MovePaddles()

      IF ! lPlay
         // contagem do saque: 3, 2, 1 e GO
         nCount--
         IF Int( nCount / 20 ) + 1 != nLastNum .AND. nCount > 0
            nLastNum := Int( nCount / 20 ) + 1
            hb_DispOutAt( FT + 2, FL + Int( FWID / 2 ) - 4, "  " + hb_ntos( nLastNum ) + "  ", "Y+/N" )
            PlaySfx( "count", 3 )
         ENDIF
         IF nCount <= 0
            lPlay := .T.
            hb_DispOutAt( FT + 2, FL + Int( FWID / 2 ) - 4, Space( 5 ), "W/N" )
            PlaySfx( "go", 3 )
         ENDIF
      ELSE
         Stage( "stepball" )
         nRes := StepBall()
      ENDIF

      Stage( "draw" )
      DrawAll()

      Stage( "sleep" )
      nSpin := 0
      DO WHILE TickMs() < nNext
         SleepMs( 1 )
         nSpin++
         IF nSpin > 1000              // defesa: espera de ~1 s para um tick de poucos ms e sinal de prazo errado
            hb_MemoWrit( hb_DirBase() + "pong_spin.log", "espera anormal: nNext=" + hb_ntos( nNext ) + ;
               " TickMs=" + hb_ntos( TickMs() ) + " s_nTickMs=" + hb_ntos( s_nTickMs ) + ;
               " ticks=" + hb_ntos( s_aBotLog[ 5 ] ) + " tipo_nNext=" + ValType( nNext ) + hb_eol() )
            nNext := TickMs()
            EXIT
         ENDIF
      ENDDO
      nNext += s_nTickMs
      IF TickMs() > nNext + 3 * s_nTickMs
         nNext := TickMs() + s_nTickMs
      ENDIF

   ENDDO

   // ponto marcado: som, bola piscando fora, pausa curta
   PlaySfx( "score", 4 )
   IF s_nRally > s_nBest
      s_nBest := s_nRally
   ENDIF

RETURN nRes

STATIC PROCEDURE PauseSec( nSec )     // nao chamar de Wait: WAIT e comando do Harbour (espera tecla)

   IF s_lBot
      SleepMs( 1 )
   ELSE
      Inkey( nSec )
   ENDIF

RETURN

// ---------------------------------------------------------------------
// Regras / fisica (funcoes testaveis sem tela)
// ---------------------------------------------------------------------

// dobra y para dentro de [FT, FT+FH-1] como onda triangular (quicando nas paredes)
STATIC FUNCTION ReflectY( y )

   LOCAL nLo := FT, nSpan := FH - 1, nP := 2 * ( FH - 1 ), t := y - FT

   t := t - Int( t / nP ) * nP
   IF t < 0
      t += nP
   ENDIF
   IF t > nSpan
      t := nP - t
   ENDIF

RETURN nLo + t

// y em que a bola estara ao chegar em xT (com quicadas nas paredes)
STATIC FUNCTION PredictY( bx, by, vx, vy, xT )

   LOCAL n

   IF vx == 0
      RETURN by
   ENDIF
   n := ( xT - bx ) / vx
   IF n < 0
      RETURN by
   ENDIF

RETURN ReflectY( by + vy * n )

// deslocamento do contato em relacao ao centro da raquete, -1 (ponta de cima) a +1 (baixo)
STATIC FUNCTION PaddleOffset( nPy, y )
RETURN ( y - ( nPy + ( PH - 1 ) / 2.0 ) ) / ( ( PH - 1 ) / 2.0 + 0.6 )

STATIC FUNCTION PaddleHits( nPy, y )
RETURN Abs( PaddleOffset( nPy, y ) ) <= 1.0

STATIC FUNCTION ClampP( nPy )
RETURN Max( FT, Min( FT + FH - PH, nPy ) )

STATIC PROCEDURE ServeBall( nDir )

   s_nSpd := SPD0
   s_nBx := FL + Int( FWID / 2 ) + 0.0          // coluna da rede
   s_nBy := FT + ( FH - 1 ) / 2.0
   s_nVx := nDir * s_nSpd
   s_nVy := ( hb_RandomInt( -25, 25 ) / 100.0 ) * s_nSpd

RETURN

// avanca a bola um tick. Retorna 0 (em jogo), 1 (ponto do jogador 1) ou 2 (ponto do jogador 2)
STATIC FUNCTION StepBall()

   LOCAL nOx := s_nBx, nOy := s_nBy, nNx := s_nBx + s_nVx, nNy := s_nBy + s_nVy
   LOCAL f, yc, nOff, lHit := .F.

   // raquete esquerda (jogador 1)
   IF s_nVx < 0 .AND. nOx >= XL .AND. nNx < XL
      f := ( nOx - XL ) / ( nOx - nNx )
      yc := ReflectY( nOy + s_nVy * f )
      IF PaddleHits( s_nP1, yc )
         nOff := PaddleOffset( s_nP1, yc )
         s_nSpd := Min( SPD_MAX, s_nSpd + SPD_STEP )
         s_nVx := s_nSpd
         s_nVy := nOff * s_nSpd * VY_FACTOR
         nNx := XL + s_nVx * ( 1 - f )
         nNy := yc + s_nVy * ( 1 - f )
         s_nRally++
         s_nHits++
         s_nErr2 := AiError( s_nDiff )
         PlaySfx( PaddleSfx( nOff ), 2 )
         lHit := .T.
      ENDIF
   // raquete direita (jogador 2 ou CPU)
   ELSEIF s_nVx > 0 .AND. nOx <= XR .AND. nNx > XR
      f := ( XR - nOx ) / ( nNx - nOx )
      yc := ReflectY( nOy + s_nVy * f )
      IF PaddleHits( s_nP2, yc )
         nOff := PaddleOffset( s_nP2, yc )
         s_nSpd := Min( SPD_MAX, s_nSpd + SPD_STEP )
         s_nVx := -s_nSpd
         s_nVy := nOff * s_nSpd * VY_FACTOR
         nNx := XR + s_nVx * ( 1 - f )
         nNy := yc + s_nVy * ( 1 - f )
         s_nRally++
         s_nHits++
         s_nErr1 := AiError( IIF( s_lBot, s_nDiffL, s_nDiff ) )
         PlaySfx( PaddleSfx( nOff ), 2 )
         lHit := .T.
      ENDIF
   ENDIF

   // paredes de cima e de baixo
   IF nNy < FT
      nNy := 2 * FT - nNy
      s_nVy := -s_nVy
      IF ! lHit
         PlaySfx( "wall", 1 )
      ENDIF
   ELSEIF nNy > FT + FH - 1
      nNy := 2 * ( FT + FH - 1 ) - nNy
      s_nVy := -s_nVy
      IF ! lHit
         PlaySfx( "wall", 1 )
      ENDIF
   ENDIF

   s_nBx := nNx
   s_nBy := nNy

   // saiu da quadra: ponto
   IF s_nBx < FL
      RETURN 2
   ELSEIF s_nBx > FL + FWID - 1
      RETURN 1
   ENDIF

RETURN 0

// tom da rebatida pelo ponto de contato: centro grave, pontas agudas (Int obrigatorio no nome)
STATIC FUNCTION PaddleSfx( nOff )
RETURN "paddle" + hb_ntos( IIF( Abs( nOff ) < 0.35, 1, IIF( Abs( nOff ) < 0.7, 2, 3 ) ) )

// erro de mira da IA, sorteado a cada rebatida do adversario. A zona de acerto da
// raquete e de +-2,1 linhas do centro: erro maior que isso e ponto perdido. Com
// erros menores que 2,1 a IA nunca erra e o ponto CPU x CPU nunca termina
// (descoberto pela simulacao do autoteste). Chance de errar: facil ~42%,
// normal ~19%, dificil ~9%.
STATIC FUNCTION AiError( nDiff )

   LOCAL nMax := { 3.6, 2.6, 2.3 }[ Max( 1, Min( 3, nDiff ) ) ]

RETURN ( hb_RandomInt( -100, 100 ) / 100.0 ) * nMax

// um passo da IA: devolve o novo topo da raquete
STATIC FUNCTION AiStep( nSide, nDiff, nPy, nErr )

   LOCAL nSpd := { 0.30, 0.42, 0.55 }[ Max( 1, Min( 3, nDiff ) ) ]
   LOCAL xT := IIF( nSide == 1, XL, XR )
   LOCAL lApp := IIF( nSide == 1, s_nVx < 0, s_nVx > 0 )
   LOCAL nReach := { 34, 52, 100 }[ Max( 1, Min( 3, nDiff ) ) ]
   LOCAL nTarget, nDelta

   IF lApp .AND. Abs( s_nBx - xT ) < nReach
      nTarget := PredictY( s_nBx, s_nBy, s_nVx, s_nVy, xT ) + nErr - ( PH - 1 ) / 2.0
   ELSE
      nTarget := FT + ( FH - PH ) / 2.0           // volta ao centro
   ENDIF
   nDelta := nTarget - nPy
   IF Abs( nDelta ) <= 0.25
      RETURN nPy
   ENDIF

RETURN ClampP( nPy + IIF( nDelta > 0, 1, -1 ) * Min( nSpd, Abs( nDelta ) ) )

// ---------------------------------------------------------------------
// Entrada
// ---------------------------------------------------------------------

STATIC PROCEDURE PollKeys()

   LOCAL k

   s_nEvDy := 0
   s_nEv1 := 0                    // eventos W/S (jogador 1)
   s_nEv2 := 0                    // eventos das setas (jogador 2)
   s_lReqPause := .F.
   s_lReqQuit := .F.

   DO WHILE ( k := Inkey() ) != 0
      s_nLastKey := TickMs()
      DO CASE
      CASE k == K_UP .OR. k == Asc( "w" ) .OR. k == Asc( "W" )
         s_nEvDy--
         IF k == K_UP
            s_nEv2--
         ELSE
            s_nEv1--
         ENDIF
         ProbeAsync( IIF( k == K_UP, VK_UP, VK_W ) )
      CASE k == K_DOWN .OR. k == Asc( "s" ) .OR. k == Asc( "S" )
         s_nEvDy++
         IF k == K_DOWN
            s_nEv2++
         ELSE
            s_nEv1++
         ENDIF
         ProbeAsync( IIF( k == K_DOWN, VK_DOWN, VK_S ) )
      CASE k == Asc( "m" ) .OR. k == Asc( "M" )
         s_lSnd := ! s_lSnd
      CASE k == Asc( "p" ) .OR. k == Asc( "P" )
         s_lReqPause := .T.
      CASE k == K_ESC
         s_lReqQuit := .T.
      ENDCASE
   ENDDO

   IF s_lBot                      // o bot nunca para para pedir confirmacao
      s_lReqQuit := .F.
      s_lReqPause := .F.
   ENDIF

RETURN

// estado real da tecla, valido se a janela tem foco ou recebeu teclado ha menos de 2,5 s
STATIC FUNCTION KeyDown( nVk )

   IF ! KeyRaw( nVk )
      RETURN .F.
   ENDIF

RETURN KeyFocus() .OR. ( TickMs() - s_nLastKey ) < 2500

STATIC PROCEDURE ProbeAsync( nVk )

   IF KeyRaw( nVk )
      s_nMiss := 0
      s_nAsync := 1
   ELSE
      s_nMiss++
      IF s_nMiss >= 8
         s_nAsync := -1
      ENDIF
   ENDIF

RETURN

STATIC FUNCTION SignOf( n )
RETURN IIF( n > 0, 1, IIF( n < 0, -1, 0 ) )

// movimento das duas raquetes (humano, CPU ou, no modo bot, CPU x CPU)
STATIC PROCEDURE MovePaddles()

   LOCAL nD1 := 0, nD2 := 0

   IF s_lBot
      s_nP1 := AiStep( 1, s_nDiffL, s_nP1, s_nErr1 )
      s_nP2 := AiStep( 2, s_nDiff, s_nP2, s_nErr2 )
      RETURN
   ENDIF

   IF s_nAsync == 1
      IF s_nPlayers == 1
         nD1 := IIF( KeyDown( VK_DOWN ) .OR. KeyDown( VK_S ), 1, 0 ) - IIF( KeyDown( VK_UP ) .OR. KeyDown( VK_W ), 1, 0 )
      ELSE
         nD1 := IIF( KeyDown( VK_S ), 1, 0 ) - IIF( KeyDown( VK_W ), 1, 0 )
         nD2 := IIF( KeyDown( VK_DOWN ), 1, 0 ) - IIF( KeyDown( VK_UP ), 1, 0 )
      ENDIF
      IF nD1 == 0 .AND. nD2 == 0 .AND. s_nEvDy != 0 .AND. s_nPlayers == 1
         nD1 := IIF( s_nEvDy > 0, 1, -1 )          // toque rapido ja solto
      ENDIF
   ELSE
      // fallback por eventos do Inkey: W/S movem o jogador 1, setas o jogador 2 (no modo
      // 1 jogador as duas teclas movem o jogador 1). Cada evento = 1,5 passo.
      IF s_nPlayers == 1
         nD1 := SignOf( s_nEv1 + s_nEv2 ) * 1.5
      ELSE
         nD1 := SignOf( s_nEv1 ) * 1.5
         nD2 := SignOf( s_nEv2 ) * 1.5
      ENDIF
   ENDIF

   s_nP1 := ClampP( s_nP1 + nD1 * PSPD )
   IF s_nPlayers == 1
      s_nP2 := AiStep( 2, s_nDiff, s_nP2, s_nErr2 )
   ELSE
      s_nP2 := ClampP( s_nP2 + nD2 * PSPD )
   ENDIF

RETURN

// ---------------------------------------------------------------------
// Desenho
// ---------------------------------------------------------------------

STATIC PROCEDURE DrawFrame()

   SetColor( "W/N" )
   CLS
   hb_DispOutAt( 0, 0, PadC( "P O N G   A R C A D E   by Jair Lima", 80 ), "N/W" )
   hb_DispOutAt( FT - 1, FL, Replicate( Chr( 205 ), FWID ), "B+/N" )
   hb_DispOutAt( FT + FH, FL, Replicate( Chr( 205 ), FWID ), "B+/N" )
   hb_DispOutAt( FT + FH + 1, 0, PadC( IIF( s_nPlayers == 1, ;
      "W/S ou SETAS: mover   P pausa   M som   ESC sair", ;
      "J1: W/S   J2: SETAS   P pausa   M som   ESC sair" ), 80 ), "N+/N" )
   s_nDrBr := -1
   s_nDrBc := -1
   s_nDr1 := -1
   s_nDr2 := -1

RETURN

STATIC PROCEDURE DrawBigDigit( n, nRow, nCol, cClr )

   LOCAL r

   FOR r := 1 TO 5
      hb_DispOutAt( nRow + r - 1, nCol, StrTran( StrTran( s_aFont[ Min( 9, n ) + 1 ][ r ], "#", BLK + BLK ), " ", "  " ), cClr )
   NEXT

RETURN

STATIC PROCEDURE HudAll()

   hb_DispOutAt( 1, 8, PadR( IIF( s_nPlayers == 1, "VOCE", "JOGADOR 1" ), 12 ), "W/N" )
   hb_DispOutAt( 1, 60, PadL( IIF( s_nPlayers == 1, "CPU " + { "FACIL", "NORMAL", "DIFICIL" }[ s_nDiff ], "JOGADOR 2" ), 12 ), "W/N" )
   DrawBigDigit( s_nSc1, 2, 14, "G+/N" )
   DrawBigDigit( s_nSc2, 2, 58, "C+/N" )
   hb_DispOutAt( 2, 34, PadC( "RALLY " + hb_ntos( s_nRally ), 12 ), "Y+/N" )
   hb_DispOutAt( 4, 34, PadC( "MELHOR " + hb_ntos( s_nBest ), 12 ), "W/N" )

RETURN

STATIC PROCEDURE DrawPaddles()

   LOCAL n1 := Int( s_nP1 + 0.5 ), n2 := Int( s_nP2 + 0.5 ), r

   IF n1 != s_nDr1
      IF s_nDr1 >= 0
         FOR r := 0 TO PH - 1
            hb_DispOutAt( s_nDr1 + r, PL0, "  ", "W/N" )
         NEXT
      ENDIF
      FOR r := 0 TO PH - 1
         hb_DispOutAt( n1 + r, PL0, BLK + BLK, "G+/N" )
      NEXT
      s_nDr1 := n1
   ENDIF
   IF n2 != s_nDr2
      IF s_nDr2 >= 0
         FOR r := 0 TO PH - 1
            hb_DispOutAt( s_nDr2 + r, PR0, "  ", "W/N" )
         NEXT
      ENDIF
      FOR r := 0 TO PH - 1
         hb_DispOutAt( n2 + r, PR0, BLK + BLK, "C+/N" )
      NEXT
      s_nDr2 := n2
   ENDIF

RETURN

STATIC PROCEDURE DrawNet( nFrom, nTo )

   LOCAL r

   FOR r := nFrom TO nTo
      IF r % 2 == 0
         hb_DispOutAt( r, FL + Int( FWID / 2 ), Chr( 179 ), "N+/N" )
      ENDIF
   NEXT

RETURN

STATIC PROCEDURE DrawBall()

   LOCAL nR := Int( s_nBy + 0.5 ), nC := Int( s_nBx + 0.5 )

   IF nR == s_nDrBr .AND. nC == s_nDrBc      // bola na mesma celula: nao redesenha (evita flicker)
      RETURN
   ENDIF

   IF s_nDrBr >= 0
      hb_DispOutAt( s_nDrBr, s_nDrBc, " ", "W/N" )
      IF s_nDrBc == FL + Int( FWID / 2 ) .AND. s_nDrBr % 2 == 0
         hb_DispOutAt( s_nDrBr, s_nDrBc, Chr( 179 ), "N+/N" )
      ENDIF
   ENDIF
   IF nC >= FL .AND. nC <= FL + FWID - 1 .AND. nR >= FT .AND. nR <= FT + FH - 1
      hb_DispOutAt( nR, nC, BLK, "W+/N" )
      s_nDrBr := nR
      s_nDrBc := nC
   ELSE
      s_nDrBr := -1
   ENDIF

RETURN

STATIC PROCEDURE DrawAll()

   DrawBall()
   DrawPaddles()
   // so redesenha o texto quando o rally muda: escrever o mesmo texto a cada tick
   // enche a pipe do ConPTY (Windows Terminal) e bloqueia toda chamada de console
   IF s_nRally != s_nRallyDrawn
      hb_DispOutAt( 2, 34, PadC( "RALLY " + hb_ntos( s_nRally ), 12 ), "Y+/N" )
      s_nRallyDrawn := s_nRally
   ENDIF

RETURN

STATIC PROCEDURE RedrawAll()

   LOCAL r

   FOR r := FT TO FT + FH - 1
      hb_DispOutAt( r, FL, Space( FWID ), "W/N" )
   NEXT
   s_nDrBr := -1
   s_nDr1 := -1
   s_nDr2 := -1
   DrawNet( FT, FT + FH - 1 )
   DrawPaddles()
   DrawBall()
   HudAll()

RETURN

STATIC PROCEDURE Banner( cMsg, cClr )

   LOCAL c := "  " + cMsg + "  "
   LOCAL nCol := FL + Int( FWID / 2 ) - Int( Len( c ) / 2 )
   LOCAL nRow := FT + Int( FH / 2 ) - 1

   hb_DispOutAt( nRow - 1, nCol - 1, Space( Len( c ) + 2 ), cClr )
   hb_DispOutAt( nRow, nCol - 1, " " + c + " ", cClr )
   hb_DispOutAt( nRow + 1, nCol - 1, Space( Len( c ) + 2 ), cClr )

RETURN

// ---------------------------------------------------------------------
// Melhor rally
// ---------------------------------------------------------------------

STATIC PROCEDURE LoadBest()

   LOCAL cFile := hb_DirBase() + BEST_FILE

   s_nBest := IIF( File( cFile ), Max( 0, Int( Val( MemoRead( cFile ) ) ) ), 0 )

RETURN

STATIC PROCEDURE SaveBestIfNeeded()

   LOCAL cFile := hb_DirBase() + BEST_FILE

   IF s_lBot
      RETURN
   ENDIF
   IF Max( 0, Int( Val( MemoRead( cFile ) ) ) ) < s_nBest
      IF ! hb_MemoWrit( cFile, hb_ntos( s_nBest ) )
         hb_DispOutAt( 24, 0, PadC( "ATENCAO: melhor rally nao gravado (pasta sem permissao)", 80 ), "R+/N" )
      ELSE
         PlaySfx( "hiscore", 5 )
      ENDIF
   ENDIF

RETURN

// ---------------------------------------------------------------------
// Som: WAV 8 bits (onda quadrada e ruido) via winmm, com prioridade (canal unico)
// ---------------------------------------------------------------------

STATIC PROCEDURE InitSound()

   s_cTmp := GetEnv( "TEMP" )
   IF Empty( s_cTmp )
      s_cTmp := "."
   ENDIF
   IF ! Right( s_cTmp, 1 ) == "\"
      s_cTmp += "\"
   ENDIF

   MakeWav( "coin",    { { 988, 988, 70 }, { 1319, 1319, 330 } } )
   MakeWav( "paddle1", { { 440, 440, 45 } } )
   MakeWav( "paddle2", { { 560, 560, 45 } } )
   MakeWav( "paddle3", { { 700, 700, 45 } } )
   MakeWav( "wall",    { { 260, 260, 40 } } )
   MakeWav( "count",   { { 660, 660, 70 } } )
   MakeWav( "go",      { { 880, 880, 160 } } )
   MakeWav( "score",   { { 440, 110, 320 } } )
   MakeWav( "win",     { { 523, 523, 90 }, { 659, 659, 90 }, { 784, 784, 90 }, { 1047, 1047, 90 }, ;
                         { 784, 784, 90 }, { 1047, 1047, 360 } } )
   MakeWav( "lose",    { { 392, 392, 260 }, { 330, 330, 260 }, { 262, 262, 260 }, { 196, 196, 620 } } )
   MakeWav( "pause",   { { 600, 600, 50 }, { 400, 400, 80 } } )
   MakeWav( "hiscore", { { 784, 784, 90 }, { 988, 988, 90 }, { 1175, 1175, 90 }, { 1568, 1568, 260 } } )

RETURN

STATIC PROCEDURE MakeWav( cName, aNotes )

   LOCAL nRate := 11025
   LOCAL cData := "", a, i, nSamp, nPh, f, nAmp, nVal, cHdr, nMs := 0

   FOR EACH a IN aNotes
      nSamp := Int( a[ 3 ] * nRate / 1000 )
      nMs += a[ 3 ]
      nPh := 0
      FOR i := 1 TO nSamp
         f := a[ 1 ] + ( a[ 2 ] - a[ 1 ] ) * i / nSamp
         nAmp := 70 * ( 1 - 0.6 * i / nSamp )
         nPh += f / nRate
         nPh -= Int( nPh )
         nVal := IIF( nPh < 0.5, 128 + nAmp, 128 - nAmp )
         cData += Chr( Int( nVal ) )
      NEXT
   NEXT

   cHdr := "RIFF" + L2Bin( 36 + Len( cData ) ) + "WAVEfmt " + L2Bin( 16 ) + I2Bin( 1 ) + I2Bin( 1 ) + ;
      L2Bin( nRate ) + L2Bin( nRate ) + I2Bin( 1 ) + I2Bin( 8 ) + "data" + L2Bin( Len( cData ) )

   hb_MemoWrit( s_cTmp + "pong_" + cName + ".wav", cHdr + cData )
   s_hDur[ cName ] := nMs

RETURN

// canal unico: igual ou maior prioridade substitui; menor e DESCARTADO (nao entra em fila)
STATIC FUNCTION CanPlay( nPrio, nNow )
RETURN nNow >= s_nBusyUntil .OR. nPrio >= s_nBusyPrio

STATIC PROCEDURE PlaySfx( cName, nPrio )

   LOCAL nNow := TickMs()

   IF ! s_lSnd .OR. s_cTmp == NIL .OR. ! CanPlay( nPrio, nNow )
      RETURN
   ENDIF
   IF ! hb_HHasKey( s_hDur, cName )       // nome inexistente nunca derruba o jogo (o autoteste cobre os nomes)
      RETURN
   ENDIF
   s_nBusyUntil := nNow + s_hDur[ cName ]
   s_nBusyPrio := nPrio
   wapi_PlaySound( s_cTmp + "pong_" + cName + ".wav", NIL, SND_FLAGS )

RETURN

// ---------------------------------------------------------------------
// Modo bot: CPU x CPU acelerado para exercitar o fluxo real sem humano
// ---------------------------------------------------------------------

STATIC PROCEDURE RunBot()

   LOCAL nWin, i

   s_lBot := .T.
   s_nClkBase := hb_MilliSeconds() - TickMs()
   s_nTickMs := Max( 2, Val( GetEnv( "PONG_BOT_TICK" ) ) )
   IF s_nTickMs == 2 .AND. Empty( GetEnv( "PONG_BOT_TICK" ) )
      s_nTickMs := 12            // ticks muito curtos saturam a saida do Windows Terminal (ConPTY)
   ENDIF
   s_nBotUntil := TickMs() + 90000
   s_nDiffL := 1               // esquerda FACIL contra direita DIFICIL: o dificil deve vencer quase sempre
   s_nDiff := 3
   s_lSnd := ( GetEnv( "PONG_BOT_SOM" ) == "1" )      // teste: som desligado por padrao no bot
   s_nBest := 0

   FOR i := 1 TO 6
      nWin := PlayMatch( 2 )
      IF TickMs() > s_nBotUntil
         EXIT
      ENDIF
      s_aBotLog[ 1 ]++
      IF nWin == 1
         s_aBotLog[ 2 ]++
      ELSEIF nWin == 2
         s_aBotLog[ 3 ]++
      ENDIF
      s_aBotLog[ 4 ] += s_nSc1 + s_nSc2
   NEXT

   hb_MemoWrit( hb_DirBase() + "pong_bot.log", ;
      "partidas=" + hb_ntos( s_aBotLog[ 1 ] ) + " vitorias_facil_esq=" + hb_ntos( s_aBotLog[ 2 ] ) + ;
      " vitorias_dificil_dir=" + hb_ntos( s_aBotLog[ 3 ] ) + " pontos=" + hb_ntos( s_aBotLog[ 4 ] ) + ;
      " ticks=" + hb_ntos( s_aBotLog[ 5 ] ) + " maior_rally=" + hb_ntos( s_nBest ) + " fim=ok" + hb_eol() )

RETURN

// ---------------------------------------------------------------------
// C embutido: teclado fisico, foco, timer e sleep preciso
// ---------------------------------------------------------------------

#pragma BEGINDUMP

#define _WIN32_WINNT 0x0600
#include "hbapi.h"
#include <windows.h>
#include <mmsystem.h>

HB_FUNC( TIMERRES )
{
   timeBeginPeriod( ( UINT ) hb_parni( 1 ) );
}

HB_FUNC( SLEEPMS )
{
   Sleep( ( DWORD ) hb_parni( 1 ) );
}

// Console "quieto": desliga eventos de mouse e de janela e o modo de selecao por clique
// (QuickEdit). Eventos que a leitura de teclado do GTWIN contava mas descartava podiam
// deixar a leitura bloqueada esperando uma tecla (visto no gdb: thread principal
// parada em hb_gt_win_ReadKey), e a selecao por clique congela toda E/S do console.
HB_FUNC( CONSOLEQUIET )
{
   HANDLE hIn = GetStdHandle( STD_INPUT_HANDLE );
   DWORD  dwMode = 0;

   if( hIn != INVALID_HANDLE_VALUE && GetConsoleMode( hIn, &dwMode ) )
   {
      dwMode &= ~( ENABLE_MOUSE_INPUT | ENABLE_WINDOW_INPUT | ENABLE_QUICK_EDIT_MODE );
      dwMode |= ENABLE_EXTENDED_FLAGS;
      SetConsoleMode( hIn, dwMode );
   }
}

// relogio MONOTONICO em ms desde o boot. hb_MilliSeconds() vem do relogio do sistema
// (hora local) e pode andar para tras ou saltar quando o Windows ajusta a hora; um
// prazo calculado antes do salto deixava o laco de espera do tick dormindo ate o
// relogio "alcancar" o prazo (parecia travado). Todo pacing usa TickMs().
HB_FUNC( TICKMS )
{
   LARGE_INTEGER nFreq, nCnt;

   QueryPerformanceFrequency( &nFreq );
   QueryPerformanceCounter( &nCnt );
   hb_retnint( ( HB_MAXINT ) ( ( nCnt.QuadPart * 1000 ) / nFreq.QuadPart ) );
}

// estado fisico da tecla (global, sem checar foco)
HB_FUNC( KEYRAW )
{
   hb_retl( ( GetAsyncKeyState( hb_parni( 1 ) ) & 0x8000 ) != 0 );
}

// a janela do console (ou o terminal que a hospeda) esta em primeiro plano?
HB_FUNC( KEYFOCUS )
{
   HWND hCon  = GetConsoleWindow();
   HWND hFg   = GetForegroundWindow();
   HWND hRoot = hCon ? GetAncestor( hCon, GA_ROOTOWNER ) : NULL;

   hb_retl( ( hFg != NULL ) && ( hFg == hCon || hFg == hRoot ) );
}

#pragma ENDDUMP

// ---------------------------------------------------------------------
// Autoteste sem interface (pong --selftest): regras deterministas
// ---------------------------------------------------------------------

STATIC PROCEDURE SelfTest()

   LOCAL nBad := 0, cLog := "", cWav, a, i, j, nRes, nT0, nTicks, nOk, y, nPy, nPoints
   LOCAL nWall := 0, nStuck := 0, nMaxRally := 0
   LOCAL bChk := {| lOk, cMsg | cLog += IIF( lOk, "ok    ", "FALHA " ) + cMsg + hb_eol(), IIF( lOk, NIL, nBad++ ) }

   s_lSnd := .F.

   // 1. ReflectY: sempre dentro da quadra e continua nas bordas
   nOk := .T.
   FOR i := -300 TO 300
      y := ReflectY( FT + i * 0.37 )
      IF y < FT - 0.0001 .OR. y > FT + FH - 1 + 0.0001
         nOk := .F.
      ENDIF
   NEXT
   Eval( bChk, nOk, "ReflectY mantem y em [FT, FT+FH-1] para 601 valores" )
   Eval( bChk, Abs( ReflectY( FT + 3 ) - ( FT + 3 ) ) < 0.0001, "ReflectY identidade dentro da quadra" )
   Eval( bChk, Abs( ReflectY( FT - 2 ) - ( FT + 2 ) ) < 0.0001, "ReflectY quica na parede de cima" )
   Eval( bChk, Abs( ReflectY( FT + FH - 1 + 3 ) - ( FT + FH - 1 - 3 ) ) < 0.0001, "ReflectY quica na parede de baixo" )
   Eval( bChk, Abs( ReflectY( FT + 2 * ( FH - 1 ) + 4 ) - ( FT + 4 ) ) < 0.0001, "ReflectY duas quicadas voltam ao mesmo lado" )

   // 2. PredictY
   Eval( bChk, Abs( PredictY( 40, 12, 1, 0, 70 ) - 12 ) < 0.0001, "PredictY bola reta" )
   Eval( bChk, Abs( PredictY( 40, 12, 1, 0.1, 50 ) - 13 ) < 0.0001, "PredictY com inclinacao sem quicar" )
   Eval( bChk, Abs( PredictY( 40, 10, 1, -0.5, 50 ) - ReflectY( 5 ) ) < 0.0001, "PredictY com 1 quicada" )
   Eval( bChk, Abs( PredictY( 40, 12, -1, 0.2, 5 ) - ReflectY( 12 + 0.2 * 35 ) ) < 0.0001, "PredictY bola indo para a esquerda (desce 7 linhas)" )
   Eval( bChk, Abs( PredictY( 60, 12, -1, 0.2, 70 ) - 12 ) < 0.0001, "PredictY bola se afastando devolve a posicao atual" )

   // 3. contato com a raquete: centro = 0, pontas = +-1, alem = erra
   nPy := 10.0
   Eval( bChk, Abs( PaddleOffset( nPy, nPy + ( PH - 1 ) / 2.0 ) ) < 0.0001, "contato no centro: offset 0" )
   Eval( bChk, PaddleHits( nPy, nPy - 0.5 ) .AND. PaddleHits( nPy, nPy + PH - 1 + 0.5 ), "pontas da raquete acertam" )
   Eval( bChk, ! PaddleHits( nPy, nPy - 0.9 ) .AND. ! PaddleHits( nPy, nPy + PH - 1 + 0.9 ), "alem das pontas erra" )
   Eval( bChk, PaddleOffset( nPy, nPy ) < 0 .AND. PaddleOffset( nPy, nPy + PH - 1 ) > 0, "cima = negativo, baixo = positivo" )

   // 4. ClampP
   Eval( bChk, ClampP( -5 ) == FT .AND. ClampP( 99 ) == FT + FH - PH .AND. ClampP( FT + 3 ) == FT + 3, "ClampP limita a raquete na quadra" )

   // 5. rebatida: inverte vx, acelera, angulo pelo ponto de contato, sem atravessar a raquete
   ServeBall( -1 )
   s_nP1 := ClampP( s_nBy - ( PH - 1 ) / 2.0 )          // raquete centrada na bola
   s_nBx := XL + 0.4
   s_nBy := FT + 7
   s_nVx := -s_nSpd
   s_nVy := 0
   s_nP1 := FT + 7 - ( PH - 1 ) / 2.0
   nRes := StepBall()
   Eval( bChk, nRes == 0 .AND. s_nVx > 0, "rebatida na esquerda inverte vx" )
   Eval( bChk, s_nSpd > SPD0 .AND. s_nHits >= 1, "rebatida acelera a bola" )
   Eval( bChk, Abs( s_nVy ) < 0.05, "contato no centro: bola sai reta" )
   s_nBx := XL + 0.4
   s_nBy := FT + 7
   s_nVx := -s_nSpd
   s_nVy := 0
   s_nP1 := FT + 7 - ( PH - 1 ) + 0.5                     // bola na ponta de baixo
   nRes := StepBall()
   Eval( bChk, nRes == 0 .AND. s_nVy > 0.2, "contato na ponta de baixo: bola desce" )
   s_nBx := XL + 0.4
   s_nBy := FT + 7
   s_nVx := -s_nSpd
   s_nVy := 0
   s_nP1 := FT + 7 - 0.5                                  // bola na ponta de cima
   nRes := StepBall()
   Eval( bChk, nRes == 0 .AND. s_nVy < -0.2, "contato na ponta de cima: bola sobe" )

   // 6. erro: raquete longe, bola passa e o ponto vai para o outro lado
   ServeBall( -1 )
   s_nP1 := FT
   s_nBx := XL + 0.3
   s_nBy := FT + 12
   s_nVx := -1.0
   s_nVy := 0
   nRes := 0
   FOR i := 1 TO 40
      nRes := StepBall()
      IF nRes != 0
         EXIT
      ENDIF
   NEXT
   Eval( bChk, nRes == 2, "bola passa pela esquerda: ponto do jogador 2" )
   ServeBall( 1 )
   s_nP2 := FT
   s_nBx := XR - 0.3
   s_nBy := FT + 12
   s_nVx := 1.0
   s_nVy := 0
   nRes := 0
   FOR i := 1 TO 40
      nRes := StepBall()
      IF nRes != 0
         EXIT
      ENDIF
   NEXT
   Eval( bChk, nRes == 1, "bola passa pela direita: ponto do jogador 1" )

   // 7. sem tunelamento na velocidade maxima
   nOk := .T.
   FOR i := 0 TO 19                       // x de entrada ate 1.9 antes da face (com vx 2.0 ainda cruza)
      ServeBall( 1 )
      s_nP2 := FT + 6
      s_nSpd := SPD_MAX
      s_nBx := XR - i * 0.1
      s_nBy := FT + 7.5
      s_nVx := SPD_MAX
      s_nVy := 0
      nRes := StepBall()
      IF nRes != 0 .OR. s_nVx >= 0
         nOk := .F.
      ENDIF
   NEXT
   Eval( bChk, nOk, "velocidade maxima nao atravessa a raquete (20 posicoes de entrada)" )

   // 8. velocidade respeita o teto
   ServeBall( 1 )
   s_nSpd := SPD_MAX
   s_nP2 := FT + 6
   s_nBx := XR - 0.2
   s_nBy := FT + 7.5
   s_nVx := SPD_MAX
   s_nVy := 0
   StepBall()
   Eval( bChk, s_nSpd <= SPD_MAX, "velocidade da bola respeita o teto" )

   // 9. saque: direcao e angulo
   nOk := .T.
   FOR i := 1 TO 200
      ServeBall( IIF( i % 2 == 0, 1, -1 ) )
      IF ( i % 2 == 0 .AND. s_nVx <= 0 ) .OR. ( i % 2 == 1 .AND. s_nVx >= 0 ) .OR. Abs( s_nVy ) > 0.26 * SPD0
         nOk := .F.
      ENDIF
   NEXT
   Eval( bChk, nOk, "saque: direcao pedida, angulo pequeno (200 saques)" )

   // 10. IA: nunca sai da quadra, vai ao centro quando a bola se afasta, facil e mais lenta que dificil
   nOk := .T.
   FOR i := 1 TO 400
      s_nBx := hb_RandomInt( 5, 75 )
      s_nBy := hb_RandomInt( FT, FT + FH - 1 )
      s_nVx := IIF( hb_RandomInt( 0, 1 ) == 0, 1, -1 ) * ( 0.5 + hb_RandomInt( 0, 150 ) / 100.0 )
      s_nVy := hb_RandomInt( -60, 60 ) / 100.0
      nPy := FT + hb_RandomInt( 0, FH - PH )
      FOR j := 1 TO 3
         y := AiStep( IIF( i % 2 == 0, 1, 2 ), j, nPy, AiError( j ) )
         IF y < FT .OR. y > FT + FH - PH
            nOk := .F.
         ENDIF
      NEXT
   NEXT
   Eval( bChk, nOk, "AiStep sempre dentro da quadra (400 estados x 3 niveis)" )
   // bola se afastando da direita: alvo e o centro da quadra
   s_nBy := FT + 2
   s_nVy := 0
   s_nVx := -1.0
   s_nBx := 40
   nPy := FT + 0.0
   Eval( bChk, AiStep( 2, 3, nPy, 0 ) > nPy, "IA com a bola se afastando volta ao centro" )
   // velocidades: dificil anda mais por tick que facil
   s_nVx := 1.0
   s_nVy := 0
   s_nBx := 60
   s_nBy := FT + FH - 1
   Eval( bChk, ( AiStep( 2, 3, FT + 0.0, 0 ) - FT ) > ( AiStep( 2, 1, FT + 0.0, 0 ) - FT ), "IA dificil e mais rapida que facil" )
   // facil nao reage com a bola longe
   s_nBx := 10
   s_nVx := 1.0
   nPy := FT + ( FH - PH ) / 2.0
   Eval( bChk, Abs( AiStep( 2, 1, nPy, 0 ) - nPy ) < 0.26, "IA facil ignora a bola distante (fica no centro)" )

   // 11. simulacao: 300 pontos CPU x CPU; a bola nunca sai das paredes e todo ponto termina
   nOk := .T.
   nPoints := 0
   s_lBot := .T.
   s_nDiffL := 2
   s_nDiff := 2
   FOR i := 1 TO 300
      ServeBall( IIF( i % 2 == 0, 1, -1 ) )
      s_nP1 := FT + 6
      s_nP2 := FT + 6
      s_nErr1 := 0
      s_nErr2 := 0
      nRes := 0
      nTicks := 0
      DO WHILE nRes == 0 .AND. nTicks < 20000
         MovePaddles()
         nRes := StepBall()
         IF s_nBy < FT - 0.0001 .OR. s_nBy > FT + FH - 1 + 0.0001
            nOk := .F.
            nWall++
         ENDIF
         nTicks++
      ENDDO
      IF nRes == 0
         nOk := .F.
         nStuck++
         nMaxRally := Max( nMaxRally, s_nRally )
      ELSE
         nPoints++
         nMaxRally := Max( nMaxRally, s_nRally )
      ENDIF
   NEXT
   s_lBot := .F.
   cLog += "info  simulacao: pontos=" + hb_ntos( nPoints ) + " paredes_violadas=" + hb_ntos( nWall ) + ;
      " sem_fim=" + hb_ntos( nStuck ) + " maior_rally=" + hb_ntos( nMaxRally ) + hb_eol()
   Eval( bChk, nOk .AND. nPoints == 300, "300 pontos CPU x CPU terminam sem a bola sair pelas paredes" )

   // 12. nomes de som e WAVs
   s_lSnd := .T.
   InitSound()
   FOR EACH cWav IN { "coin", "paddle1", "paddle2", "paddle3", "wall", "count", "go", "score", "win", "lose", "pause", "hiscore" }
      a := hb_MemoRead( s_cTmp + "pong_" + cWav + ".wav" )
      i := Bin2L( SubStr( a, 41, 4 ) )
      Eval( bChk, Left( a, 4 ) == "RIFF" .AND. SubStr( a, 9, 4 ) == "WAVE" .AND. i == Len( a ) - 44 .AND. ;
         Bin2L( SubStr( a, 5, 4 ) ) == Len( a ) - 8 .AND. hb_HHasKey( s_hDur, cWav ) .AND. s_hDur[ cWav ] > 0, "WAV " + cWav )
   NEXT
   // nomes do tom da rebatida: todo offset de -1 a +1 gera um WAV existente
   nOk := .T.
   FOR i := -20 TO 20
      IF ! hb_HHasKey( s_hDur, PaddleSfx( i / 20.0 ) )
         nOk := .F.
      ENDIF
   NEXT
   Eval( bChk, nOk .AND. PaddleSfx( 0 ) == "paddle1" .AND. PaddleSfx( 0.5 ) == "paddle2" .AND. PaddleSfx( -1 ) == "paddle3", "PaddleSfx: tons por ponto de contato, todos existentes" )
   Eval( bChk, SignOf( 3 ) == 1 .AND. SignOf( -2 ) == -1 .AND. SignOf( 0 ) == 0, "SignOf" )
   // simetria: a face direita fica adjacente a raquete (nao dentro dela), como a esquerda
   Eval( bChk, XL == PL0 + 2 .AND. XR == PR0 - 1, "faces das raquetes simetricas e fora das raquetes" )
   ServeBall( 1 )
   Eval( bChk, Int( s_nBx + 0.5 ) == FL + Int( FWID / 2 ), "saque na coluna da rede" )
   s_nBusyUntil := 1000
   s_nBusyPrio := 3
   Eval( bChk, ! CanPlay( 2, 500 ) .AND. CanPlay( 3, 500 ) .AND. CanPlay( 5, 500 ) .AND. CanPlay( 1, 1500 ), "prioridade de efeitos" )

   // 13. timer: a melhor de 3 medicoes (uma unica amostra varia com a carga do computador)
   nT0 := 999999
   FOR j := 1 TO 3
      y := TickMs()
      FOR i := 1 TO 30
         SleepMs( 2 )
      NEXT
      nT0 := Min( nT0, TickMs() - y )
   NEXT
   cLog += "info  30 x SleepMs(2), melhor de 3 = " + hb_ntos( nT0 ) + " ms" + hb_eol()
   Eval( bChk, nT0 < 200, "TimerRes(1) + Sleep nativo: precisao de ~1-2 ms" )

   cLog += "falhas=" + hb_ntos( nBad ) + hb_eol()
   hb_MemoWrit( hb_DirBase() + "pong_selftest.log", cLog )
   ErrorLevel( IIF( nBad == 0, 0, 1 ) )

RETURN

// perfil de tempo por etapa do tick (so no modo bot): soma o tempo ate a proxima marca
STATIC PROCEDURE Stage( cName )

   LOCAL nNow

   IF s_lBot
      nNow := TickMs()
      IF s_cStage != NIL
         s_hProf[ s_cStage ] := IIF( hb_HHasKey( s_hProf, s_cStage ), s_hProf[ s_cStage ], 0 ) + nNow - s_nStageT
      ENDIF
      s_cStage := cName
      s_nStageT := nNow
   ENDIF

RETURN
