# 3. Plano de reconstrução

Proposta para revisão, não implementação. Base em [1. Arquitetura do dotnix](01-dotnix.md) e [2. Inventário do dots](02-dots.md). O contrato externo continua a ser `nixosConfigurations.{desktop,lab,ordis}`. A mudança é como se chega a essas saídas e como se prova que continuam funcionando.

## Árvore-alvo

```text
flake.nix
flake.lock
.github/workflows/ci.yml
modules/
  devshell/{devshell,formatting}.nix
  nix/{flake-modules,nixos-configurations,home-manager}.nix
  hosts/
    desktop/{modules,configuration,_hardware-configuration,home,access,maintenance}.nix
    lab/{modules,configuration,home}.nix
    ordis/{modules,configuration,_hardware-configuration,access,pihole,networking}.nix
  system/
    {systems,nix-settings,locale,sops,virtualisation}.nix
    boot/{limine,no-hibernation}.nix
    networking/{network,tailscale,wireguard}.nix
    storage/{home-snapshots,zram}.nix
    users/rinyaresu/{default,ssh,pi-bootstrap}.nix
    interfaces/
      {bluetooth,sound}.nix
      cli/{tools,toolchain,neovim,git,providers,docker,herdr,pi,ssh-agent}.nix
      cli/shells/fish.nix
      gui/{graphics,fonts,polkit,unfree}.nix
      gui/apps/…                 # navegadores, apps, terminal e associação MIME
      gui/desktop/{niri,i3,files}/…
  server/networking/pihole/{default.nix,admin-hash.py,api-no-argv-secrets.patch}
  tests/*.nix                  # publicações dos checks comportamentais mantidos
checks/                        # fixtures de teste que não são módulos flake-parts
secrets/{README.md,ssh.yaml}
AGENTS.md
README.md
docs/                          # só procedimentos operacionais
```

A profundidade acompanha as responsabilidades existentes. Não criar diretórios vazios. `modules/packages/` entra apenas se houver artefato útil como saída independente do flake, como prevê o dotnix. O pacote Herdr pinado e o Pi ajustado podem continuar dentro da capacidade que os consome. O utilitário Pi-hole fica junto do serviço enquanto seu único consumidor for Ordis.

## Como compor

| Padrão da referência | Aplicação proposta |
| --- | --- |
| `flake.nix` com `mkFlake` + import-tree; `nix/flake-modules.nix`, `system/systems.nix` | Uma descoberta. Flake raiz só guarda inputs e liga a árvore. Publicação flake-parts em `nix/`, x86-64 em `system/`, sem `rootPath` sem consumidor ou input de wrappers sem requisito. |
| `nix/nixos-configurations.nix` e `hosts/*/modules.nix` | Adotar o conjunto local de montagem `configurations.nixos.<host>.modules` do dotnix, com módulos diferidos e merge nativos. Seletores nomeados em `modules.nix`; entradas `configuration`, `home`, `access` etc. em arquivos irmãos. Um único `nixosSystem` por entrada, com toplevels/checks derivados. Isso substitui as três chamadas repetidas e as raízes públicas artificiais `host-*`. Não estender o conjunto com registro de usuários, metadados de CI ou descoberta duplicada. Um label com revisão é útil para rastrear gerações; acrescentá-lo sem forçar perda de labels necessários ao operador. |
| `hosts/*/_hardware-configuration.nix` | Hardware NixOS bruto ignorado pela descoberta e importado por caminho no fragmento do host. Sem trocar sistemas de arquivos, flags ou dispositivos. |
| Contribuições a `base`/`gui` e opções nativas | Agregar sob o mesmo nome somente políticas realmente comuns. Candidatos iniciais: `base` com Nix, NetworkManager, locale comum e sudo com senha nos três; `gui` com gráficos/fontes/Polkit nos PCs. Não incluir acesso, segredo ou manutenção de um host no grupo comum. Manter niri, i3, apps e serviços opt-in quando os contratos diferem. |
| `system/interfaces/`, `system/users/`, `server/`, `packages/` | Redistribuir [o inventário](02-dots.md): CLI/providers/Pi/Herdr em interfaces; identidade Git/conta/SSH/bootstrap juntos em usuários; GUI e integrações em interfaces; acesso e ajustes de cada host em hosts; Pi-hole reutilizável em server, lista/interface/firewall em Ordis. |
| `nix/home-manager.nix` + seleção da classe HM pelo host | Uma integração pequena com upstream e opções nativas; seleção explícita em `hosts/*/home.nix`. Lab usa Herdr base sem TreeView nem restore; desktop seleciona TreeView e restore; Ordis não importa HM. Preservar `useGlobalPkgs`, `useUserPackages`, asserções de dependência efetiva e versões independentes. |
| `devshell/formatting.nix` e `devshell/devshell.nix` | Formatter e check via treefmt-nix; começar com nixfmt, sem importar a lista de linters do autor. Devshell nativo para ferramentas que realmente têm uso no repo, sem bootstrap de credenciais. |

### Divergências deliberadas

1. **HM explícito, sem matching.** O matching do dotnix usa chaves NixOS para selecionar uma única home. Nossos apps somente HM, TreeView e bootstrap diferentes por host exigiriam dummies, acoplamento a rótulos ou exceções de privacidade. O módulo de home por host expressa a seleção diretamente. Identidade deriva da conta upstream; não adotar `user.*` global, home fixo ou vincular as versões de estado. Avaliar se a asserção genérica de identidade atual ainda evita uma falha real; não trocar asserções de segurança em `osConfig` por nomes.
2. **Estável e somente x86-64.** Preservar as versões fixadas, patches e comportamento comprovado. Não misturar atualização de inputs/pacotes com migração estrutural, exceto inputs da nova infraestrutura. A matriz deriva a plataforma avaliada, sem declarar suporte ARM inexistente.
3. **Sem input privado no build.** Usar o ciphertext SOPS revisado e age externo ao store, com fail-closed e ordenação antes do HM. Hash Pi-hole, autorização SSH local, estado Tailscale, VPN e autenticação permanecem externos. Home/Agent só em runtime após desbloqueio; Dev não se torna input. Não copiar geração automática de identidade, symlinks destrutivos ou scripts de ativação do dotnix.
4. **Sem deploy automático nem confiança importada.** Não adicionar deploy-rs, segredos de GitHub, permissões permanentes, substituidores de terceiros específicos da referência ou um fluxo de bootstrap remoto. Preservar sudo com senha e políticas atuais de acesso, atualizações e recuperação. A separação CI/deploy é arquitetural; aqui não há segundo workflow porque não há deploy autorizado.
5. **Checks de comportamento além do toplevel.** Um sistema buildável não prova fronteiras de segredo, autenticação, firewall, DNS e recuperação. Manter testes com evidência útil, não a modelagem interna da suite atual.
6. **Sem instalar o desenho de hardware do autor.** Não adotar disko/RAID/criptografia, Secure Boot, greeter, configurações de usuários ou aplicativos dele. A forma de declarar e separar é transferível; as escolhas e riscos de instalação dependem dos nossos alvos.

## CI e critérios para retirar mecanismos

- Usar `.github/workflows/ci.yml` com três jobs no formato do dotnix: **check** com `nix flake check` (formatter e checks/VMs), **prepare** com `nix eval` sobre nomes e `config.nixpkgs.hostPlatform.system`, e **builds** em matriz, sem fail-fast, com `nix build .#nixosConfigurations.<nome>.config.system.build.toplevel`. Primeiro manter a sobreposição de toplevels no check e na matriz, como na referência. Medir custo após funcionamento; não adicionar cache próprio ou ferramenta de orquestração por antecipação. Se for caro, discutir qual superfície deve realizar os toplevels antes de mudar.
- Manter push, PR e dispatch para provas, sem `pull_request_target`. Ações pinadas por SHA, permissão de leitura, checkout sem persistência de credencial. KVM só para o job que roda VMs; limpeza delimitada ao runner hospedado quando comprovadamente necessária. Manter os substituidores já necessários e não presumir cache do dotnix; cache adicional exigirá decisão separada sobre origem, confiança e quem pode escrever. Incorporar evidência do PR #2 se ele entrar em `master`, sem editar a branch alheia. Não há deploy ou autoativação em evento algum.
- Retirar testes de fixtures do próprio sistema de módulos (`checks/modules/`, `module-system-checks.nix`), catálogos de opções sem risco e política universal de `key`. Usar imports e identidade de caminhos nativos; para uma contribuição publicada como valor anônimo, não presumir deduplicação por nome ou `_file`. Manter `key` nativa onde múltiplos caminhos reais ainda exigirem a mesma contribuição única (verificar Ghostty, Fish e Pi). Não criar deduplicador. Conservar testes dos consumidores se provarem falha observável, por exemplo init duplicado ou conflito de configuração.
- Substituir `scripts/check` e o hook por comandos nativos e jobs explícitos; remover o exportador, allowlist duplicada, manifest e seus testes **só** depois de validar a fronteira de fonte. CI usa checkout do SHA e referência Git do flake, não `path:$PWD`. Arquivos não rastreados/ignorados ficam fora; alterações locais rastreadas podem entrar. Isso não filtra arquivos privados já rastreados, nem substitui a revisão do ciphertext. Comparar o snapshot Git destinado aos builds com a fonte permitida: nenhum segredo em claro, estado pessoal, backup ou material de recuperação. Docs rastreados seriam visíveis no snapshot Git, mesmo sem consumo por derivação: se a exclusão absoluta de documentação for requisito, decidir antes da remoção do filtro. Não implementar outro exportador apenas para repetir o recorte do índice. Manter qualquer prova independente de fronteira de build/runtime que continue relevante.
- Preservar provas direcionadas a Pi/Herdr/fish, configuração gráfica, SOPS/SSH/bootstrap, Tailscale, Pi-hole e snapshots. Usar `checks` com `runNixOSTest` ou derivação nativa conforme o tipo de prova. Não reescrever scripts e patches de runtime no mesmo commit que move seus módulos. Só substituí-los ao demonstrar paridade, incluindo casos de recusa.

## Documentação permanente

README com saídas, comandos nativos e links. AGENTS curto: regra de descoberta e seleção, proteção de fontes/segredos, checks/builds e limite de autorização. Eliminar o manual da antiga estrutura e as decisões que só espelham opções. Consolidar procedimentos que exigem contexto externo: instalação e recuperação desktop, administração/rollback Ordis, credenciais e validação externa (SOPS/Tailscale/Pi-hole), bootstrap e passos manuais TreeView. Remeter detalhes privados ao Home, sem copiá-los. A auditoria em `review/` sai antes do merge, preservada no histórico e discussão.

## Sequência proposta e gates

1. **Após aprovação do plano**, registrar saídas e opções efetivas da base e confirmar estado do PR #2. Usar fonte Git limpa para a reconstrução só após conferir a fronteira; enquanto não aprovada, usar a exportação da base. Registrar SHA e resultados, não segredos. Manter o worktree/PR desta auditoria.
2. Reconstruir flake, montagem e hosts. Mover hardware e trocar consumidores de `host-*` nos checks (por exemplo desktop/Tailscale) sem perder isolamento. Avaliar três saídas e comparar contas, versões, componentes selecionados e opções críticas com a base. Nenhuma mudança de hardware/serviço nesta etapa.
3. Redistribuir funcionalidades por responsabilidade e provar cada família. Validar niri/i3/HM e shell/SSH/Pi/Herdr; depois rede/firewall/Tailscale/Pi-hole, snapshots e isolamento do lab. Não remover mecanismos antigos antes de seus consumidores migrarem. Construir os três toplevels, e o output VM do lab, sem ativar.
4. Trocar CI/formatter, reduzir testes genéricos e consolidar docs em commits separados. Provar a matriz, formatter, checks e VMs sem autorização de produção. Confirmar que a avaliação e o build não precisam de age, chave SSH pessoal ou repositórios privados; confirmar recusa com credenciais inválidas apenas em fixtures. Revisar diff final e aguardar aceitação.
5. **Antes de qualquer ativação futura, com autorização própria:** comparar opções efetivas com a geração funcional (rede, firewall, SSH, boot, mounts, sudo, identidade e versões de estado). Ordis requer acesso independente/console, geração e backups recuperáveis, validação de SSH novo/sudo antes da troca, DNS TCP/UDP somente onde permitido e UI local, recuperação de serviço, mounts e boot; validar acesso externo pela identidade autorizada sem confundir com teste na LAN. Desktop requer confirmar destino físico, partições/Windows e recuperação, firmware/Secure Boot, GPU/monitores, sessões, desbloqueio e segredos, rollback e cópia dos dados. Lab descartável primeiro, sem diretórios, credenciais ou rede do host. Nem build nem VM autorizam ativação, reboot ou GC.

## Decisões na revisão

- Aprovar o montador nomeado central com HM explícito e os limites de `base`/`gui`.
- Decidir se docs rastreados, sem dados sensíveis, podem estar na fonte Git do flake. É a diferença concreta entre aposentar a exportação atual e manter uma fronteira mais estrita.
- Confirmar o corte de checks e a CI de partida (sem cache próprio/deploy), considerando o PR #2. Retirada de hardening, autorização de ativação e política de recuperação física não fazem parte dessa aprovação.
