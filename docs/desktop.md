# Usar o desktop

Faça login com senha no console e execute `niri-session`. Niri com Noctalia é a
sessão principal. i3 é a alternativa de recuperação, iniciada por `startx`.
Encerre uma sessão antes de iniciar a outra. Não há display manager ou autologin.

O desktop usa layout de monitores e modos próprios em `modules/hosts/desktop/home.nix`.
Esses conectores e frequências dependem de validação no hardware. A capacidade
compartilhada niri não impõe esse hardware ao lab.

## Atalhos

Super é a tecla Windows.

| Atalho | Ação |
| --- | --- |
| Super+Enter | Abrir Ghostty, com autoattach Herdr em terminal gráfico |
| Super+D | Abrir launcher |
| Super+C | Abrir histórico de clipboard |
| Super+Shift+Q | Fechar janela |
| Super+Alt+B | Teclado brasileiro |
| Super+Alt+U | Teclado US internacional |
| Super+1 até Super+9 | Selecionar workspace |
| Super+Shift+número | Mover coluna niri ou janela i3 ao workspace |
| Print | Capturar região e anotar |
| Super+Shift+Delete | Limpar histórico não fixado no niri, histórico CopyQ no i3 |
| Super+Shift+E | Encerrar sessão gráfica, sem desligar o PC |

No niri, Super+H e Super+L focam colunas. Super+J e Super+K focam janelas da
coluna. Acrescente Shift para mover. Super+R muda largura, Super+F alterna tela
cheia e Super+Shift+F maximiza coluna. Super+Shift+Espaço alterna janela flutuante.
Super+O abre overview e Super+Shift+/ mostra ajuda.
Essas ações respeitam o modelo niri, não reproduzem a árvore de containers i3.

O teclado padrão é US internacional. O console mantém configuração própria a
validar, inclusive acentos e digitação de senha. Atalhos gráficos não mudam o
layout do console.

## Bloqueio e inatividade

A tela bloqueia após dez minutos e antes de suspender. Monitores apagam após
quinze minutos, sem suspender o computador. Não há hibernação, suspensão híbrida
ou suspensão automática por inatividade.

Super+Alt+L bloqueia tanto no niri quanto no i3.
Notificações não devem aparecer na tela bloqueada. Aplicativos, agentes de
terminal e acesso remoto devem continuar funcionando enquanto o PC está acordado.
Valide bloqueio real, retomada, KVM, monitores e notificações nas duas sessões.
A declaração não comprova esses efeitos físicos.

## Captura com edição

No niri, Print seleciona uma região por Slurp, captura com Grim e abre Satty.
Enter no editor salva o resultado em `~/Pictures/Screenshots` e copia a imagem
editada. Cancelar a seleção ou fechar sem exportar não cria arquivo final nem
substitui o clipboard. Arquivos intermediários ficam no diretório runtime privado.
Ctrl+Print e Alt+Print continuam usando capturas nativas de monitor e janela.
No i3, Print usa Flameshot como alternativa.

Confira a imagem salva e cole-a em outro aplicativo para validar o caminho
completo. Testes com ferramentas simuladas provam o encadeamento e o cancelamento,
mas não comprovam pixels ou integração gráfica real.

## Clipboard, aparência e áudio

Noctalia mantém texto e imagens, com cem entradas e Secret Service para
persistência cifrada. CopyQ no i3 inicia com cem entradas de texto, sem imagens.
Uma configuração CopyQ já existente é preservada e precisa de revisão.
CopyQ não cifra seu histórico em repouso. Bloquear a tela não apaga o histórico.
Evite copiar segredos. Não há sincronização externa configurada.

GNOME Keyring tenta desbloquear o cofre de sessão com a senha de login.
A senha do keyring precisa corresponder. O primeiro uso pode pedir desbloqueio.
Isso não desbloqueia Bitwarden nem remove a passphrase SSH.

A base visual é clara Rosé Pine Dawn, sem alternância automática para escuro.
Ghostty usa IosevkaTerm Nerd Font tamanho 15. Decorações e transparência não são
cópias cegas de opções X11. Aplicativos podem manter preferências próprias.

A luz noturna usa Noctalia no niri e Redshift no i3, com 5900 K de dia e 2600 K
à noite. As transições graduais diferem entre implementações.
Use a interface para escolher dispositivos PipeWire e WirePlumber.

Discord inicia ao entrar na sessão. Não há autostart dos demais aplicativos
pessoais. Firefox é padrão, Chrome é secundário. Compartilhamento em Discord,
OBS e Meet exige testes separados de imagem e áudio recebidos ou gravados.
Abertura do seletor de portal não é prova de compartilhamento bem-sucedido.
