# Trabalhar nos projetos

Os ambientes são explícitos por sessão. Abrir Fish, Ghostty, Herdr ou Neovim não
instala Ruby, Node, gems ou pacotes do projeto.

## Pi e suas configurações

O Pi 1.5.0 é instalado pela fonte oficial, fixada no `flake.lock`, com o mesmo
nixpkgs estável do sistema. O Node 24 usado pelo pacote não entra no PATH global.
`PI_NODE_BIN` aponta para esse runtime para o launcher dos seus subagentes.

O pacote oficial dessa versão omite `pi-schema` na lista de dependências
substituídas no build Nix. O módulo fornece esse pacote 1.5.0 do npm com hash
fixo, sem acrescentar outra linha de nixpkgs.

Somente o host físico ativa `pi-config-restore`. Após login, o serviço espera
você carregar explicitamente a chave SSH.

```sh
ssh-add
systemctl --user status pi-config-restore
```

Com a chave carregada e a rede disponível, o serviço restaura primeiro o
repositório privado `git@github.com:Rinyaresu/home.git`, branch `main`, em
`~/personal/home`, e depois `git@github.com:Rinyaresu/agent.git`, branch `main`,
em `~/.pi`. Cada destino é verificado independentemente: um checkout existente
não impede a restauração do outro. Antes de restaurar Agent, o serviço exige
`~/personal/home/references/personal.md`; se o Home existente não passar nessa validação,
a execução falha e preserva o destino. Destinos existentes, inclusive symlinks,
e destinos que apareçam durante o clone nunca são substituídos. O serviço verifica
a chave pública do GitHub e não pede senha ou confirmação em background. Uma falha
de rede ou autenticação é tentada novamente após 30 segundos.

Espere a mensagem de restauração concluída antes de abrir `pi` pela primeira vez.
Um `~/.pi` já existente, inclusive um symlink, é preservado sem merge, pull ou
sobrescrita. Se abriu o Pi antes e ele criou essa pasta, revise o conteúdo antes
de decidir como restaurar; o serviço não a apaga. Consulte os detalhes com
`journalctl --user -u pi-config-restore`.

Depois do clone, suas configurações continuam editáveis e o serviço não as
atualiza automaticamente. Atualizações do Pi são feitas pelo Nix. Atualizações
do seu repo de configuração continuam sendo operações Git explícitas.

Credenciais, sessões e dependências ignoradas pelo Git não fazem parte do clone.
Refaça os logins no Pi. O próprio Pi instala os pacotes declarados nas suas
configurações ao iniciar; isso pode precisar de rede. Dependências adicionais de
scripts das skills podem precisar de instalação separada.

## Usar mise em um projeto existente

Entre no diretório e confira a configuração do projeto antes de confiar nela.

```fish
mise trust
mise install
mise activate fish | source
```

`mise install` é uma operação explícita e pode acessar a rede. Os runtimes seguem
as versões do projeto. Não configurei versões globais de Ruby ou Node.
A ativação dura aquela sessão Fish. O hook não é ativado nas outras janelas ou
panes, mas processos filhos podem herdar variáveis e PATH. Feche a sessão para
voltar a um ambiente neutro.

Para compilar gems nativas, abra uma shell com as dependências Nix antes de ativar
mise no projeto.

```sh
nix --extra-experimental-features 'nix-command flakes' develop \
  'path:/etc/nixos' -c fish
```

A shell fornece compilador, pkg-config, OpenSSL, libyaml, zlib, libpq e libffi.
Ela não contém Ruby ou Node e não cria arquivos no projeto. `/etc/nixos` é o
caminho do guia de instalação. Ajuste-o se mantiver o repo em outro diretório. Os módulos nix-ld e envfs atendem dependências já validadas, mas não
garantem compatibilidade com qualquer executável externo.

## Usar direnv em um projeto pessoal

Use outra sessão Fish, sem ativar mise nela. Revise a `.envrc` e autorize apenas
se confiar no conteúdo.

```fish
direnv allow
direnv hook fish | source
```

O hook automático distribuído pelo pacote está mascarado. Não configurei os dois
provedores como hooks globais. Uma `.envrc` pode executar código, não é apenas
uma lista de variáveis.

## Abrir Herdr

Execute `herdr` em um terminal neutro, antes de ativar mise ou direnv, e ative o
provedor somente na pane do projeto. Não há autoattach nem daemon iniciado pelo
login. O shell das panes é Fish.

Se iniciar o servidor Herdr a partir de um ambiente de projeto já ativo, os
processos filhos podem herdar esse ambiente. Não acrescentei um wrapper que tente
adivinhar e remover variáveis. Inicie o Herdr de um terminal neutro para não
propagar dependências de um projeto para as outras panes.

## Editar com Neovim

Execute `nvim`. A configuração mantém as opções nativas de edição, inclusive
indentação, numeração e completion. Rosé Pine Dawn é o único plugin de aparência.
Não há distribuição de IDE ou gerenciador de plugins em runtime.
Fish usa seu prompt e sua mensagem inicial nativos. Herdr mantém o onboarding.

LSP nativo está configurado para JavaScript, TypeScript, JSX, TSX, Nix e Bash.
O servidor TypeScript depende do TypeScript preparado no projeto. Ele não instala
as dependências automaticamente. Os diagnósticos não escrevem texto no fim das
linhas.

Use os atalhos nativos de LSP do Neovim. Não acrescentei um segundo conjunto de
mapeamentos ou alterei a tecla líder.

| Atalho | Ação |
| --- | --- |
| `Ctrl+]` | Ir à definição com o tagfunc do LSP conectado |
| `K` | Mostrar documentação |
| `grr` | Consultar referências |
| `grn` | Renomear símbolo |
| `gra` | Pedir ação de código |
| `Ctrl+x`, `Ctrl+o` em inserção | Pedir completion nativa |

Ruby LSP automático e formatação ao salvar ficaram adiados nesta entrega.
Essa decisão prioriza o pedido mais recente de uma configuração pequena e evita
instalação de gems no início do editor. Isso é uma diferença em relação ao plano
anterior de formatar quando o projeto define um formatador. Salvar nunca depende
de servidor ou formatador.

A integração Ruby pode ser acrescentada depois com um bundle explicitamente
preparado no Ruby do projeto. Não execute `ruby-lsp` diretamente sem verificar o
bootstrap do bundle, pois sua inicialização padrão pode instalar gems.
