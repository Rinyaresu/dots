# Trabalhar nos projetos

Fish integra mise e direnv em shells interativos. Entrar no projeto não autoriza
instalar runtimes ou executar uma `.envrc` não aprovada.

## Autorizar o ambiente

Revise a configuração mise antes de `mise trust`. Instale as versões declaradas
somente com uma ação explícita, como `mise install`. A configuração desabilita
instalação automática nos hooks, no comando ausente, em exec e nas tarefas.
Não define versões globais de Node ou Ruby.

Revise a `.envrc` antes de `direnv allow`. Uma alteração exige nova autorização.
O hook recarrega o ambiente ao entrar e restaura o ambiente anterior ao sair.
Não use mise e direnv para controlar os mesmos runtimes no mesmo projeto.
Uma `.envrc` executa código, não apenas atribuições de variáveis.

Para dependências nativas, use a devShell declarada. Ela fornece compilador,
pkg-config e bibliotecas, mas não instala runtimes do projeto.

```sh
source=$(python3 -B scripts/export-source.py)
nix --extra-experimental-features 'nix-command flakes' develop "path:$source" -c fish
```

`nix-ld` e `envfs` ajudam executáveis externos. Eles não garantem compatibilidade
com toda ferramenta Linux. Teste as ferramentas reais do projeto.

## Usar Herdr

Terminais gráficos interativos entram no Herdr automaticamente. O console continua
livre para `niri-session`, `startx` e recuperação. Scripts e shells SSH não fazem
autoattach. Panes existentes não entram em outra sessão Herdr.
Para uma shell comum, use `HERDR_NO_AUTO=1 fish`.

O wrapper inicia o cliente com o ambiente de projeto removido pelos hooks nativos
de mise e direnv, sem mudar a shell pai. Cada pane Fish ativa o ambiente de seu
próprio diretório. Isso não remove variáveis arbitrárias exportadas manualmente.
Um servidor Herdr iniciado antes por outro caminho pode conservar ambiente antigo.
Não encerre servidores com agentes em execução para testar essa situação.

O Herdr já preserva processos quando o cliente fecha ou a conexão cai.
Esta configuração não acrescenta daemon, linger ou política de sobrevivência a
reboot. Encerrar todo o login é uma validação separada de integração no NixOS.

## Desbloquear SSH

O desktop usa um agente OpenSSH. A primeira operação que precisa da chave pode
pedir sua passphrase por janela gráfica. `AddKeysToAgent` conserva a chave carregada.
Bloquear a tela não descarrega a chave nem cria expiração automática.
O cofre GNOME Keyring e o aplicativo Bitwarden não fornecem esse agente.

As sessões importam seu ambiente gráfico para o systemd do usuário. O bootstrap
usa o mesmo socket do agente, espera uma sessão disponível e solicita desbloqueio.
Cancelar não remove a passphrase ou desabilita autenticação. O serviço espera uma
chave carregada posteriormente, sem repetir o prompt a cada tentativa de clone.
Herdr fornece encaminhamento nativo do socket para suas panes. Valide uma operação
real em pane existente e pane nova após iniciar a sessão.

## Restaurar configuração Pi

Pi e Herdr vêm das fontes fixadas no lock. O bootstrap do desktop restaura Home
e depois Agent quando os respectivos destinos não existem. Home deve conter
`references/personal.md`. Destinos existentes, inclusive symlinks e destinos que
apareçam durante clone, não são sobrescritos nem atualizados.

O bootstrap usa a chave de host GitHub fixada, clone não interativo e a chave já
desbloqueada. Falhas de rede podem ser tentadas novamente. Não há pull automático
em checkouts existentes. Espere a conclusão antes de abrir Pi pela primeira vez.
Um diretório `~/.pi` criado antes disso é preservado, mesmo que esteja incompleto.
Consulte `journalctl --user -u pi-config-restore` sem publicar dados de autenticação.

Git não recupera credenciais, sessões e arquivos ignorados. Refaça os logins dos
aplicativos e revise suas dependências locais. Nenhum checkout privado é necessário
para avaliar ou construir o sistema.

## Usar Neovim

A base é pequena, com Rosé Pine Dawn, LSP nativo para Nix, Bash e JavaScript ou
TypeScript. O servidor TypeScript depende das dependências preparadas do projeto.
Não há gerenciador de plugins ou instalação de runtimes ao abrir o editor.
Reconstruir a configuração completa é trabalho separado.

Use os atalhos nativos de LSP, como `K`, `grr`, `grn` e `gra`.
A configuração não importa os plugins ou atalhos do editor anterior e não formata
automaticamente ao salvar.
