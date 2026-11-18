# Etapa 3: CI e fonte Git nativas

Baseline exportada: `262c9131bf711cc1c6384e81ef150d3fc072a254`. Os dois workflows da baseline passaram. Confirmei `master` em `96dcf1363828e565d2bc3787d25f0df8f297db77`, e PR #2 aberto e sem conflitos em `104a3f1e96114c54bbfe6afb48c4dab38a11c6cf`. Candidato funcional testado: `32ce0d617754803fdfbe9f7357ea6ed027b363fb`. Este relatório é temporário.

## Matriz final dos 23 checks

| Antes | Destino e cobertura |
| --- | --- |
| `architecture` | Removido o catálogo. Toplevels exercitam asserções de conta, dependências e classes; lab e Ordis ganharam invariantes locais. Paridade dos consumidores reais verificada nesta etapa, sem fixture multicontas. |
| `module-system` | Removidas as provas genéricas de merge, chave e deduplicação e as respectivas fixtures. |
| `migration-options` | Substituído pela comparação pontual de opções e toplevels; não congela o catálogo de aplicações. |
| `desktop-policies` | Opções efetivas, comparação de manutenção/GC e VMs desktop de acesso e snapshots. Não interpreta regras shell como texto. |
| `desktop-access` | `packages.x86_64-linux.desktop-access`, a mesma VM de SSH, overlay e firewall. |
| `desktop-snapshots` | `packages.x86_64-linux.desktop-snapshots`, a mesma VM Btrfs/Snapper. |
| `graphical-policy` | Toplevels exercitam os pré-requisitos de i3, Niri e Secret Service já declarados. Comportamento dos wrappers continua testado. |
| `graphical-behavior` | Mantido; lê Home Manager e startx do desktop. A derivação ficou igual à baseline. |
| `graphical-config` | Mantido: Niri valida desktop e lab; Ghostty e Noctalia validam as configurações reais. Saiu a validação duplicada da fixture. |
| `session-contract` | Asserções existentes de exclusividade e duração do agente e requisitos do bootstrap; comportamento em checks focados. |
| `herdr-tree-config` | Mantido. Binário Herdr valida TOML do desktop; asserção rejeita TreeView pessoal no lab. |
| `shell-session` | Mantido com Fish real. |
| `shell-providers` | Mantido com Fish, mise e direnv reais. |
| `bootstrap-session` | Mantido; cancelamento, seleção e prólogo são distintos da convergência do restore. |
| `ssh-session` | `packages.x86_64-linux.ssh-session`, a mesma VM com sshd e agente reais. |
| `ssh-agent` | Mantido; ciclo de identidade no agente real. |
| `pi-bootstrap-restore` | Mantido; convergência, disputa de destino, recusa e recuperação. |
| `secret-build-boundary` | Mantido e direcionado ao desktop real. Manifest, owner/mode, identidade externa sem fallback e link da ativação; não depende de um nó de teste. |
| `secret-runtime` | `packages.x86_64-linux.secret-runtime`; mantém cenários runtime e scanner de bytes da fixture, recebe só o ciphertext em vez da raiz. |
| `bootstrap-runtime` | `packages.x86_64-linux.bootstrap-runtime`, a mesma VM SOPS → HM → agente → Git descartável. |
| `pihole-policy` | Avaliação de opções, VM fail-closed e asserções locais para loopback e firewall. Nenhuma mudança operacional no serviço. |
| `pihole` | `packages.x86_64-linux.pihole`, mesma derivação e mesmas asserções. |
| `tailscale` | `packages.x86_64-linux.tailscale`, mesma VM com preferências e firewall do Ordis. |

Os dez outputs `checks.x86_64-linux` são `formatting`, `bootstrap-session`, `graphical-behavior`, `graphical-config`, `herdr-tree-config`, `pi-bootstrap-restore`, `secret-build-boundary`, `shell-providers`, `shell-session` e `ssh-agent`. As sete entradas acima são todos os outputs `packages.x86_64-linux`. O flake check avalia seus tipos e derivações, sem realizar VMs. Não publica toplevels como checks.

Removidos `source-files.txt`, `scripts/export-source.py`, `scripts/check`, `.githooks/pre-push`, `checks/{automation_test,source_test}.py`, `checks/graphical.nix`, os quatro arquivos de `checks/modules/` e os dois módulos `migration-checks.nix` e `module-system-checks.nix`. O catálogo `architecture` deixou de existir; o teste de restore permaneceu em `modules/nix/checks.nix`. `AGENTS.md` e `README.md` usam os novos comandos. A revisão geral de `docs/` fica pendente. Não mudou `flake.lock` nem scripts de runtime.

## Fonte, store e limite de segurança

Antes de retirar o exportador, sua baseline concluiu `./scripts/check`, 15 testes do wrapper e 23 derivações avaliadas. A transição `fc8eeeb`, ainda com exportador rastreado, passou no check nativo e produziu projeção exatamente igual. Uma avaliação intermediária havia detectado recursão no import do Pi-hole por sombreamento de `config`; foi corrigida sem alterar o módulo importado.

`nix flake archive --json` materializou a fonte Git do candidato. Comparei o inventário e os bytes com `git ls-tree` e os blobs do SHA. A baseline exportada tinha 107 arquivos; a fonte Git funcional tem 115, com 21 entradas novas no snapshot (workflow, gitignore e Markdown de raiz, docs, review e secrets) e 13 retiradas. Este relatório acrescenta um Markdown ao snapshot de publicação. Nenhum gitlink ou symlink rastreado. Revisão de nomes, conteúdo e padrões de chave privada/age/token encontrou o envelope autorizado `secrets/ssh.yaml`; os marcadores falsos do teste do exportador foram removidos junto com ele. Não encontrei material privado em claro. Isso não é garantia absoluta nem auditoria de todo o histórico ou da máquina.

A fonte Git completa pode residir no store para avaliação; isso não significa que integra o fechamento dos resultados. Os três toplevels têm a mesma derivação e o mesmo output da baseline, logo não ganharam arquivos no fechamento. Seis VMs também têm derivações idênticas. O delta de entradas de fonte (referências recursivas sem `.drv`) na sétima VM, `secret-runtime`, é apenas a remoção do snapshot exportado completo. O caminho store de `ssh.yaml` já existia na baseline e continua igual. O scanner da VM confronta os bytes dos segredos descartáveis com os arquivos regulares do seu store. O check de formatação usa somente fontes Nix como insumo da própria derivação, não como filtro de flake. Identidade age e chave descriptografada de produção continuam externas à fonte e à construção; o teste usa identidade e chave descartáveis criadas na VM.

## Validação local

Fonte imutável: `src="git+file://$PWD?rev=32ce0d617754803fdfbe9f7357ea6ed027b363fb"`. Com Nix com flakes:

- `nix eval --json "$src#nixosConfigurations" --apply "$(<projecao.nix)"`: mesma projeção da etapa 2 para os três hosts (identidade, boot, mounts, rede, SSH, firewall, serviços, pacotes, Home Manager e isolamento). Ordis segue sem Home Manager. Lab mantém store próprio, sem compartilhamentos ou rede.
- `nix build --no-link -L "$src#nixosConfigurations.<host>.config.system.build.toplevel"`: exit 0 nos três, mesmas derivações e outputs da etapa 2.
- `nix flake check --show-trace "$src"`: exit 0. `nix fmt -- --check flake.nix` na árvore limpa também passou; o check `formatting` verifica todas as fontes Nix.
- Para cada VM, `nix build --offline --no-link --no-write-lock-file --rebuild -L "$src#packages.x86_64-linux.<nome>"`. Só conta como reexecução se o log do guest registra KVM e um desfecho.

| VM | Exit | Tempo do script no guest |
| --- | --- | --- |
| desktop-access | 0 | 57,24 s |
| desktop-snapshots | 0 | 15,25 s |
| tailscale | 0 | 35,13 s |
| pihole | 0 | 52,81 s |
| secret-runtime | 0 | 103,67 s |
| bootstrap-runtime | 0 | 36,42 s |
| ssh-session | 0 | 13,52 s |

Todos registraram `Hypervisor detected: KVM`. Para `secret-runtime`, a tentativa inicial com `--rebuild` não executou a VM: o novo output ainda não existia. Repeti sem `--rebuild` para a primeira realização, sem mudar fonte nem teste. O script terminou com `PASS exact private fixture bytes absent from 49311 regular store files`. O passe de Pi-hole não encerra a intermitência.

## CI e divergências da referência

A [CI do dotnix](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/.github/workflows/ci.yml) inspira os três jobs. Aqui `check` é leve e `prepare` lê nome e `config.nixpkgs.hostPlatform.system` das configurações reais. Executei localmente o bloco shell de `prepare`: desktop, lab e Ordis, todos `x86_64-linux` em `ubuntu-24.04`. `builds` consome a matriz com `fail-fast: false` e é o único job que constrói toplevels. Formatter usa nixfmt fixado no lock e um check nativo em vez de introduzir treefmt-nix e alterar o lock. A referência usa cache autenticado e SSH privado; este PR não usa nenhum dos dois. Actions fixadas por SHA. Limpeza de SDKs não utilizados só nos runners hospedados de `check` e `builds`. O [primeiro run](https://github.com/Rinyaresu/dots/actions/runs/44287968211), head `b418abde10e153460112f453990ff547d00005f5`, confirmou a merge ref `7a74b17e8f554d400ce4e852ed9b895605e95a1f` nos logs de `check`, `prepare` e build de Ordis. `prepare` e Ordis passaram; `check` falhou por falta de espaço ao materializar Satty. A correção compartilha a limpeza de SDKs com `check`, sem retirar verificações.

Todos os jobs fazem checkout explícito de `github.sha`, verificam `HEAD` e imprimem SHA e pais nos logs. No PR, é a merge ref, não o SHA listado como head do PR. Em push a `master`, é o commit enviado; no dispatch, o commit do disparo. Push à branch do PR não satisfaz o filtro de push. A [execução remota vinculada ao SHA do PR](https://github.com/Rinyaresu/dots/pull/3/checks) deve ser conferida pelo checkout de cada job, não só pelo SHA da listagem. A publicação da revisão deste relatório dispara essa execução; o corpo do PR registra os IDs e o estado observados após o push.

## Revisão de segurança após `2f67213`

| Garantia dos checks antigos | Proteção atual e limite |
| --- | --- |
| Pi-hole só em Ordis; administração local; sem aberturas globais | Asserções dos três hosts rejeitam seleção indevida, serviço web desabilitado, bind fora de `127.0.0.1:8080` ou abertura global por FTL. A VM testa bind, rejeição do cliente LAN e filtragem DNS fora da LAN autorizada. |
| Sem DHCP, NTP servidor IPv4/IPv6 nem sincronização NTP do FTL | Nova asserção conjunta no módulo Pi-hole. A VM já verificava ausência de listeners UDP nas portas 67 e 123, não a opção de sincronização. |
| Credencial externa e FTL mínimo, somente leitura | Novas asserções no módulo Pi-hole fixam `LoadCredential` no arquivo externo e exigem `misc.readOnly`, ambient capabilities e bounding set limitados a `CAP_NET_BIND_SERVICE`. A VM testa ausência/invalidade fail-closed, autenticação, permissões e ausência do hash no TOML. |
| SSH desktop não exposto fisicamente; autenticação restrita e chaves externas | Asserções em `desktop/access.nix` restringem as opções estruturadas de firewall e SSH efetivas. `desktop-access` testa as regras shell do firewall efetivo e as conexões física/overlay, e valida autenticação, root, modos e caminhos no sshd da fixture. Regras shell arbitrárias não são analisadas estaticamente; essa evidência de runtime depende do gate separado, não do CI regular. A ausência de overlay no lab já é asserção local. As flags de Tailscale são declarações, não uma asserção de igualdade entre hosts. |
| GC manual | Asserção em `common` rejeita `nix.gc.automatic` ou timer `nix-gc` nos três hosts. A janela declarada do opt-in não é bloqueada como snapshot; habilitá-lo em um host agora requer mudar explicitamente a guarda. |
| Snapshots privados e política diária | `desktop-snapshots` exercita o módulo desktop compartilhado, Btrfs, limite diário, catch-up, negação ao usuário e ausência de snapshot root no boot. Não há mais catálogo que rejeite todo ajuste de retenção ou confira a ausência de Snapper nos outros hosts; sem mudanças efetivas nesta revisão. |
| Agente nativo único, sem expiração | Asserção NixOS agora também exige `startAgent`; as guardas existentes rejeitam GCR e `agentTimeout` não nulo. Home Manager já exige agente/askpass para bootstrap, que usa o socket explícito e tem checks de sessão e VM próprios. `ssh-session` e `ssh-agent` exercitam desbloqueio, inclusão e reuso. Não é uma garantia contra agentes iniciados manualmente fora da configuração declarada. |
| Outros contratos de sessão | `shell-providers` usa a configuração real de mise e prova trust/allow explícitos e recusa de instalar runtime ausente. Herdr e Fish têm checks direcionados; o check de árvore protege a exclusão no lab e Ordis tem asserção sem Home Manager. Shell de login e detalhes de layout não receberam guardas novas. |

**Validação local de `b93fcb9f0bebf21a0d3dde0ecabf90445b62a217`.** Com `src="git+file://$PWD?rev=b93fcb9f0bebf21a0d3dde0ecabf90445b62a217"`, `nix build --offline --no-link "$src#nixosConfigurations."{desktop,lab,ordis}.config.system.build.toplevel` e `nix flake check --offline --show-trace --no-write-lock-file -L "$src"` saíram 0. A projeção anterior e a adicional de GC, agente, SSH, firewall e Pi-hole coincidiram com `32ce0d6`. Os três toplevels, as sete derivações de VM e nove checks regulares são idênticos; só mudou a derivação de formatação. Não houve nova execução KVM: nenhum contrato de runtime da VM ou sua derivação mudou. Os registros KVM acima continuam sendo do SHA original.

**Sondas negativas descartáveis:** `nix eval --offline --raw "$src#nixosConfigurations.<host>" --apply 'h: (h.extendModules { modules = [ ({ lib, ... }: { <mutação>; }) ]; }).config.system.build.toplevel.drvPath'`. As 25 avaliações deram exit 1 com a mensagem da asserção correspondente: DHCP; NTP IPv4, IPv6 e sync; credencial alternativa; configuração gravável; ambient/bounding ampliados isoladamente; bind externo; firewall DNS global; regras SSH global/LAN/interface confiável; senha e caminho de chaves alternativo; GC automático em cada host e timer manual; agente desligado, GCR ativo e timeout; Pi-hole ativado em desktop/lab e UI desligada em Ordis. Para timeout, a sonda válida usa `"60"` (string); o inteiro do check antigo falhava por tipo, não provava a guarda.

**CI externa:** o [Codeberg confirmou em 18/11/2026, 08:17 UTC](https://social.anoxinon.de/@Codeberg/117636454915265360) que `codeberg.org` estava indisponível e em `clientHold`. Às 11:15 UTC, a consulta A via Google Public DNS ainda retornava NXDOMAIN; o RDAP consultado no mesmo período já não listava `clientHold`, o que não demonstra recuperação DNS. No [run 44288709255](https://github.com/Rinyaresu/dots/actions/runs/44288709255), merge ref `85eb0435491042bc4d27c8659e124fcfdb025e36`, `prepare` e Ordis passaram; `check`, desktop e lab falharam ao resolver o domínio. Caminho nos logs: Herdr 0.9.5 → `herdr-libghostty-vt-zig-cache.drv` → `translate_c.drv` → `4rqvd4wgs52z3p9rz1dpzb6lz9yqzw9i-source.drv` → [tarball de translate-c no Codeberg](https://codeberg.org/vancluever/translate-c/archive/4e879eb8aba615de112eabd1231ea6e01920cead.tar.gz). A limpeza existente elevou o espaço livre de 13 para 34 GiB em `check`; nesse run a falha foi DNS, não disco. Sem contorno e sem reruns manuais. O gate remoto exige um run bem-sucedido na merge ref do head publicado.

Nenhum sistema foi ativado nem operado remotamente. A [intermitência Pi-hole](https://github.com/Rinyaresu/dots/pull/3#issuecomment-6967660331) continua aberta; aprovação de runtime não é inferida deste gate.
