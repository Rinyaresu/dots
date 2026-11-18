# 4. Etapa 1 — montagem dos hosts

Escopo: fundação do [plano aprovado](03-plano.md), sem reorganização geral, troca da CI ou migração dos checks. Referência: [dotnix `50ad795e920d187bb56e064430f92c10326e6f66`](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/nixos-configurations.nix). Na abertura, `master` remoto estava em `96dcf1363828e565d2bc3787d25f0df8f297db77`, PR #2 aberto e não integrado (HEAD `104a3f1e96114c54bbfe6afb48c4dab38a11c6cf`), e o worktree do PR #3 limpo em `3c1b2b759930fb36327fe20e01ae7349ef3a842c` (baseline de comparação).

## Mapa das mudanças

- `d0ce8c01b152407a7f0c57d0d461ac1754cabedc`: [montador](../modules/nix/nixos-configurations.nix) com `lazyAttrsOf` de submódulos e conjunto nomeado de `deferredModule`. Checkpoint ainda sem migrar consumidores: a projeção dos três sistemas foi idêntica, byte a byte, à da baseline.
- `63dbba71b22718098aacefcf364deddad2cc17be`: [grupos](../modules/nix/host-groups.nix) e migração dos [fragmentos dos hosts](../modules/hosts). As chamadas de produção a `nixosSystem` ficaram no montador, mantendo `nixosConfigurations.desktop`, `lab` e `ordis`. As chamadas em fixtures de checks continuam. Os hosts publicam seletores e fragmentos locais em `configurations.nixos.<host>.modules`, sem raiz pública `host-*` nem lista paralela de hosts.
- Desktop/lab selecionam `base gui i3 niri` e têm `homeUser = "rinyaresu"`; apenas desktop seleciona `desktop-personal`. Ordis seleciona `common` e suas capacidades/fragmentos de servidor, sem `homeUser`. `common` entra nos PCs como import de `base`. A camada pessoal inclui SSH/SOPS, restore, TreeView e apps exclusivos; o lab continua importando o módulo SOPS genérico da baseline, sem segredos pessoais.
- `checks/{desktop-access,desktop-snapshots,tailscale}.nix` e seus consumidores leem os mesmos fragmentos pelos novos seletores. [O check de arquitetura](../modules/nix/checks.nix) passa a exigir os pares aprovados em vez de proibir `base`/`gui`; preserva as demais verificações. As 23 saídas antigas continuam em `checks`. A [allowlist](../source-files.txt) inclui os dois módulos novos; workflow, exportador, serviços, scripts de runtime, patches e lock não mudaram.

**Divergências deliberadas da referência:** `homeUser` local substitui `config.user.name` global, `common` é só NixOS e Ordis não recebe HM. O montador usa a ponte HM já existente (incluindo pacotes e asserções), sem introduzir `specialArgs` sem consumidor. Não acrescenta label/revisão ao nome do toplevel ou publica toplevels em `checks`: nesta etapa preservamos a identidade atual e o contrato da CI. O caminho dos fragmentos locais foi mantido; as instruções antigas em AGENTS e no catálogo continuam provisoriamente desatualizadas para a montagem.

## Comparação de opções e builds

| Contrato | Desktop | Lab | Ordis |
| --- | --- | --- | --- |
| Identidade e estado | hostname, conta nativa, UID, shell e grupos iguais; NixOS/HM `26.05/26.05` | hostname efetivo `nixos-lab`; mesma conta, UID, shell e grupos; `26.05/26.05` | hostname/conta nativos preservados; `26.05`, sem opção HM e sem conta pessoal |
| Boot e mounts | Limine e entrada EFI existentes, módulos/parâmetros de kernel e mounts preservados | mesma configuração de boot e mounts da VM | systemd-boot, mounts Btrfs/EFI e swap preservados |
| Rede, SSH, firewall | interfaces/NetworkManager, opções SSH e regras idênticas na projeção | DHCP desativado como antes; projeções SSH/firewall idênticas | opções SSH, chaves públicas (comparadas por impressão digital), regras físicas/overlay, interfaces e configuração de link idênticas |
| Serviços e HM | mesmos serviços habilitados, mesmas chaves de arquivos HM; SOPS pessoal, restore e TreeView presentes | mesmos serviços habilitados, mesmas chaves de arquivos HM; sem segredos, restore privado ou TreeView | mesma derivação de toplevel, portanto nenhuma mudança no fechamento construído |
| Isolamento | — | `-nic none`, rede restrita, zero diretórios compartilhados, sem montar store do host, imagem com store gravável, sem overlay tmpfs | — |

**Diferenças verificadas nos PCs:** a ordem de merge das listas de pacotes mudou, mas o multiconjunto de derivações é igual. Nos builds, todos os links de `sw` (15.288 desktop; 15.304 lab) e de `home-path` têm os mesmos nomes e alvos. Nos arquivos da home, as únicas alterações de alvo foram fontconfig e manpath (mesmo conteúdo exceto referências a novos caminhos do store) e completions Fish (mesmos 63 links no desktop e 59 no lab, com alvos idênticos). As quatro unidades com nova derivação nos dois PCs mudaram somente referências: `ExecStart` da ativação HM e do man-cache, e `X-Restart-Triggers` do dbus-broker e do polkit. A derivação da imagem/launcher da VM lab mudou junto do sistema; os valores de isolamento não mudaram. Isso não é prova de ativação, boot físico ou sessão gráfica em execução.

| Host | Derivação candidata (prefixo `/nix/store/`) | Build |
| --- | --- | --- |
| desktop | `j0cfkajdjfmw6w17a4zqgplgsikjgq84-nixos-system-desktop-26.05.20261108.ac588ef.drv` | passou |
| lab | `i45931211ykj2xyf2jk0iqwj9y56x6zl-nixos-system-nixos-lab-26.05.20261108.ac588ef.drv` | passou |
| Ordis | `hyq4ikh6faa9bafmbxcxz0p4bvvb764b-nixos-system-ordis-26.05.20261108.ac588ef.drv` (mesma baseline) | passou |

Todos os toplevels da baseline também estavam realizáveis. Os dois toplevels alterados foram construídos localmente; o de Ordis já estava no store. Confirmei offline os três caminhos no export do commit candidato, sem socket de agente SSH ou tokens GitHub no comando. Só houve acesso aos insumos do lock/store e ciphertext já autorizado; as chaves de runtime não são insumos do build. Nenhum sistema foi ativado.

## Checks e controles do montador

- Baseline: `./scripts/check --quick` passou (15 unittests, formatter e avaliação das saídas).
- Primeira tentativa do candidato: falhou na asserção antiga `no-legacy-groups`, que proibia os novos nomes. Era incompatibilidade da migração, não falha preexistente. A substituição por `named-group-boundaries` manteve o check e validou o novo contrato.
- Candidato: `./scripts/check` terminou com status 0. Passaram os 15 unittests, formatter, avaliação das 23 saídas e realização pelo gate existente (`running 11 flake checks...`; reuso do store é permitido). O teste `secret-runtime` foi executado nesta rodada em KVM, inclusive a verificação de que os bytes privados da fixture não entraram no store da VM; o script levou 95,76 s. As outras seis derivações de VM foram resolvidas e aceitas pelo gate, sem nova execução observada no log. Nenhuma falha permaneceu. O aviso de output flake `modules` desconhecido também ocorre na baseline.
- Sonda descartável com o **montador de produção**: a seleção direta de uma capacidade pareada habilitou Nano e criou o arquivo HM marcador; a importação transitiva habilitou Nano mas deixou a opção HM e o marcador ausentes. Os dois toplevels resolveram. Com matching e sem `homeUser`, falhou com `configurations.nixos.probe-missing-name.homeUser must name a native NixOS account`. Com nome sem conta nativa, o toplevel foi rejeitado explicitamente (`…probe-missing-account.homeUser … is not a normal NixOS account on this host`). A sonda não altera os três sistemas nem publica outras saídas no candidato.

### Reprodução

Executar de cada revisão **no worktree dedicado**, usando a fonte explícita atual. Antes dos comandos, salve o primeiro bloco abaixo em `review/.etapa1/projection.nix`. Os JSONs locais incluem detalhes da configuração e não devem ser anexados. Confirme `git diff --check`; o export avaliado do candidato foi comparado arquivo a arquivo com `git show 63dbba7:<caminho>`.

```bash
umask 077
d="$PWD/review/.etapa1"
mkdir -p "$d"
export XDG_STATE_HOME="$d/state" NIX_CONFIG='builders ='
src=$(python3 -B scripts/export-source.py)
n=(nix --extra-experimental-features 'nix-command flakes')
"${n[@]}" eval --offline --no-write-lock-file "path:$src#nixosConfigurations" \
  --json --apply "$(<"$d/projection.nix")" > "$d/opcoes.json"
args=()
for host in desktop lab ordis; do
  args+=("path:$src#nixosConfigurations.$host.config.system.build.toplevel")
done
"${n[@]}" build --no-link --no-write-lock-file -L "${args[@]}"
./scripts/check                    # wrapper preservado
```

Para comparar os perfis construídos, use `nix-store -q --outputs <drv>` e compare nomes e alvos dos links em `<toplevel>/sw` e `<activation>/home-path`/`home-files`; fontes e derivação de ativação constam da projeção. Para a sonda, copie o export para `$d/probe`, salve o segundo bloco como `$d/probe/modules/nix/etapa1-probe.nix` e execute:

```bash
for host in probe-direct probe-transitive; do
  "${n[@]}" eval --offline --no-write-lock-file --json "path:$d/probe#nixosConfigurations.$host" \
    --apply 's: { nano = s.config.programs.nano.enable; hm = s.options ? home-manager; marker = (s.config.home-manager.users.fixture.home.file or {}) ? ".only-direct"; top = s.config.system.build.toplevel.drvPath; }'
done
for host in probe-missing-name probe-missing-account; do
  "${n[@]}" eval --offline --no-write-lock-file "path:$d/probe#nixosConfigurations.$host.config.system.build.toplevel.drvPath"
done
```

<details>
<summary>Projeção Nix (salvar como projection.nix)</summary>

```nix
hosts:
builtins.mapAttrs (
  _: system:
  let
    c = system.config;
    o = system.options;
    h = c.home-manager.users.rinyaresu or null;
    names = builtins.attrNames;
    drv = p: p.drvPath or (toString p);
  in {
    identity = {
      inherit (c.networking) hostName;
      platform = c.nixpkgs.hostPlatform.system;
      inherit (c.users) mutableUsers;
      accounts = builtins.mapAttrs (_: u: {
        inherit (u) name uid isNormalUser home group extraGroups;
        keyCount = builtins.length u.openssh.authorizedKeys.keys;
        keyFingerprint = builtins.hashString "sha256" (builtins.toJSON u.openssh.authorizedKeys.keys);
        keyFiles = u.openssh.authorizedKeys.keyFiles;
        shell = toString u.shell;
      }) (builtins.intersectAttrs { rinyaresu = null; ordis = null; } c.users.users);
    };
    state = { os = c.system.stateVersion; home = if h == null then null else h.home.stateVersion; };
    boot = {
      systemdBoot = c.boot.loader.systemd-boot.enable;
      grub = c.boot.loader.grub.enable;
      limine = c.boot.loader.limine.enable;
      limineEntries = c.boot.loader.limine.extraEntries;
      inherit (c.boot.loader) timeout;
      inherit (c.boot.loader.efi) canTouchEfiVariables;
      inherit (c.boot) kernelParams kernelModules;
      initrd = c.boot.initrd.systemd.enable;
      inherit (c.boot.initrd) availableKernelModules;
    };
    mounts = {
      fs = builtins.mapAttrs (_: f: { inherit (f) device fsType options neededForBoot; }) c.fileSystems;
      swap = map (s: s.device) c.swapDevices;
    };
    network = {
      inherit (c.networking) useDHCP interfaces;
      nm = c.networking.networkmanager.enable;
      dhcpcd = c.networking.dhcpcd.enable;
      inherit (c.networking) nameservers;
      linkSettings = builtins.mapAttrs (_: link: link.linkConfig) c.systemd.network.links;
    };
    ssh = {
      inherit (c.services.openssh) enable openFirewall ports settings;
      agent = c.programs.ssh.startAgent;
    };
    firewall = {
      inherit (c.networking.firewall) enable interfaces allowedTCPPorts allowedUDPPorts trustedInterfaces extraCommands extraStopCommands;
      nft = c.networking.nftables.enable;
    };
    services = {
      enabled = names (builtins.removeAttrs (builtins.mapAttrs (_: u: u.enable) (builtins.removeAttrs c.systemd.services []))
        (builtins.filter (n: !c.systemd.services.${n}.enable) (names c.systemd.services)));
      unitFiles = builtins.mapAttrs (_: u: drv u.unit) c.systemd.units;
      inherit (c.security.sudo) wheelNeedsPassword;
      pihole = c.services.pihole-ftl.enable;
      tailscale = c.services.tailscale.enable;
      secretNames = names (c.sops.secrets or {});
    };
    isolation = if c.networking.hostName != "nixos-lab" then null else {
      inherit (c.virtualisation) mountHostNixStore useNixStoreImage writableStore writableStoreUseTmpfs sharedDirectories restrictNetwork;
      inherit (c.virtualisation.qemu) networkingOptions;
      vm = c.system.build.vm.drvPath;
    };
    hm = {
      option = o ? home-manager;
      users = names (c.home-manager.users or {});
      value = if h == null then null else {
        inherit (h.home) username homeDirectory;
        configFiles = builtins.mapAttrs (_: f: toString f.source) h.xdg.configFile;
        files = builtins.mapAttrs (_: f: toString f.source) h.home.file;
        packages = map drv h.home.packages;
        units = names h.systemd.user.services;
        activation = h.home.activationPackage.drvPath;
      };
    };
    packages = map drv c.environment.systemPackages;
    toplevel = c.system.build.toplevel.drvPath;
  }
) hosts
```

</details>

<details>
<summary>Módulo da sonda, somente para o export descartável</summary>

```nix
{ config, ... }:
let
  inherit (config.flake.modules) nixos;
  minimal = {
    nixpkgs.hostPlatform = "x86_64-linux";
    boot.loader.grub.enable = false;
    fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
    system.stateVersion = "26.05";
  };
  pc = {
    imports = [ minimal ];
    users.users.fixture = { isNormalUser = true; uid = 1234; };
    home-manager.users.fixture.home.stateVersion = "26.05";
  };
in {
  flake.modules.nixos.paired.programs.nano.enable = true;
  flake.modules.homeManager.paired.home.file.".only-direct".text = "fixture";
  configurations.nixos = {
    probe-direct = {
      homeUser = "fixture";
      modules = { configuration = pc; inherit (nixos) paired; };
    };
    probe-transitive = {
      modules.configuration = { imports = [ minimal nixos.paired ]; };
    };
    probe-missing-name.modules = { configuration = minimal; inherit (nixos) paired; };
    probe-missing-account = {
      homeUser = "absent";
      modules = {
        inherit (nixos) paired;
        configuration = { imports = [ minimal ]; home-manager.users.absent.home.stateVersion = "26.05"; };
      };
    };
  };
}
```

</details>

## Fechamento dos gates pendentes

### Nova execução dos três testes alterados

Fonte comum: `aecb3822e8920a95acc8bcb2a2935acd3817fccf`. O worktree estava limpo antes do export e cada arquivo da allowlist exportada foi comparado byte a byte com `git show <SHA>:<arquivo>`. Usei os checks existentes, sem alterar fixtures ou derivar novos testes. Com Nix 2.35.5, `--rebuild` voltou a executar cada builder e comparou sua saída à anterior; não removeu outputs do store compartilhado. O log de **cada** invocação contém `checking outputs of '<drv>'`, `machine: starting vm`, `Hypervisor detected: KVM` no kernel convidado e `test script finished`.

```bash
export NIX_CONFIG=$'builders =\nexperimental-features = nix-command flakes'
src=$(python3 -B scripts/export-source.py)
for t in desktop-access desktop-snapshots tailscale; do
  f="path:$src#checks.x86_64-linux.$t"
  nix eval --offline --no-write-lock-file --raw "$f.drvPath"
  timeout -k 20 720 nix build --rebuild --offline --no-link --no-write-lock-file --print-build-logs "$f"
done
```

| Check | Derivação realizada (prefixo `/nix/store/`) | Evidência nova e cenários | Status |
| --- | --- | --- | --- |
| `desktop-access` | `yyv5i35n0ycbhivy2x7c5y99fg3a7pkj-vm-test-run-desktop-overlay-access.drv` | KVM, script 57,95 s. Passaram a matriz IPv4/IPv6 de portas e origens, o controle que confirma listeners e rotas de retorno, a política SSH e o login com autorização externa de runtime. O DNS permaneceu inalterado após reiniciar o daemon na VM. | 0 |
| `desktop-snapshots` | `v13ypqc0x03ibjhpxsxspjwa5r0lk9qq-vm-test-run-desktop-home-snapshots.drv` | KVM, script 14,93 s. Snapshot Btrfs reteve o conteúdo anterior; passaram as verificações de diretório privado `root:root:700`, retenção dos sete snapshots e reaplicação do preparo sem perder snapshots. | 0 |
| `tailscale` | `nyqv13pv12wmp2yf9c1vlzk7m8xmn2fq-vm-test-run-ordis-tailscale-firewall.drv` | KVM, script 37,69 s. Passaram configuração bloqueada e persistência do daemon, preservação de DNS após reinício, política SSH e matriz LAN/overlay IPv4/IPv6. O subteste Pi-hole/Tailscale concluiu sem ampliar o acesso DNS (10,44 s). | 0 |

### Diferença objetiva nas unidades geradas

Comparei a baseline `3c1b2b759930fb36327fe20e01ae7349ef3a842c` com `aecb3822e8920a95acc8bcb2a2935acd3817fccf`. Não houve inclusão ou remoção em `systemd.units`. O mapa inteiro de Ordis é idêntico; desktop e lab diferem nas mesmas quatro unidades. Em cada par de arquivos de unidade, substituir **somente** o componente de hash de 32 caracteres dos caminhos do store torna o conteúdo byte a byte igual, preservando nomes, sufixos, flags e diretivas de dependência e restart. Os valores abaixo são os observados nos dois PCs (hashes omitidos onde basta mostrar a mudança).

| Unidade | Campo | Antigo → novo |
| --- | --- | --- |
| `home-manager-rinyaresu.service` | `ExecStart` | O mesmo executável `hm-setup-env` e o mesmo número de argumentos; muda apenas o argumento `…-home-manager-generation`. Hash desktop `b35f6kci… → z12bd8k6…`; lab `3hz73zxb… → 47a9jmq8…`. O script `activate` referenciado também é igual após normalizar hashes. |
| `mandb.service` | `ExecStart` | Mesma chamada `…-unit-script-mandb-start/bin/mandb-start`, sem argumentos novos. Hash desktop `bi3yiphx… → vnjd4q3n…`; lab `7cijr508… → g0xcwx1l…`. O conteúdo do wrapper também só difere nos hashes. |
| `dbus-broker.service` | `X-Restart-Triggers` | Muda o hash de `…-X-Restart-Triggers-dbus-broker`: desktop `rjqj6ax0… → kz8w0jy2…`; lab `l5gl2fyz… → c79r9wmb…`. O arquivo aponta nos dois lados para `…-dbus-1`, também com hash diferente. |
| `polkit.service` | `X-Restart-Triggers` | Muda o hash de `…-X-Restart-Triggers-polkit`: desktop `ybi2j60z… → 1a1k6rkl…`; lab `msfc2q68… → m9r9dzrb…`. O arquivo aponta nos dois lados para `…-system-path`, também com hash diferente. |

Não houve mudança declarativa no comando lógico, na estrutura dos argumentos, nas dependências ou nas diretivas de restart; **os valores absolutos dos gatilhos mudaram**. Uma troca de geração pode tratar essas unidades como alteradas e reiniciá-las. Esta comparação não demonstra quais unidades serão efetivamente reiniciadas ou o efeito disso numa máquina em uso; não executei ativação, nem simulei uma troca no host.

Para reproduzir, exporte ambas as revisões e gere as projeções acima (para não trocar de branch, extraia a baseline via `git archive <SHA> | tar -x -C <diretório-temporário>` dentro do worktree e execute seu exportador ali). Compare as chaves e os valores de `services.unitFiles`; para cada valor diferente, resolva `nix-store -q --outputs <drv>` e compare `<output>/<unidade>` primeiro sem filtro, depois aplicando `re.sub(r'/nix/store/[0-9a-z]{32}-', '/nix/store/HASH-', texto)` em ambos os lados. Repita para o wrapper `mandb-start`, o `activate` da geração HM e o arquivo apontado por cada `X-Restart-Triggers`. Não trate a normalização como igualdade de identidade dos store paths.

### CI remota da revisão `aecb382`

O workflow **Checks** é acionado pelos dois eventos. O checkout fixado em `.github/workflows/check.yml` não recebe `ref` explícito: em `push` usa o SHA da branch; em `pull_request` usa o merge ref, embora a API liste o HEAD do PR em `head_sha`. Os pais do merge ref foram conferidos pela API, e sua árvore (`ab1b3ceda2c0dc88c53df80b27f3f11c36b62f80`) é idêntica à de `aecb382`. A identificação do checkout de PR se apoia no workflow e no merge ref observado antes do novo push, não em um log final ainda indisponível.

| Evento | Run | Revisão do checkout | Estado observado em 2026-11-18 02:28 UTC |
| --- | --- | --- | --- |
| `push` | [44222377417](https://github.com/Rinyaresu/dots/actions/runs/44222377417) | `aecb3822e8920a95acc8bcb2a2935acd3817fccf` | Em execução; sem conclusão |
| `pull_request` | [44222382867](https://github.com/Rinyaresu/dots/actions/runs/44222382867) | `0c633f8f88fe4fc04f6f5e5ad57ddca788d903fc` (merge ref), com HEAD do PR em `aecb3822e8920a95acc8bcb2a2935acd3817fccf` | Em execução; sem conclusão |

Reprodução: `gh api --method GET 'repos/Rinyaresu/dots/actions/runs?head_sha=aecb3822e8920a95acc8bcb2a2935acd3817fccf'` lista evento e estado; `git ls-remote origin refs/pull/3/merge` mostra o merge **atual**, que acompanha novos pushes e não deve ser usado para identificar retroativamente aquele run.

## Limites para revisão

Esta etapa não altera CI, fonte Git, árvore final nem aceitação separada. As VMs que o check atual avalia ou realiza não equivalem ao futuro gate de sete execuções por SHA candidato. A configuração efetiva declarada e os builds no store não comprovam rede, dispositivos, sessão ou instalação nas máquinas. Não foi feito deploy, ativação, SSH para Ordis ou reboot. Revisar o escopo dos grupos, a recusa de conta inválida e as novas referências de store das duas estações antes da próxima etapa.
