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

Nenhum sistema foi ativado nem operado remotamente. A [intermitência Pi-hole](https://github.com/Rinyaresu/dots/pull/3#issuecomment-6967660331) continua aberta; aprovação de runtime não é inferida deste gate.
