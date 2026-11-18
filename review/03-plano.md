# 3. Plano de reconstrução revisado

Proposta, não implementação. [Referência](01-dotnix.md) e [inventário, checks e fronteira da fonte](02-dots.md). Manter as três saídas atuais. A referência define a forma de descobrir, compor, construir e validar; o dots fornece os requisitos das máquinas.

## Home Manager: adotar matching por nome

Na referência, [o montador](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/nixos-configurations.nix#L26-L55) faz a interseção dos nomes de `configurations.nixos.<host>.modules` com `flake.modules.homeManager`. Só com correspondência injeta HM e atribui os módulos a uma conta. Não segue imports transitivos do lado NixOS.

| Host | Nomes de interesse no seletor proposto (além de opções locais e capacidades exclusivamente NixOS) | Interseção HM esperada |
| --- | --- | --- |
| desktop | `base gui i3 niri desktop-personal configuration` | `gui i3 niri desktop-personal` |
| lab | `base gui i3 niri configuration` | `gui i3 niri` |
| Ordis | `base ssh tailscale pihole configuration` | vazia |

**Ensaio da regra, sem construir os hosts:** avaliei em Nix os conjuntos sintéticos acima (com `lab` como fragmento adicional sem correspondente) usando `builtins.intersectAttrs modules hm`, equivalente ao filtro da referência. O resultado foi a última coluna. Com `homeManager.base` adicionado, Ordis recebeu `base` e os PCs também. Ao adicionar `homeManager.firefox` sem chave de seleção correspondente, nenhum host ganhou `firefox` na interseção. Essa última limitação vale mesmo se `nixos.gui` importar um módulo NixOS Firefox: o seletor não mudou. A solução é fazer `homeManager.gui` contribuir com Firefox ou importar o módulo HM Firefox, não fabricar um módulo de sistema vazio.

**Distribuição proposta:**

- `nixos.base` nos três: Nix e atualização manual, NetworkManager, locale comum e sudo com senha. **Sem `homeManager.base`**, ao contrário do dotnix. Não há um requisito que force a remoção do matching; é o conteúdo de `base` em duas classes que faria Ordis receber HM. A opção estritamente literal seria tirar `base` do Ordis e criar um grupo adicional para o chão compartilhado, ou duplicar sua seleção. Isso introduz outro grupo apenas para contornar a colisão. Evitar ambos.
- `nixos.gui` e `homeManager.gui` nos PCs: composição multifile do dotnix. No sistema, gráficos, fontes, polkit, ferramentas de desktop, áudio, arquivos, Firefox/MIME, integração de sessão e da conta; na home, preferências visuais, Fish/Git, Ghostty, Neovim, Pi, Herdr base, providers e apps comuns às duas seleções atuais. Usar contribuições diretas ou imports HM para dependências reutilizadas. Não selecionar greeter, login automático, segredo ou restore em `gui`. `i3` e `niri` são seletores pareados opt-in; `niri` segue o exemplo da referência, não é efeito implícito de `gui`. Display físico só em `desktop/configuration.nix`.
- `desktop-personal` somente no desktop. O lado NixOS tem função real: SOPS/SSH pessoal, ordenação de HM e integração de bootstrap. O lado HM instala o link do segredo, o restore, Herdr TreeView e apps apenas do desktop. Sem material real no lab. Não é um dummy para tornar apps HM selecionáveis. `homeManager.gui` pode instalar Herdr base e `homeManager.desktop-personal` estendê-lo via Herdr TreeView; não eliminar identidades nativas necessárias nos diamantes reais.
- Matching não pressupõe que a conta global do autor seja inevitável. Aqui ambos os consumidores existentes usam rinyaresu, e Ordis não importa HM. No conjunto de sistemas com matching, usar esse nome na ligação do HM, com conta nativa publicada pelos fragmentos dos PCs, sem inventar `user.*` global ou cadastro. Guardar a ligação em `modules/nix/home-manager.nix`, junto das opções upstream usando somente o resultado da interseção (sem um segundo mecanismo de seleção). Manter as versões de estado declaradas por host/conta. A contribuição local do host para `home.stateVersion` e monitores não escolhe módulos. Suportar várias homes por host ou contas diferentes via seleção exigiria outro contrato; **não é requisito desta base**.

Outra opção seria espelhar cada capacidade HM-only com um nome NixOS vazio; preserva seleção fina, mas não o modelo real do dotnix, que põe aplicações HM em bundles sem dummies. A seleção explícita de toda a lista HM, proposta no primeiro plano, não é necessária para as combinações verificadas. Asserções entre classes devem permanecer somente para pré-condições efetivas, não para repetir o matching.

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

Os diretórios `devshell`, `nix`, `hosts`, `system` e `server` seguem o catálogo real da referência. CLI, GUI, rede, boot e armazenamento recebem as capacidades na sua área, em vez de um novo diretório genérico `features`. Não criar `packages/` vazio. Testes publicados são contribuições flake-parts colocadas junto à funcionalidade; fixtures Nix brutas usam `_` e são importadas pelo consumidor. Fixtures Python e patches são arquivos auxiliares, como na referência. Um teste de isolamento de firewall do host pode morar na área da política (`system/networking`) ou junto à configuração daquele host, não requer uma terceira árvore.

| Diferença de layout | Decisão e evidência |
| --- | --- |
| `checks/` e `modules/tests/` não existem na referência | Nenhum dos dois no alvo. Colocar fixture sobrevivente ao lado da capacidade que prova. `modules/packages/` só se aparecer artefato independente; não é necessário para publicar testes dentro de módulos de domínio. |
| `docs/` não existe na referência | Não criar/migrar árvore de catálogos. Usar README para um guia operacional mínimo, AGENTS para limites e prova, README de segredos para provisionamento. Matriz abaixo. |
| `secrets/` é local, não existe no dotnix | Necessário para a única entrada SOPS cifrada e revisada sem exigir o repositório privado que a referência usa no build. Nenhuma identidade dentro. |
| Fragmentos adicionais do host no plano anterior | Remover como padrão. `home.nix` vira dados de host (estado/monitores) em `configuration.nix`; seleção sai por matching. `access.nix` vira opções locais do host e SSH compartilhável em `system/ssh.nix`, sem diluir diferenças de superfície. `maintenance.nix` vira política local do desktop; `tso-experiment.nix` vira configuração local de Ordis, preservando TSO off e identidade DHCP; `pihole.nix` do host vira interface/lista/firewall em `configuration.nix`, como os ajustes de serviço de `homelab` na referência. Não separar só por tamanho; só extrair se existir consumidor independente. `_hardware-configuration.nix` mantém a fronteira literal da referência. |

## Critério de fidelidade por decisão

| Implementação exata da referência | Proposta e diferença | Motivo verificável |
| --- | --- | --- |
| [flake.nix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/flake.nix#L118-L125), `mkFlake`, import-tree e `rootPath`; [flake-modules.nix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/flake-modules.nix) importa também wrappers | Mesma descoberta e publicação; sem argumento ou input sem consumidor | Nenhuma implementação planejada exige wrappers ou caminho global. Hardware por caminho relativo já é o padrão real. |
| [Montador](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/nixos-configurations.nix#L15-L55) com conjunto nomeado de módulos diferidos, `nixosSystem` central, revisão no label | Adotar montagem nativa e revisão. Retirar raízes públicas `host-*`; manter as 3 saídas; não forçar label se houver consumidor dependente. | Várias contribuições de hosts montam uma saída sem cadastro paralelo. Revisão registra o que foi construído. |
| Matching, `base` em duas classes e versões HM/sistema ligadas em [home-manager.nix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/home-manager.nix) | Mesmo matching; `base` só NixOS, `gui` em duas classes; conta nativa e state versions independentes | A interseção verificada exclui Ordis e a camada pessoal do lab. O estado HM não precisa assumir o estado do sistema nem uma conta global do autor. |
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
| [docs/estrutura.md](../docs/estrutura.md) | Remover. Antigo montador, deduplicação, catálogo e contrato documentável por código. |
| [docs/decisoes.md](../docs/decisoes.md) | Remover. Opções consultáveis no flake; levar só gates físicos/limites de recuperação ao procedimento de instalação. |
| [docs/desktop.md](../docs/desktop.md) | Remover catálogo de atalhos, clipboard e aparência. Preservar comandos de entrada/saída e aceitação física no README, quando não inferíveis do sistema. |
| [docs/desenvolvimento.md](../docs/desenvolvimento.md) | Remover catálogo de ferramentas/atalhos. Manter confiança explícita no ambiente e sequência de desbloqueio só se necessária no guia de credenciais/primeira sessão. |
| [docs/servicos.md](../docs/servicos.md) | Remover catálogo. Consolidar autorização SSH de entrada (clientes/provisionamento) e recuperação de snapshots/manutenção nas seções operacionais pertinentes. |
| [docs/bootstrap.md](../docs/bootstrap.md) | Fundir com primeira sessão/credenciais. Manter ordem de intervenção, falhas fechadas, preservação de destinos e limites de prova; não reproduzir DAG de unidades. |
| [docs/instalacao.md](../docs/instalacao.md) | Manter procedimento condensado no README: reconhecer disco/EFI, recuperação externa, política de firmware, o que chroot não prova e peculiaridade de rollback Limine. Sem valores de recuperação. |
| [docs/ordis.md](../docs/ordis.md) | Manter no README a verificação de acesso, rollback independente, geração/estado preservados e reboot separado. Retirar inventário de opções. |
| [docs/pihole.md](../docs/pihole.md) | Mover provisionamento/rotação do hash e aceitação/recuperação ao README de credenciais; remover listas consultáveis e lista de checks. |
| [docs/tailscale.md](../docs/tailscale.md) | Mover cadastro, grants e teste de acesso realmente externo ao procedimento de acesso; configuração do daemon fica no código. |
| [docs/herdr-tree.md](../docs/herdr-tree.md) | Manter no README só pins externos, identidade do servidor/subscriber, limites de aplicação e sequência operacional segura de instalação e rollback. Remover layout declarativo, catálogo e reconstituição histórica. |
| [secrets/README.md](../secrets/README.md) | Manter como procedimento de credenciais: insumos externos, ordem, permissão e recuperação. Nunca os valores nem documentos privados. |

Não mover conteúdo para Home. Apontar para material existente ali só quando necessário; não editar Home, Agent ou Dev.

## Ordem e gates

1. Após aprovação, registrar opções efetivas e builds base, e confirmar estado do PR #2. Repetir auditoria da fonte do commit candidato antes de substituir a exportação existente.
2. Introduzir montagem central e seletores pareados. Avaliar os três toplevels e comparar versão, boot, mounts, rede, autenticação, isolamento do lab e HM efetivo com a base. Ordis sem HM ou usuário pessoal; lab sem identidade/restore/TreeView e sem NIC nem store do host.
3. Reorganizar por domínio, sem reescrever os scripts/patches de runtime no mesmo passo. Provar asserções e builds nativos; rodar todas as VMs marcadas **Separado** na primeira migração, em infraestrutura descartável com KVM, sem material pessoal. Em mudanças posteriores, exigir os casos separados afetados quando a área crítica mudar. Build da VM lab e teste de isolamento não certificam máquina física.
4. Migrar CI e docs, aposentar mecanismos pelos critérios da matriz. Validar que os jobs usam o mesmo SHA, que a matriz é completa e que push de branch de PR não faz segunda execução. Revisar todos os arquivos rastreados, a relação fonte/store/runtime e a ausência de credenciais de produção. Limpar `review/` antes do merge só após as revisões.
5. Ativação só em tarefa autorizada. Ordis requer geração e backups, console/rollback independente, SSH novo/sudo, validação de DNS, rede, mounts e boot. Desktop requer identificação física, preservação Windows/EFI, firmware e recuperação, validação de sessão/dispositivos e de autenticação/segredos. Não usar GC ou reboots como forma de testar o refactor.

**Revisão solicitada:** aceitar o matching com `base` NixOS-only, `gui` pareado e grupo pessoal; aceitar a matriz como única realização de toplevels e a CI de PR na merge ref; aprovar o corte de checks e as provas KVM separadas como gates de mudanças críticas. O uso da fonte Git nativa é a proposta de partida solicitada, com verificação de fronteira antes da troca.
