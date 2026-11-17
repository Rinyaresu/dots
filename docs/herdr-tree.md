# Reproduzir a TreeView do Herdr

Use este procedimento somente no host que executa o servidor Herdr e os Pi.
Acesso remoto a esse servidor não exige outro Algorant no computador da tela.
O cliente Herdr 0.9.5 lê as linhas da sidebar de sua configuração local.
Para mostrar os branches remotos no notebook, aplique somente o layout abaixo
no cliente, preservando seus atalhos, após inspeção e autorização.
Não execute os comandos de instalação em um pane remoto sem conferir `hostname`,
usuário e socket. Alterar fontes não autoriza ativação.

## Escolher o destino e a fonte

| Ambiente | Configuração e aplicação | Algorant |
| --- | --- | --- |
| Desktop CachyOS atual, hostname `cachyos`, usuário `rinyaresu` | `Rinyaresu/dev`, arquivo `env/.config/herdr/config.toml`, aplicado após revisar o diff com `~/.config/herdr/config.toml`. | Instalado no servidor local. |
| Desktop NixOS declarado, ainda não instalado | Este flake. `modules/hosts/desktop/home.nix` importa `home.herdr-tree`, que inclui `home.herdr`. Home Manager gera `herdr/config.toml`. | Instalação gerenciada imperativa após ativar HM e iniciar Herdr. |
| Notebook Ubuntu `umanni`, usuário `kaique` | Continua no mecanismo de `Rinyaresu/dev`. Não há perfil Ubuntu neste flake. Preserve config, atalhos e políticas corporativas. | Somente se usar Pi com filhos no servidor Herdr local e houver autorização para instalar. Para conectar ao desktop, não instalar outro subscriber. |
| Ordis NixOS | Raiz `host-ordis`, sem Home Manager, Pi ou Herdr. | Não instalar. Administrar por SSH não exige TreeView no servidor. |
| Lab NixOS | Continua importando somente `home.herdr`. | Não recebe TreeView ou credenciais pessoais. |

O `dots` contém o histórico e os módulos trazidos do `nix`. Não importa o
checkout `~/personal/nix` durante avaliação. O bootstrap pessoal ainda restaura
`Rinyaresu/home` e `Rinyaresu/agent` separadamente, somente quando ausentes.
Não importa dotfiles do `dev`. Não aplique `dev-env` sobre arquivos geridos por
Home Manager. Consulte [a composição](estrutura.md) e [o bootstrap](bootstrap.md).

A TreeView é uma projeção da seção Agents nativa, não parentage estrutural ou
collapse de subárvores. Ela não deve filtrar agentes independentes.

## Preparar versões e preservar o estado

A combinação validada usa Herdr 0.9.5, protocolo 22, e estas revisões:

- `Rinyaresu/pi-subagent` em `71c959a995b6d23f2bb37f298931af475414ba86`.
- `Algorant/herdr-agent-tree` em `c14c3ee4fa9fa709b4e6e984fc53f47cd9bc2a28`.

O commit do fork foi criado localmente. Ele precisa ser publicado ou transportado
por Git antes que outra máquina possa obtê-lo. Não substitua a revisão por `main`
ou `latest` para contornar uma revisão ausente. Preserve os repositórios privados.

Esse pin reproduz a TreeView sobre a base versionada do fork, não todas as
mudanças locais do desktop. Ele não inclui o áudio, workspace separado por filho
ou a exclusão local de `ask_user_question` nos filhos. Guardar um backup dessas
mudanças não preserva seu comportamento depois de trocar o pacote. Não aplique
o pin no desktop ou em outro checkout com essas funcionalidades em uso antes
de reconciliá-las em trabalho próprio revisado. O checkout ativo foi mantido.
A instalação limpa abaixo reproduz somente a integração TreeView versionada.

1. Confira `hostname`, `id -un`, `herdr --version` e `herdr status server --json`.
   Confirme o socket explícito do servidor local. Não reinicie um servidor ativo.
2. Confira `herdr plugin list --json`. Algorant deve ser o único projetor de
   Agents. Annotate não projeta essa view e pode continuar habilitado.
3. Faça um probe com source que nunca será proprietário. Esse probe é uma escrita
   condicional da API, não um getter. Herdr 0.9.5 preserva uma view de outro source.

   Defina `socket` com o caminho conferido em `herdr status server --json`.

   ```sh
   SOCKET="$socket" python3 - <<'PY'
   import json, os, socket
   with socket.socket(socket.AF_UNIX) as s:
       s.settimeout(3)
       s.connect(os.environ["SOCKET"])
       s.sendall((json.dumps({"id": "tree-preflight", "method": "agent.view.clear",
                            "params": {"source": "plugin:agent-tree-probe"}}) + "\n").encode())
       with s.makefile() as stream:
           response = json.loads(stream.readline(100000))
       assert "error" not in response, response.get("error")
       view = response["result"]
       assert not view.get("active") or (
           view.get("source") == "plugin:agent-tree" and view.get("label") == "tree"
       ), "Outra view de Agents está ativa; pare sem substituir seu proprietário"
       print(view)
   PY
   ```

   Aceite ausência de view ou a view esperada `plugin:agent-tree` com label `tree`.
   Outro source ou label exige parar. Nesta revisão, Algorant pode retomar a
   view depois de perder a propriedade. Não habilite dois projetores.
4. Fora dos repositórios, guarde before e planned das configurações e o registro
   filtrado do plugin. Confira os backups byte a byte antes da primeira edição.
   Registre cada estágio, a raiz gerenciada, o binário, socket e state dir.
   Não copie sessões, catálogos de máquinas, logs ou `plugins.json` para Git.
5. Não recarregue Pi ocupado. A instalação do plugin não requer reload de Pi.
   Um Pi que já carregou uma versão antiga do publisher só deve usar `/reload`
   quando estiver ocioso. Não encerre filhos existentes para migrá-los.

## Instalar o publisher pelo gerenciador do Pi

Após disponibilizar o commit, use o mecanismo de pacotes existente do Pi:

```sh
pi install git:github.com/Rinyaresu/pi-subagent@71c959a995b6d23f2bb37f298931af475414ba86
```

Se o fork já estiver no checkout gerenciado do Pi, confira antes seu
`git status --short` e `git rev-parse HEAD`. Não permita fetch/reset sobre
alterações locais não preservadas. Mesmo depois de guardá-las, adie a troca se
as funcionalidades independentes ainda forem necessárias. Remova da declaração de pacotes qualquer
cópia duplicada, sem remover seus arquivos de estado. No desktop atual o checkout
sujo foi preservado, não reconciliado com o novo commit.

O `agent/settings.json` continua pertencendo a `Rinyaresu/agent`, não ao `dots`.
O commit local correspondente do Agent fixa essa entrada. Revise somente a
entrada de pacote ao aplicá-lo. Não copie o settings inteiro de outra máquina,
pois provedores e particularidades podem diferir.
A instalação acima mantém a identidade Git do pacote e troca sua referência.

A implementação mantém `pi_*` e adiciona aliases somente para referências de
caminho nativas, absolutas, distintas e únicas. Os fingerprints são SHA-256 de
JSON compacto `["pi","path",path]`, sem normalizar caminhos. `agency_lead` não
é publicado. Os aliases renovam a cada 30 segundos com TTL de 120 segundos.
Shutdown aguarda publicação em curso e para renovação. A última publicação
expira, não é apagada sincronamente. Não adicione outro publisher dessas chaves.

## Aplicar o layout pelo mecanismo da máquina

No NixOS desktop, o módulo opt-in `home.herdr-tree` em
`modules/features/herdr.nix` acrescenta texto declarativo antes das seções
existentes de Herdr e instala Cargo e Rust do lock do flake. Não cria um daemon,
registry de plugins ou tarefa de instalação na ativação de Home Manager.
O módulo genérico Herdr continua disponível sem a TreeView.

No CachyOS atual, a fonte existente em `dev/env/.config/herdr/config.toml`
contém somente o bloco de linhas. Compare o arquivo inteiro com a implantação
antes de aplicar somente esse diff. O runtime atual tem particularidades que a
fonte do `dev` não tem, incluindo `onboarding = false` na raiz. Não execute
`./dev-env` indiscriminadamente para implantar esta mudança.

As linhas são:

```toml
[ui.sidebar.agents]
rows = [
  ["state_icon", "$agent_tree_branch", "machine", "workspace", "tab"],
  ["agent"],
]
```

Preserve `onboarding = false` na raiz quando já configurado. Não coloque essa
opção dentro de `[ui]`. Preserve `prefix+t` do Annotate. Não adicione o toggle
opcional do Algorant nem execute `scripts/activate-managed.sh`, `just deploy`
ou outro deploy script. O layout vazio de branch mantém as linhas nativas
legíveis mesmo sem o plugin.

Depois de conferir o diff aplicado, execute `herdr config check`. Só recarregue
configuração quando a validação passar. Reload de configuração Herdr não é
reload de Pi nem reinício do servidor.

## Instalar e ativar o plugin gerenciado

Confira primeiro `herdr plugin list --plugin agent-tree --json`. Uma instalação
já aplicada deve ter `source.kind=github`, owner `Algorant`, repo
`herdr-agent-tree`, `requested_ref` e `resolved_commit` iguais ao SHA abaixo.
Confira também `git -C <plugin_root> rev-parse HEAD` e arquivos-fonte sem diff.
Se a mesma revisão já está ativa, com subscriber comprovado e view `tree`, não
reinstale nem recarregue. Esse é o caminho de repetição sem efeitos.

Se estiver ausente, instale a revisão exata:

```sh
herdr plugin install Algorant/herdr-agent-tree \
  --ref c14c3ee4fa9fa709b4e6e984fc53f47cd9bc2a28 --yes
```

Herdr executa `cargo build --locked --release` na fonte gerenciada. Em uma
máquina limpa, prepare Git, Cargo/Rust e toolchain nativa antes dessa etapa.
O desktop NixOS seleciona GCC pela toolchain e Cargo e Rust por `home.herdr-tree`.
No CachyOS, prepare-os pelo mecanismo de pacotes da máquina. O build gerenciado
do plugin não é uma derivação Nix reproduzível bit a bit. A revisão da fonte e Cargo.lock
são fixos. A instalação é imperativa porque Herdr gerencia seu próprio catálogo,
actions e subscriber por socket. Não versione esse estado mutável.

Install ou enable em servidor já iniciado não prova projeção ativa.
Se a configuração ainda não está aplicada, deixe o plugin disabled até validá-la.
Depois, confirme novamente que não apareceu outro projetor e execute:

```sh
herdr config check
herdr server reload-config
herdr plugin enable agent-tree
herdr plugin action invoke agent-tree.reload
```

Guarde o `log_id` da resposta. Consulte `herdr plugin log list --plugin agent-tree`
e aguarde esse mesmo log terminar com `status=succeeded`. Resposta inicial
`ok` ou timeout não certifica conclusão. Um resultado pendente impede avançar.

Confira pelo probe que a view está ativa com `source=plugin:agent-tree` e
`label=tree`. Comprove exatamente um subscriber pela identidade descrita abaixo.
Compare agentes, sessões, terminais, estados e `pi_*` com o baseline, sem imprimir
caminhos de sessões, tarefas ou conversas. Na seção Agents do cliente efetivamente
usado, confirme visibilidade, linhas preservadas, clique e navegação com foco no
terminal correto. Snapshot global não prova foco local de todo cliente conectado.
Não crie uma tarefa com modelo somente para produzir filhos de demonstração.

## Atualizar sem trocar a revisão silenciosamente

Uma mudança de revisão exige atualizar este pin, revisar o upstream e repetir
as verificações em ambiente isolado antes de qualquer aplicação real. Preserve
before, planned, plugin anterior e identidade do subscriber. Pare o subscriber
antigo de forma comprovada antes de substituir seu checkout. Instale a nova
revisão com `--ref` explícito. Ative com `agent-tree.reload` e aguarde a action.
Não use `herdr update` como atualização do plugin ou do fork.

## Reverter conforme o estágio alcançado

Mantenha esta sequência fora de qualquer trap genérico. O lock esperado fica
em `${XDG_STATE_HOME:-$HOME/.local/state}/herdr/plugins/agent-tree/`, com nome
`subscriber-<16 primeiros hex de SHA-256 do socket>.lock`. O lock é uma pista,
não prova de identidade. Falta de lock não comprova falta de processo.

| Estágio | Recuperação |
| --- | --- |
| Antes de instalar | Não invoque actions de plugin ausente. Restaure somente arquivos efetivamente alterados e ainda iguais à planned ou before. |
| Instalado, não ativado | Verifique independentemente ausência de subscriber e actions terminadas. Deixe disabled. Não sinalize processo inexistente. |
| Config aplicada, sem subscriber iniciado | Comprove ausência por inventário, não pelo lock. Se houver tokens próprios residuais, execute clear síncrono. Restaure somente alterações reconhecidas e recarregue config. |
| Subscriber iniciado e identidade comprovada | Disable impede hooks futuros, mas não é parada. Encerre somente o processo comprovado por pidfd, confira saída e novo inventário, depois execute clear síncrono. |
| Identidade desconhecida, processo opaco ou action pendente | Pare a recuperação com status pendente. Não mate por nome ou PID isolado, não remova locks e não declare rollback concluído. Obtenha leitura administrativa ou intervenção do operador para comprovar identidade. |

Para comprovar presença ou ausência, examine os processos do UID esperado no
namespace correto com dois detectores independentes. Um usa executável e argv;
outro usa ambiente `HERDR_PLUGIN_ID=agent-tree`, `HERDR_SOCKET_PATH`,
`HERDR_PLUGIN_ROOT` e `HERDR_PLUGIN_STATE_DIR`. Compare com os caminhos exatos
registrados da instalação. Um `/proc` ilegível impede concluir ausência. Faça dois
inventários completos com plugin disabled, instalador encerrado e nenhuma action
em execução. Não use somente `pgrep`, falta de lock ou um único PID salvo.

Para comprovar um candidato, exija UID correto, executável `<plugin_root>/target/
release/agent-tree`, argv com `subscriber`, contexto exato do plugin e socket e
state dir registrados. Confira o start time de `/proc/<pid>/stat`, abra um pidfd
e revalide tudo antes de sinalizar. Aguarde saída pelo pidfd. Não use `killall`,
`pkill`, nome de processo ou `kill <pid>` sem essas verificações. Se o lock sumiu,
um processo ainda pode ser comprovado por essas mesmas evidências. Um lock que
aponta processo divergente nunca autoriza sinal.

Depois de comprovar ausência do subscriber, execute `clear` de forma síncrona
pelo launcher original com o contexto explícito. Os valores abaixo devem vir
da instalação conferida, não de um PID ou caminho de outra máquina:

```sh
HERDR_PLUGIN_ID=agent-tree \
HERDR_PLUGIN_ROOT="$plugin_root" \
HERDR_PLUGIN_STATE_DIR="$state_dir" \
HERDR_SOCKET_PATH="$socket" \
  "$plugin_root/src/agent-tree" clear
herdr plugin disable agent-tree
```

`clear` remove tokens próprios de saída e limpa a view com source guard.
Os aliases de entrada `role` e `agency_*` pertencem ao fork e expiram conforme
seu publisher. Não os remova como se pertencessem ao Algorant. Não remova tokens
alheios. Subscriber ativo pode republicar decorações sem TTL, portanto clear
antes de comprovar a parada não basta. Disable sozinho também não basta.

Restaure cada config somente se seus bytes ainda coincidirem com a imagem planned
ou já forem iguais à before. Se houver edição concorrente, preserve o arquivo e
resolva o diff com o operador. Em HM, retire `home.herdr-tree` e importe `home.herdr`
na fonte, avalie e faça a ativação autorizada da geração. Não escreva sobre um
symlink do Nix store. Em `dev`, retire somente o bloco TreeView na fonte e aplique
apenas esse diff revisado, preservando as demais particularidades da implantação.

Valide config, recarregue, confira view nativa, ausência dos tokens próprios e
navegação no cliente correto. Confira novamente que não houve republicação.
Mantenha o plugin disabled ou, depois dessas verificações, use o uninstall nativo.
Reverter o fork é uma decisão separada. Pare sua renovação somente por reload
em Pi ocioso ou fim natural da sessão e aguarde o TTL. Preserve os `pi_*`.
