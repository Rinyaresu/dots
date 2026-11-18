# 3. Plano de reconstrução revisado

Proposta, não implementação. [Referência](01-dotnix.md) e [inventário, checks e fronteira da fonte](02-dots.md). Manter as três saídas atuais. A referência define a forma de descobrir, compor, construir e validar; o dots fornece os requisitos das máquinas.

## Home Manager: matching por nome, com base pareada

O [montador do dotnix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/nixos-configurations.nix#L26-L55) cruza as chaves escolhidas pelo host com `flake.modules.homeManager`; só importa HM se houver correspondência. [Fish](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/interfaces/cli/shells/fish.nix) contribui para as duas classes em `base`; [Git](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/interfaces/cli/git.nix) e [Nixvim](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/interfaces/cli/nixvim/use-in-home.nix) entram por `homeManager.base`. O mesmo vale para [direnv](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/interfaces/cli/shells/direnv.nix) e [Claude](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/interfaces/cli/ai/claude.nix), comparáveis por função a providers de shell e Pi, não por implementação. [VPS](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/hosts/vps/modules.nix) seleciona `base` sem `gui`: o ambiente de terminal não depende do desktop gráfico. O dotnix não oferece Herdr como contraparte; seu núcleo de multiplexer pertence à CLI, embora o autoattach do dots continue condicionado à sessão gráfica.

| Alternativa | Resultado e compromisso |
| --- | --- |
| Plano anterior: `base` só NixOS, CLI em `gui` | Evita outro grupo, mas prende a CLI à GUI. O agrupamento só refletia o fato de os dois consumidores atuais serem gráficos; não a divisão da referência. |
| `base` pareada nos PCs, `common` só NixOS | **Escolhida.** `nixos.base` importa `nixos.common` e declara a conta/shell de uso interativo. Ordis seleciona `common` diretamente e mantém a sua conta. Mais um nome, mas uma fronteira real: política do sistema sem conta de estação nem HM. |
| `base` só NixOS + novo par `cli` | Também resolve, desde que `nixos.cli` contenha configuração real de conta/shell. Tem a mesma quantidade de grupos, mas muda o significado de `base` no dotnix. |
| `base` pareada em todos, exceção HM por host | Uma flag extra filtraria o matching, divergiria da regra e poderia ocultar seleção indevida. Importar o `base` inteiro só transitivamente em Ordis não é solução: escaparia do matching, mas ainda importaria a conta e o shell dos PCs. |

| Host | Seleção direta relevante | Home Manager resultante |
| --- | --- | --- |
| desktop | `base gui i3 niri desktop-personal configuration` | `base gui i3 niri desktop-personal` |
| lab | `base gui i3 niri configuration` | `base gui i3 niri` |
| Ordis | `common ssh tailscale pihole configuration` | HM não importado |

- `nixos.common`: Nix/atualização manual, NetworkManager, locale compartilhado e sudo com senha. Sem correspondente HM. `nixos.base`: importa `common` e fornece conta/shell dos PCs. `homeManager.base`: Fish, Git, Neovim, Pi, Herdr base e providers. Comportamento gráfico do Fish continua condicionado; não introduzir credenciais nem bootstrap em base. Herdr TreeView estende Herdr no desktop; preservar os diamantes reais.
- `gui` em ambas as classes: gráficos, fontes, polkit, áudio, apps gráficos e integração de sessão. Ghostty e preferências visuais ficam aqui. Sem greeter, login automático, segredo ou restore implícito; `i3` e `niri` seguem opt-in, e display físico é local ao desktop. Um app só HM contribui para o grupo correspondente, como o Firefox da referência; não precisa de módulo NixOS vazio.
- `desktop-personal`: SOPS/SSH pessoal e ordenação no lado NixOS; link, restore, TreeView e apps apenas do desktop em HM. `homeUser` é o nome da conta nativa para a ligação HM, junto ao seletor dos dois PCs; fica ausente em Ordis. Não escolhe capacidades e não cria `config.user.name` global, aliases ou cadastro de usuários. Manter `system.stateVersion` e `home.stateVersion` independentes nos fragmentos do host (ambas ainda `26.05` na base real). Se houver correspondência sem conta, falhar com diagnóstico explícito; não importar HM incondicionalmente. Múltiplas homes por host estão fora do requisito.

### Ensaio com módulos reais

Foi avaliado um flake descartável com `mkFlake`, `flakeModules.modules`, módulos diferidos, `nixosSystem`, integração upstream do Home Manager e módulo upstream SOPS. Em Nix 2.35.5, o comando abaixo resolveu a derivação de toplevel (incluindo asserções) e as opções efetivas dos quatro casos. A associação lê apenas chaves **diretas**. No controle `transitivo`, `indirect-base` importa `nixos.base` e fornece a conta e o chão comum, mas **não** seleciona `homeManager.base`: só `gui` é pareado. Selecionar diretamente as capacidades pareadas desejadas; imports transitivos de sistema não substituem a seleção HM.

| Caso | Estado sistema / HM | Conta e Home Manager | Opções efetivas |
| --- | --- | --- | --- |
| desktop | `26.05 / 25.11` | apenas HM de `rinyaresu`, home `/home/rinyaresu`, UID NixOS 1234 | Fish/Git/Neovim e fontes HM ligados; SOPS com `fixture-ssh`, arquivo marcador TreeView e unidade de bootstrap presentes |
| lab | `25.11 / 26.05` | apenas HM de `rinyaresu`, mesma home e UID | Fish/Git/Neovim e fontes HM ligados; opção SOPS ausente, zero segredos, sem arquivo TreeView nem unidade de bootstrap |
| Ordis | `26.05 / —` | só `ordis` entre as contas do ensaio; nem a opção `home-manager` existe | NetworkManager e sudo com senha continuam ligados, X server desligado |
| transitivo | `25.11 / 26.05` | HM de `rinyaresu` pela chave direta `gui` | Fontes HM ligadas; Fish/Git/Neovim desligados e marcador CLI ausente; NetworkManager ligado pela cadeia NixOS |

`options ? user` foi falso nos quatro casos. O default efetivo de `programs.neovim.withPython3` foi `true` no desktop (`home.stateVersion = 25.11`, com avisos de default legado Ruby/Python) e `false` no lab (`26.05`), mostrando que a versão HM não segue a do sistema.

<details>
<summary>Reprodução: lock, comando e flake descartável</summary>

Na raiz do worktree, salvar o flake abaixo em `review/.hm-probe/flake.nix`. Recortar o lock a partir do commit examinado: nixpkgs `ac588ef1c914865dad517b337ea0eb9694a4021c`, flake-parts `ea2630b7470978622c7689a1ff75d2b389175399`, HM `6eb2d33d1d0c95a37ef6443c88e6c1686012ee8b`, SOPS `fe7b4228405aeac2ce7192c2049a6e2bc8637082`. O comando offline pressupõe os inputs no cache local.

```sh
mkdir -p review/.hm-probe
git show cc634483fab8256747bc739992236075e67b36b9:flake.lock |
  jq '["root","nixpkgs","flake-parts","home-manager","sops-nix"] as $keep |
      .nodes.root.inputs |= with_entries(select(.key as $k | $keep | index($k))) |
      .nodes |= with_entries(select(.key as $k | $keep | index($k)))' \
  > review/.hm-probe/flake.lock
nix --extra-experimental-features 'nix-command flakes' eval --offline \
  --no-write-lock-file --json "path:$PWD/review/.hm-probe#probe" |
  jq .
```

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { config, lib, ... }:
      let
        system = "x86_64-linux";
        os = config.flake.modules.nixos;
        hm = config.flake.modules.homeManager;
        pc = systemVersion: homeVersion: {
          system.stateVersion = systemVersion;
          home-manager.users.rinyaresu.home.stateVersion = homeVersion;
        };
        systems = lib.mapAttrs
          (host: { modules, homeUser }:
            let
              homeModules = lib.attrValues (builtins.intersectAttrs modules hm);
            in
            inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              modules = lib.attrValues modules ++ [
                {
                  networking.hostName = host;
                  boot.loader.grub.enable = false;
                  fileSystems."/" = { device = "/dev/dummy"; fsType = "tmpfs"; };
                }
              ] ++ lib.optionals (homeModules != []) [
                inputs.home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.users.${homeUser}.imports = homeModules;
                }
              ];
            })
          config.configurations.nixos;
        inspect = _: host:
          let
            c = host.config;
            h = c.home-manager.users.rinyaresu or null;
          in {
            inherit (c.networking) hostName;
            networkManager = c.networking.networkmanager.enable;
            xserver = c.services.xserver.enable;
            systemState = c.system.stateVersion;
            globalUserOption = host.options ? user;
            hmOption = host.options ? home-manager;
            accounts = builtins.filter (name: builtins.elem name ["rinyaresu" "ordis"])
              (builtins.attrNames c.users.users);
            sudoPassword = c.security.sudo.wheelNeedsPassword;
            sopsOption = host.options ? sops;
            sopsSecrets = builtins.attrNames (c.sops.secrets or {});
            hm = if h == null then null else {
              users = builtins.attrNames c.home-manager.users;
              username = h.home.username;
              homeDirectory = h.home.homeDirectory;
              uid = c.users.users.${h.home.username}.uid;
              state = h.home.stateVersion;
              fish = h.programs.fish.enable;
              git = h.programs.git.enable;
              neovim = h.programs.neovim.enable;
              neovimPythonDefault = h.programs.neovim.withPython3;
              fonts = h.fonts.fontconfig.enable;
              files = builtins.attrNames h.home.file;
              privateBootstrapUnit = h.systemd.user.services ? private-bootstrap;
            };
            toplevel = c.system.build.toplevel.drvPath;
          };
      in {
        imports = [ inputs.flake-parts.flakeModules.modules ];
        options.configurations.nixos = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options.modules = lib.mkOption { type = lib.types.attrsOf lib.types.deferredModule; };
            options.homeUser = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          });
        };
        config = {
          systems = [ system ];
          flake.nixosConfigurations = systems;
          flake.probe = lib.mapAttrs inspect systems;

          flake.modules.nixos = {
            common = {
              networking.networkmanager.enable = true;
              security.sudo.wheelNeedsPassword = true;
            };
            base = {
              imports = [ os.common ];
              users.users.rinyaresu = { isNormalUser = true; uid = 1234; };
            };
            gui.services.xserver.enable = true;
            desktop-personal = {
              imports = [ inputs.sops-nix.nixosModules.sops ];
              sops = {
                validateSopsFiles = false;
                age.keyFile = "/nonexistent/fixture-age.txt";
                defaultSopsFile = "/nonexistent/fixture.yaml";
                secrets.fixture-ssh = {};
              };
            };
            indirect-base.imports = [ os.base ];
          };
          flake.modules.homeManager = {
            base = {
              programs = {
                fish.enable = true;
                git.enable = true;
                neovim.enable = true;
              };
              home.file.".probe-cli".text = "pi, herdr, providers (marcador)";
            };
            gui.fonts.fontconfig.enable = true;
            desktop-personal = {
              home.file.".probe-treeview".text = "marcador";
              systemd.user.services.private-bootstrap.Service.ExecStart = "/bin/true";
            };
          };
          configurations.nixos = {
            desktop = {
              homeUser = "rinyaresu";
              modules = { inherit (os) base gui desktop-personal; configuration = pc "26.05" "25.11"; };
            };
            lab = {
              homeUser = "rinyaresu";
              modules = { inherit (os) base gui; configuration = pc "25.11" "26.05"; };
            };
            ordis.modules = {
              inherit (os) common;
              configuration = {
                system.stateVersion = "26.05";
                users.users.ordis = { isNormalUser = true; uid = 1235; };
              };
            };
            transitivo = {
              homeUser = "rinyaresu";
              modules = { inherit (os) indirect-base gui; configuration = pc "25.11" "26.05"; };
            };
          };
        };
      }
    );
}
```

</details>

Limites: os hosts são descartáveis, não o flake funcional; SOPS usa caminhos inexistentes com validação de ciphertext desativada. Pi, Herdr, providers e TreeView são marcadores, e o bootstrap é uma unidade inerte. Resolver `.drvPath` não realiza a derivação, inicia serviços, prova isolamento de rede/VM ou certifica paridade de runtime. Os valores de state version foram cruzados só para mostrar independência; não são alterações propostas.

## Árvore a partir da referência

```text
flake.nix
flake.lock
.github/workflows/ci.yml
modules/
  devshell/{devshell,formatting}.nix
  nix/{flake-modules,nixos-configurations,home-manager}.nix
  hosts/
    desktop/{modules,configuration,_hardware-configuration}.nix
    lab/{modules,configuration}.nix
    ordis/{modules,configuration,_hardware-configuration}.nix
  system/
    {systems,nix-settings,locale,sops,ssh,virtualisation}.nix
    boot/…
    networking/…
    storage/…
    users/…
    interfaces/{cli,gui}/…
  server/networking/pihole/…
secrets/{README.md,ssh.yaml}
README.md
AGENTS.md
```

Os diretórios `devshell`, `nix`, `hosts`, `system` e `server` seguem o catálogo real da referência. CLI, GUI, rede, boot e armazenamento recebem as capacidades na sua área, em vez de um novo diretório genérico `features`. Não criar `packages/` vazio. Checks regulares e packages de aceitação são contribuições flake-parts junto à funcionalidade; fixtures Nix brutas usam `_` e são importadas pelo consumidor. Fixtures Python e patches são arquivos auxiliares, como na referência. Um teste de isolamento de firewall do host pode morar na área da política (`system/networking`) ou junto à configuração daquele host, não requer uma terceira árvore.

| Diferença de layout | Decisão e evidência |
| --- | --- |
| `checks/` e `modules/tests/` não existem na referência | Nenhum dos dois no alvo. Colocar fixture sobrevivente ao lado da capacidade que prova. O output `packages` das VMs não justifica um diretório `modules/packages/`: a publicação fica no módulo de domínio. |
| `docs/` não existe na referência | Não criar/migrar árvore de catálogos. Usar README para um guia operacional mínimo, AGENTS para limites e prova, README de segredos para provisionamento. Matriz abaixo. |
| `secrets/` é local, não existe no dotnix | Necessário para a única entrada SOPS cifrada e revisada sem exigir o repositório privado que a referência usa no build. Nenhuma identidade dentro. |
| Fragmentos adicionais do host no plano anterior | Remover como padrão. `home.nix` vira dados de host (estado/monitores) em `configuration.nix`; seleção sai por matching. `access.nix` vira opções locais do host e SSH compartilhável em `system/ssh.nix`, sem diluir diferenças de superfície. `maintenance.nix` vira política local do desktop; `tso-experiment.nix` vira configuração local de Ordis, preservando TSO off e identidade DHCP; `pihole.nix` do host vira interface/lista/firewall em `configuration.nix`, como os ajustes de serviço de `homelab` na referência. Não separar só por tamanho; só extrair se existir consumidor independente. `_hardware-configuration.nix` mantém a fronteira literal da referência. |

## Critério de fidelidade por decisão

| Implementação exata da referência | Proposta e diferença | Motivo verificável |
| --- | --- | --- |
| [flake.nix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/flake.nix#L118-L125), `mkFlake`, import-tree e `rootPath`; [flake-modules.nix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/flake-modules.nix) importa também wrappers | Mesma descoberta e publicação; sem argumento ou input sem consumidor | Nenhuma implementação planejada exige wrappers ou caminho global. Hardware por caminho relativo já é o padrão real. |
| [Montador](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/nixos-configurations.nix#L15-L55) com conjunto nomeado de módulos diferidos, `nixosSystem` central, revisão no label | Adotar montagem nativa e revisão. Retirar raízes públicas `host-*`; manter as 3 saídas; não forçar label se houver consumidor dependente. | Várias contribuições de hosts montam uma saída sem cadastro paralelo. Revisão registra o que foi construído. |
| Matching, `base` em duas classes e versões HM/sistema ligadas em [home-manager.nix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/home-manager.nix) | Mesmo matching e os mesmos pares `base`/`gui`; chão `common` só NixOS; `homeUser` local e state versions independentes | O ensaio acima resolveu as opções reais: preserva base CLI sem GUI implícita, exclui Ordis de HM e a camada pessoal do lab. |
| `systems.nix` x86-64/ARM64, nixpkgs unstable e `nixpkgs.nix` com opções de overlays/unfree | x86-64, preservar 26.05, usar configuração nativa de nixpkgs nos consumidores | Todos os hosts atuais declaram x86-64; não há overlay global ou ampliação a ARM necessária. |
| `system/sops.nix` recebe input privado, gera identidade e prepara links | Ciphertext revisado no Git, identidade externa, validação sem identidade no build, fail-closed e link HM | Build sem acesso privado, login e runtime com credenciais providas externamente e lab isolado. |
| `devshell/{devshell,formatting}.nix` usa mkShell e treefmt-nix | Mesmo arranjo. Começar com nixfmt; não importar lint stack do autor. | Mesmo formatador existente, agora check nativo. Ferramentas adicionais só se houver necessidade demonstrada. |
| [ci.yml](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/.github/workflows/ci.yml) com check, descoberta, matriz; [montador também publica toplevels em checks](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/nixos-configurations.nix#L57-L63) | Mesmos três jobs e comandos; matriz é a única realização do toplevel, conforme abaixo | Mesmo toplevel é solicitado duas vezes no runner x86 da referência. Conservar gate, não o trabalho duplicado. |
| [deploy.yml](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/.github/workflows/deploy.yml), cache autenticado, source privada e limpeza ampla de runner | Não adicionar deploy/cache com credenciais nem setup SSH em CI. Preservar Actions fixadas por SHA e leitura. Limpar disco só no runner descartável e se necessário. | Sem deploy autorizado, credenciais pessoais fora do build, sem infraestrutura de cache aprovada. |

## CI e uso da fonte Git

1. **check**: `nix flake check --show-trace` com treefmt e checks leves aprovados na [matriz](02-dots.md#matriz-de-destino-dos-checks). **prepare**: `nix eval --json .#nixosConfigurations --apply …`, obtendo nomes e `config.nixpkgs.hostPlatform.system` como na referência. **builds**: depende só de prepare; matriz sem fail-fast, `nix build -L .#nixosConfigurations.<nome>.config.system.build.toplevel`. Jobs na mesma revisão imutável; sem KVM na CI principal se as VMs forem separadas. Não cadastrar hosts no YAML.
2. A referência realiza toplevels em check no sistema do runner e volta a realizá-los na matriz: no modelo atual seriam os três x86-64. Jobs independentes não compartilham store local; Cachix pode substituir uma realização, mas não é garantia. Recomendo **retirar a publicação dos toplevels como checks**, não o job check nem a matriz. `flake check` continua a avaliar o esquema/saídas NixOS e realizar os demais checks; a matriz constrói todos os sistemas. Não trocar por `flake check --no-build`, que também deixaria de executar formatter e provas leves.
3. **Eventos**: usar `push.branches: [master]` + `pull_request.branches: [master]` (aqui filtra a **base**) + `workflow_dispatch`. Em PR aberto/atualizado/reaberto, check e matriz na merge ref. Branch de trabalho fora de PR não dispara push automático; dispatch é manual. Push em `master` testa o commit realmente publicado, que pode não ser o merge sintético anterior, especialmente em squash/rebase. Não usar `pull_request_target` ou uma consulta de PRs no push para deduplicar. Se a base mudar, não tratar uma merge ref antiga como prova da nova: exigir resultado atualizado conforme a política do repositório antes do merge. Dispatch manual é deliberado, não deduplica execução solicitada.
4. **Revisão por job no workflow proposto:** checkout do SHA do evento (default de checkout ou `ref: ${{ github.sha }}` explícito). Em push, tip do push em `refs/heads/master`, não o tip que a branch pode alcançar depois. Em PR, `github.sha` é o merge sintético `refs/pull/N/merge`, não `github.event.pull_request.head.sha` (`refs/pull/N/head`); PR em conflito sem merge ref não tem essa prova. Em dispatch, commit da ref escolhida no disparo, não necessariamente `master`; se disparado para tag, checkout do objeto commit resolvido. Usar o mesmo SHA em todos os jobs, sem reconsultar branch móvel. A referência dá checkout padrão por push/dispatch; a revisão de integração em PR é a divergência deliberada. Na API do dot atual, `head_sha` do run de PR pode identificar a branch, não o checkout: [exemplo e SHAs observados](02-dots.md#fonte-git-auditada).
5. **Fonte nativa**: comando normal em checkout Git limpo do SHA; sem `path:$PWD`. Adotar recorte de arquivos rastreados e revisar nomes/conteúdo antes de construir a transição. Docs rastreados sem dados sensíveis podem entrar. Nenhum segredo em claro, identidade age, token, estado pessoal ou material de recuperação. O recorte Git não é scanner, e alterações de arquivo rastreado também podem entrar numa fonte local suja. Para uma prova local de release usar SHA/checkout limpo, não interpretar `.` em árvore suja como revisão imutável. Não criar outro exportador, lista ou manifest. Retirar `source-files.txt`, exportador, `scripts/check` e hook **junto da migração** após o diff de fronteira e as provas indicadas.

## Destino da documentação

| Documento atual | Destino e motivo |
| --- | --- |
| [README.md](../README.md) | Reduzir. Saídas, verificação nativa e seções curtas de operação com links. Retirar descrição do exportador e catálogo de opções. |
| [AGENTS.md](../AGENTS.md) | Reduzir. Descoberta, seleção, revisão a testar, fronteira de segredos, autorização e onde estão os procedimentos. Retirar manual de keys e exemplos redundantes. |
| [docs/estrutura.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/estrutura.md) | Remover. Antigo montador, deduplicação, catálogo e contrato documentável por código. |
| [docs/decisoes.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/decisoes.md) | Remover. Opções consultáveis no flake; levar só gates físicos/limites de recuperação ao procedimento de instalação. |
| [docs/desktop.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/desktop.md) | Remover catálogo de atalhos, clipboard e aparência. Preservar comandos de entrada/saída e aceitação física no README, quando não inferíveis do sistema. |
| [docs/desenvolvimento.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/desenvolvimento.md) | Remover catálogo de ferramentas/atalhos. Manter confiança explícita no ambiente e sequência de desbloqueio só se necessária no guia de credenciais/primeira sessão. |
| [docs/servicos.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/servicos.md) | Remover catálogo. Consolidar autorização SSH de entrada (clientes/provisionamento) e recuperação de snapshots/manutenção nas seções operacionais pertinentes. |
| [docs/bootstrap.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/bootstrap.md) | Fundir com primeira sessão/credenciais. Manter ordem de intervenção, falhas fechadas, preservação de destinos e limites de prova; não reproduzir DAG de unidades. |
| [docs/instalacao.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/instalacao.md) | Manter procedimento condensado no README: reconhecer disco/EFI, recuperação externa, política de firmware, o que chroot não prova e peculiaridade de rollback Limine. Sem valores de recuperação. |
| [docs/ordis.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/ordis.md) | Manter no README a verificação de acesso, rollback independente, geração/estado preservados e reboot separado. Retirar inventário de opções. |
| [docs/pihole.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/pihole.md) | Mover provisionamento/rotação do hash e aceitação/recuperação ao README de credenciais; remover listas consultáveis e lista de checks. |
| [docs/tailscale.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/tailscale.md) | Mover cadastro, grants e teste de acesso realmente externo ao procedimento de acesso; configuração do daemon fica no código. |
| [docs/herdr-tree.md](https://github.com/Rinyaresu/dots/blob/dcbf565b51dd4e411d3976396e8e0c69398f9df1/docs/herdr-tree.md) | Manter no README só pins externos, identidade do servidor/subscriber, limites de aplicação e sequência operacional segura de instalação e rollback. Remover layout declarativo, catálogo e reconstituição histórica. |
| [secrets/README.md](../secrets/README.md) | Manter como procedimento de credenciais: insumos externos, ordem, permissão e recuperação. Nunca os valores nem documentos privados. |

Não mover conteúdo para Home. Apontar para material existente ali só quando necessário; não editar Home, Agent ou Dev.

## Ordem e gates

1. Após aprovação, registrar opções efetivas e builds base, e confirmar estado do PR #2. Repetir auditoria da fonte do commit candidato antes de substituir a exportação existente.
2. Introduzir montagem central e seletores pareados. Avaliar os três toplevels e comparar versão, boot, mounts, rede, autenticação, isolamento do lab e HM efetivo com a base. Ordis sem HM ou usuário pessoal; lab sem identidade/restore/TreeView e sem NIC nem store do host.
3. Reorganizar por domínio, sem reescrever os scripts/patches de runtime no mesmo passo. Provar asserções e builds nativos; rodar as sete VMs de [aceitação crítica](02-dots.md#contrato-dos-sete-testes-de-aceitação-crítica) no candidato antes de solicitar aprovação final. Em mudanças posteriores, exigir os casos acionados pela matriz. Build da VM lab e teste de isolamento não certificam máquina física.
4. Migrar CI e docs, aposentar mecanismos pelos critérios da matriz. Validar que os jobs usam o mesmo SHA, que a matriz é completa e que push de branch de PR não faz segunda execução. Revisar todos os arquivos rastreados, a relação fonte/store/runtime e a ausência de credenciais de produção. Limpar `review/` antes do merge só após as revisões.
5. Ativação só em tarefa autorizada. Ordis requer geração e backups, console/rollback independente, SSH novo/sudo, validação de DNS, rede, mounts e boot. Desktop requer identificação física, preservação Windows/EFI, firmware e recuperação, validação de sessão/dispositivos e de autenticação/segredos. Não usar GC ou reboots como forma de testar o refactor.

**Revisão solicitada:** aprovar `common` só NixOS, `base` pareada e `homeUser` por host como diferenças mínimas para Ordis e lab; aprovar os sete packages de aceitação e seu contrato de execução/evidência fora do gate regular. Esta revisão não autoriza implementação nem substitui os gates de migração.
