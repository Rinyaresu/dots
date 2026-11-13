# Usar o desktop

Faça login com senha no console. Execute `startx` para i3 ou `niri-session` para
niri. Encerre a sessão gráfica antes de iniciar a outra. As duas compartilham o
mesmo usuário e os serviços nativos de sessão do systemd.

A configuração não abre um desktop sozinha. i3 é a sessão de confiança e niri
com Noctalia é a sessão experimental. Nenhuma delas importa a configuração do
CachyOS.

## Usar os atalhos

Super é a tecla Windows do teclado.

| Atalho | Ação |
| --- | --- |
| Super+Enter | Abrir Ghostty |
| Super+D | Abrir o launcher da sessão |
| Super+C | Mostrar o histórico de clipboard |
| Super+Shift+L no i3, Super+Alt+L no niri | Bloquear a tela |
| Super+Shift+Q no i3, Super+Q no niri | Fechar a janela |
| Super+1 até Super+9 | Selecionar workspace numérico |
| Super+Shift+número no i3, Super+Ctrl+número no niri | Mover para o workspace correspondente |
| Print | Selecionar uma captura de tela |

No i3, Super+Shift+Delete limpa o histórico CopyQ. No niri, use a ação nativa de
limpeza no painel de clipboard. Os modelos de workspace dos dois programas são
diferentes. O niri usa workspaces dinâmicos e colunas. Super+O abre seu overview.
Super+Shift+/ mostra a ajuda de atalhos. Super+0 seleciona o workspace 10 apenas
no i3. O niri não tenta reproduzir todos os atalhos do i3.

Super+Shift+E pede o encerramento da sessão pelo mecanismo nativo de cada
programa. O objetivo é voltar ao console, não desligar o PC.

## Bloquear e suspender

A tela bloqueia após dez minutos de inatividade e antes da suspensão. O bloqueio
manual usa Super+Shift+L no i3 e Super+Alt+L no niri.
Digite a senha do usuário para desbloquear.
Não configurei suspensão ou desligamento dos monitores por inatividade.
Hibernação e suspensão híbrida estão desativadas.

O i3 usa i3lock, xss-lock e Dunst. O niri usa o bloqueio e as notificações de
Noctalia. O guia não substitui a verificação da suspensão e retomada no hardware.

## Escolher o destino de uma captura

No i3, Print abre Flameshot. Selecione a área e use a ação de copiar ou salvar.
Os botões de upload não fazem parte da configuração.

No niri, Print abre a seleção nativa. Depois de selecionar, use Ctrl+C para
copiar sem gravar em disco. Use Espaço ou Enter para salvar. O diretório
configurado é `~/Pictures/Screenshots`. Ctrl+Print captura a tela inteira e
Alt+Print captura a janela. Não há upload automático.

## Entender o histórico de clipboard

Em uma conta nova, CopyQ recebe uma configuração inicial com limite de cem
entradas de texto e exclusão de imagens do histórico. Esse arquivo é mutável
para permitir ajustes pelo próprio CopyQ. Se já existir uma configuração do
programa no home, ela é preservada e precisa ser revisada. Um rebuild não
reescreve essas preferências.
Noctalia mantém texto e imagens no niri. Seu limite de cem entradas não inclui
os itens fixados.

O histórico CopyQ não tem criptografia em repouso. Noctalia depende do Secret
Service desbloqueado para persistência cifrada. GNOME Keyring fornece esse
serviço e não substitui o ssh-agent. A senha de login da conta e a senha do
keyring precisam continuar compatíveis para o desbloqueio por PAM.

Não configurei sincronização externa do clipboard. Evite copiar segredos para
um histórico persistente. A tela de bloqueio não apaga o histórico armazenado.
