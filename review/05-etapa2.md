# Etapa 2 — módulos por responsabilidade

Baseline da etapa 1: `c0e23752de08288188d508f382e9b9123125049a`. Candidato funcional: `85b25a5ae61a315ab962a6f3fe01b7afce275544`. Referência examinada: [dotnix @ 50ad795](https://github.com/kiriwalawren/dotnix/tree/50ad795e920d187bb56e064430f92c10326e6f66/modules).

## Correspondência com dotnix

- [CLI](https://github.com/kiriwalawren/dotnix/tree/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/interfaces/cli): Fish em `shells`, Git no nível CLI, agentes em `ai`, editor e toolchain no domínio CLI. Fish e Git da referência contribuem ao grupo `base`; aqui se mantêm as capacidades individuais que já são consumidas por outros módulos e pelas fixtures.
- [GUI](https://github.com/kiriwalawren/dotnix/tree/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/interfaces/gui): apps separam navegadores, comunicação e emulador de terminal; desktop contém gerenciador de arquivos, compositor e sessões. Mantemos Niri e i3 como seletores explícitos; não introduzimos wrappers, greeter ou apps do autor. Bluetooth e áudio ficam em `interfaces/` e fonte em `theme/`, como na referência.
- [Sistema](https://github.com/kiriwalawren/dotnix/tree/50ad795e920d187bb56e064430f92c10326e6f66/modules/system): `networking`, `storage`, `boot` e `users` contêm capacidades de seus domínios; `ssh.nix`, `sops.nix` e `virtualisation.nix` ficam no nível de sistema. Docker acompanha o CLI como na referência. Nosso `common` não recebe HM nem conta pessoal.
- [Servidor](https://github.com/kiriwalawren/dotnix/tree/50ad795e920d187bb56e064430f92c10326e6f66/modules/server/networking): Pi-hole ocupa o domínio em que dotnix mantém AdGuard Home; módulo, helper e patch movidos juntos, sem mudanças de conteúdo.
- [Hosts](https://github.com/kiriwalawren/dotnix/tree/50ad795e920d187bb56e064430f92c10326e6f66/modules/hosts/framework13): `modules.nix` seleciona capacidades e `configuration.nix` importa hardware bruto. Apenas desktop e Ordis têm hardware bruto; o lab mantém a configuração de VM. O prefixo `_` exclui os dois arquivos de `import-tree`; a avaliação passa com os imports explícitos. Fragmentos locais de Home Manager, acesso, manutenção e servidor foram preservados por separarem opções e fornecerem entradas aos checks atuais.
- `modules/nix/` mantém montagem, ponte HM, configurações Nix e publicação de checks. A CI, o exportador, as fixtures, o lock e a documentação permanente não mudaram.

## Mapa antigo → novo

Caminhos abaixo relativos a `modules/`.

| Antigo | Novo |
| --- | --- |
| `features/nix-settings.nix` | `nix/nix-settings.nix` |
| `features/pihole/admin-hash.py` | `server/networking/pihole/admin-hash.py` |
| `features/pihole/api-no-argv-secrets.patch` | `server/networking/pihole/api-no-argv-secrets.patch` |
| `features/pihole/default.nix` | `server/networking/pihole/default.nix` |
| `features/limine.nix` | `system/boot/limine.nix` |
| `features/bluetooth.nix` | `system/interfaces/bluetooth.nix` |
| `features/pi.nix` | `system/interfaces/cli/ai/pi.nix` |
| `features/providers.nix` | `system/interfaces/cli/ai/providers.nix` |
| `features/docker.nix` | `system/interfaces/cli/docker.nix` |
| `features/git.nix` | `system/interfaces/cli/git.nix` |
| `features/herdr.nix` | `system/interfaces/cli/herdr.nix` |
| `features/neovim.nix` | `system/interfaces/cli/neovim.nix` |
| `features/fish.nix` | `system/interfaces/cli/shells/fish.nix` |
| `features/toolchain.nix` | `system/interfaces/cli/toolchain.nix` |
| `features/tools.nix` | `system/interfaces/cli/tools.nix` |
| `features/chrome.nix` | `system/interfaces/gui/apps/browsers/chrome.nix` |
| `features/firefox.nix` | `system/interfaces/gui/apps/browsers/mozilla/firefox.nix` |
| `features/discord.nix` | `system/interfaces/gui/apps/communication/discord.nix` |
| `features/applications.nix` | `system/interfaces/gui/apps/desktop-personal.nix` |
| `features/obs.nix` | `system/interfaces/gui/apps/obs.nix` |
| `features/spotify.nix` | `system/interfaces/gui/apps/spotify.nix` |
| `features/stremio.nix` | `system/interfaces/gui/apps/stremio.nix` |
| `features/ghostty.nix` | `system/interfaces/gui/apps/terminal/ghostty.nix` |
| `features/files.nix` | `system/interfaces/gui/desktop/file-manager.nix` |
| `features/i3/default.nix` | `system/interfaces/gui/desktop/i3/default.nix` |
| `features/i3/tools.nix` | `system/interfaces/gui/desktop/i3/tools.nix` |
| `features/niri.nix` | `system/interfaces/gui/desktop/niri/niri.nix` |
| `features/graphics.nix` | `system/interfaces/gui/graphics.nix` |
| `features/polkit.nix` | `system/interfaces/gui/security.nix` |
| `features/unfree-desktop.nix` | `system/interfaces/gui/unfree.nix` |
| `features/sound.nix` | `system/interfaces/sound.nix` |
| `features/locale.nix` | `system/locale.nix` |
| `features/networking.nix` | `system/networking/network.nix` |
| `features/tailscale.nix` | `system/networking/tailscale.nix` |
| `features/wireguard.nix` | `system/networking/wireguard.nix` |
| `features/no-hibernation.nix` | `system/no-hibernation.nix` |
| `features/sops.nix` | `system/sops.nix` |
| `features/ssh-agent.nix` | `system/ssh.nix` |
| `features/home-snapshots.nix` | `system/storage/home-snapshots.nix` |
| `features/zram.nix` | `system/storage/zram.nix` |
| `features/fonts.nix` | `system/theme/font.nix` |
| `users/rinyaresu/default.nix` | `system/users/rinyaresu/default.nix` |
| `users/rinyaresu/pi-bootstrap.nix` | `system/users/rinyaresu/pi-bootstrap.nix` |
| `users/rinyaresu/ssh.nix` | `system/users/rinyaresu/ssh.nix` |
| `features/sudo.nix` | `system/users/sudo.nix` |
| `features/virtualisation.nix` | `system/virtualisation.nix` |
| `hosts/{desktop,ordis}/hardware.nix` | `hosts/{desktop,ordis}/_hardware-configuration.nix` (módulo NixOS bruto), importado por `configuration.nix` |
| `nix/host-groups.nix` | Removido; contribuições distribuídas abaixo |

`source-files.txt` acompanha esses movimentos. Os nomes das capacidades e as 23 saídas verificadas foram mantidos.

## Contribuições distribuídas

Cada arquivo contribui ao grupo em sua classe, no mesmo lugar em que publica a capacidade. A composição é a mesclagem nativa dos módulos deferidos, sem seleção paralela. Os imports locais reutilizam as capacidades que já têm consumidores e identidade própria.

| Grupo | Contribuições |
| --- | --- |
| `common`, NixOS | Nix settings, rede, locale e sudo nos respectivos módulos. |
| `base`, NixOS | Nix settings incorpora `common`; identidade, ferramentas, SSH agent e toolchain contribuem localmente. |
| `base`, HM | Identidade/Git, Fish, Herdr, Neovim, Pi e providers. |
| `gui`, NixOS | Unfree, gráficos, fontes, polkit, gerenciador de arquivos, Firefox, Bluetooth e áudio. |
| `gui`, HM | Chrome, Discord, arquivos, Firefox, Ghostty, OBS, Spotify, Stremio, polkit e áudio. |
| `desktop-personal`, NixOS e HM | SSH/SOPS pessoal e bootstrap no diretório do usuário. Layout TreeView em Herdr e apps pessoais em GUI contribuem apenas a HM. |

## Comparação incremental

| Commit | Família | Prefixos dos toplevels desktop / lab / Ordis |
| --- | --- | --- |
| `da83bd3` | Sistema e `common` | `j0cfkajdjf / i45931211y / hyq4ikh6fa` (projeção idêntica à baseline) |
| `86a4b5f` | CLI e usuários | `qzmx3s2z7s / n96bc416n2 / hyq4ikh6fa` |
| `e9163c3` | GUI e remoção do agregador | `1ll0clk7px / mj2anq2zyv / hyq4ikh6fa` |
| `0f6991d` | Pi-hole | Mesmos três da GUI |
| `85b25a5` | Hardware bruto | Mesmos três da GUI |

Usei a projeção Nix em [Etapa 1](04-etapa1.md) após cada família. Boot, mounts e swap, contas e fingerprints SSH, rede, DNS declarado, firewall, estado NixOS/HM, associação HM, nomes dos segredos e serviços habilitados permaneceram iguais. O lab conserva `-nic none`, rede restrita, nenhum diretório compartilhado e nenhum mount do store do host. A derivação da VM mudou com seu sistema. Ordis conserva a projeção inteira e a mesma derivação, sem HM.

Nos dois PCs, o multiconjunto de derivações dos pacotes não mudou, mas mudou sua ordem de merge. Os links em `sw` (15.288/15.304) e `home-path` (1.058/964) têm exatamente os mesmos nomes e alvos. Os arquivos HM com novos alvos são fontconfig, manpath e completions Fish: os dois primeiros só mudaram hashes de store, e os links das completions permaneceram idênticos. Quatro unidades mudaram somente referências de store em `ExecStart` (HM e mandb) e `X-Restart-Triggers` (dbus-broker e polkit), sem alterar opções declaradas de restart. Uma futura troca de geração ainda pode disparar reinícios; não foi executada.

## Verificação no candidato

O export explícito usado para build e VMs foi comparado com `git show <SHA>:<arquivo>` em todos os arquivos da allowlist. Nix 2.35.5, builders remotos desabilitados, nenhum deploy ou ativação.

```bash
export NIX_CONFIG=$'builders =\nexperimental-features = nix-command flakes'
s=$(python3 -B scripts/export-source.py)
nix eval --offline --no-write-lock-file --json "path:$s#nixosConfigurations" \
  --apply "$(<projection.nix)" # projeção inalterada de review/04-etapa1.md
args=()
for h in desktop lab ordis; do args+=("path:$s#nixosConfigurations.$h.config.system.build.toplevel"); done
nix build --offline --no-link --no-write-lock-file -L "${args[@]}"
./scripts/check
for t in desktop-access desktop-snapshots tailscale pihole secret-runtime bootstrap-runtime ssh-session; do
  f="path:$s#checks.x86_64-linux.$t"
  nix eval --offline --no-write-lock-file --raw "$f.drvPath"
  timeout -k 20 720 nix build --rebuild --offline --no-link --no-write-lock-file -L "$f"
done
```

Os três builds retornaram 0; desktop e lab foram construídos e Ordis pôde reaproveitar sua derivação idêntica. Para reproduzir a comparação de artefatos, resolva `nix-store -q --outputs <drv>` e compare nomes/alvos dos links e as unidades como descrito em [Etapa 1](04-etapa1.md).

`./scripts/check` retornou 0: 15 unittests, formatter, avaliação das 23 saídas, realização pelo gate atual e `all checks passed!`. O check `secret-build-boundary` foi realizado de novo. A realização individual abaixo é independente do wrapper: o log de cada `--rebuild` registra início de VM, `[    0.000000] Hypervisor detected: KVM` no convidado e a conclusão do script. A contagem KVM inclui reinicializações quando presentes.

| Check | Derivação (prefixo `/nix/store/`) | Marcadores KVM | Trecho do log | Exit |
| --- | --- | ---: | --- | ---: |
| `desktop-access` | `yyv5i35n0ycbhivy2x7c5y99fg3a7pkj-vm-test-run-desktop-overlay-access.drv` | 1 | `test script finished in 58.27s` | 0 |
| `desktop-snapshots` | `v13ypqc0x03ibjhpxsxspjwa5r0lk9qq-vm-test-run-desktop-home-snapshots.drv` | 1 | `test script finished in 15.10s` | 0 |
| `tailscale` | `nyqv13pv12wmp2yf9c1vlzk7m8xmn2fq-vm-test-run-ordis-tailscale-firewall.drv` | 1 | `test script finished in 35.94s` | 0 |
| `pihole` | `1y93jfvf2psyc657k7h101ckyxl74ajh-vm-test-run-pihole-network.drv` | 5 | `test script finished in 62.21s` | 0 |
| `secret-runtime` | `7n4af5ah59nfbka9dg5jbj037p2rm1x7-vm-test-run-secret-runtime.drv` | 1 | `test script finished in 77.05s` | 0 |
| `bootstrap-runtime` | `is4632ck3sr7xxcnzk7g82ipw2vabv39-vm-test-run-bootstrap-runtime.drv` | 1 | `test script finished in 36.09s` | 0 |
| `ssh-session` | `2xny2aahwcr0k8v3krjlbjv5ry7wpy3d-vm-test-run-ssh-session.drv` | 1 | `test script finished in 14.98s` | 0 |

As VMs cobrem as políticas de acesso desktop e Ordis, retenção e permissões Btrfs, Pi-hole em LAN, material sintético do SOPS no runtime, restore do bootstrap e SSH em sessão. Em `secret-runtime`, o log da reexecução também registra `PASS exact private fixture bytes absent from 49414 regular store files`. Isso é evidência da fixture, não auditoria de máquinas instaladas.

**Fronteiras de fonte e descoberta.** `git+file://$PWD?rev=85b25a5ae61a315ab962a6f3fe01b7afce275544#nixosConfigurations` deu a mesma projeção JSON byte a byte do export. A fonte Git materializada inclui `review/` e o ciphertext autorizado; o export atual exclui `review/`. O diff não adicionou material sensível, não moveu nem alterou o ciphertext e não altera o mecanismo de fonte atual. Na fonte exportada, a lista real `((inputs.import-tree <export>/modules) {}).imports` contém 67 módulos, sem os dois arquivos `_hardware-configuration.nix` nem helpers Python/patch. Os arquivos brutos são selecionados pelos imports de `configuration.nix`, não pelo flake-parts.

**CI da etapa 1.** Na última consulta antes de fechar este relatório, estavam em andamento os runs de [push](https://github.com/Rinyaresu/dots/actions/runs/44222377417) e [PR](https://github.com/Rinyaresu/dots/actions/runs/44222382867) de `aecb382` e os de [push](https://github.com/Rinyaresu/dots/actions/runs/44223679561) e [PR](https://github.com/Rinyaresu/dots/actions/runs/44223686615) de `c0e2375`. Sem resultado satisfatório confirmado, não considero a etapa 1 definitivamente aprovada e mantenho a etapa 2 local.

## Ajuste final de fidelidade

A referência separa os aplicativos por arquivo e publica as opções no grupo, como em `apps/spotify.nix`, `apps/bitwarden-desktop.nix` e `apps/communication/slack.nix`. Conferi seletores de host, imports diretos e aliases locais de `flake.modules` usados por checks e fixtures antes de remover nomes.

- `0ad62f6`: agora contribuem diretamente a `homeManager.gui` Chrome, Firefox, OBS, Spotify, Stremio, gerenciador de arquivos e agente gráfico do polkit. Bluetooth, gráficos, MIME do Firefox, GVFS e polkit contribuem a `nixos.gui`, sem mudar opções ou políticas. Neovim, providers e identidade/Git pessoal contribuem diretamente a `homeManager.base`; identidade NixOS, ferramentas e toolchain a `nixos.base`; locale e sudo a `nixos.common`. O layout pessoal do Herdr contribui diretamente a `homeManager.desktop-personal`, ainda importando o módulo Herdr usado em `base`.
- `7811774`: Anki, Bitwarden Desktop, DBeaver, Obsidian e VS Code ganharam arquivos próprios em `modules/system/interfaces/gui/apps/`. Cada arquivo contribui a `homeManager.desktop-personal`, sem nome intermediário. Os cinco pacotes e o override de ripgrep do VS Code foram preservados; a allowlist foi atualizada.

| Capacidades nomeadas mantidas | Consumidor independente |
| --- | --- |
| HM `discord` | `checks/graphical.nix` seleciona apenas Discord ao lado das sessões. |
| HM `ghostty` | Niri e i3 importam o terminal; o check de arquitetura exerce o diamante e a recusa de classe errada. |
| NixOS e HM `sound`, NixOS `fonts` e `unfree-desktop` | Fixture gráfica para o lado NixOS; o check de arquitetura testa áudio HM isoladamente sem o lado NixOS. |
| Fish, Git, Pi e Herdr | Conta NixOS importa Fish; Herdr e providers dependem de Fish HM; identidade e fixture de arquitetura importam Git HM; bootstrap importa Pi e o check testa sua deduplicação; TreeView importa Herdr. |
| NixOS `networking`, `nix-settings` e `ssh-agent` | Fixtures de acesso, snapshots e sessão SSH; bootstrap também importa o agente. |
| NixOS e HM `rinyaresu-ssh` e `pi-bootstrap` | Fixtures de segredos/bootstrap e asserções de arquitetura exercem as capacidades isoladas. |

### Validação do ajuste

Referência de comparação: `85b25a5ae61a315ab962a6f3fe01b7afce275544`. Candidato funcional: `7811774336d6cfaa68a4dd02ea363e0f83e141c8`. O export do candidato foi conferido byte a byte com o commit. Repeti os comandos de projeção e build acima e `./scripts/check`. Os três toplevels foram resolvidos e realizados com exit 0.

- Ordis: projeção e toplevel idênticos; continua sem Home Manager.
- Desktop e lab: projeção preservada para identidade, boot, mounts, rede, SSH, firewall, serviços habilitados, estado e isolamento do lab. Mudou a ordem das listas de pacotes, sem mudança no multiconjunto de derivações. Todos os links de `sw` (15.288/15.304) e `home-path` (1.058/964) conservaram nomes e alvos.
- As diferenças em fontconfig, manpath e scripts de ativação Home Manager desapareceram ao normalizar hashes de store; os links das completions Fish foram iguais. As quatro unidades com nova derivação (HM, mandb, dbus-broker e polkit) também tiveram conteúdo igual após normalizar hashes. Os novos caminhos em `ExecStart` e `X-Restart-Triggers` não provam ausência de reinício numa troca de geração, que não foi executada.

A primeira avaliação do wrapper revelou que `home.sound` ainda era consumido por `reject-audio-without-system`; preservei o módulo em vez de adaptar a asserção. No candidato final o wrapper terminou com exit 0 e avaliou os 23 checks. Comparei todo `checks.x86_64-linux` via `--apply 'builtins.mapAttrs (_: v: v.drvPath)'` para as duas fontes exportadas. Apenas `secret-build-boundary` (auditoria de artefatos desktop) e `secret-runtime` (fixture inclui a fonte exportada) mudaram. Os dois foram realizados novamente no wrapper. A VM `rfxp2rrbfx25igf8wq8r9km0f6zrni78-vm-test-run-secret-runtime.drv` registrou `Hypervisor detected: KVM` e `test script finished in 83.21s`. As outras seis VMs mantiveram as mesmas derivações e não foram forçadas nesta rodada. A [intermitência preexistente do Pi-hole](https://github.com/Rinyaresu/dots/pull/3#issuecomment-6967660331) continua aberta; o check e a implementação não mudaram.

## Limites e pendências

Não há comprovação de troca de geração, sessão gráfica, rede ou instalação em máquina física. Não houve mudanças em Home, Agent ou Dev, nem execução da etapa de migração da CI. Os relatórios são temporários.
