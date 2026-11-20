# Pi-hole no Ordis — dossiê temporário de revisão

**Estado:** diagnóstico incompleto; sem correção de produção neste PR e sem autorização de ativação. A configuração base já está em `master`. Os testes acontecem em guests descartáveis. As observações do servidor vieram de leituras SSH, não de um piloto. Este documento e os recortes ficam até a revisão aprovar uma limpeza separada.

**Decisão pré-piloto:** [reconciliação de acessos, CI final e verificações pendentes](decisao-piloto.md).

**Rodada 2:** [comparação das gerações](comparacao-geracoes.md) e [controle lógico do SQLite, KVM e CI](rodada-2.md). Os resultados abaixo permanecem como evidência da investigação original.

## A. O que sabemos sobre a issue #4

- [Issue #4](https://github.com/Rinyaresu/dots/issues/4) e [execução histórica](https://github.com/Rinyaresu/dots/actions/runs/44223679561/job/134531510364): revisão `c0e23752de08288188d508f382e9b9123125049a`, job `check`, derivação `1y93jfvf2pscy657k7h101ckyxl74ajh-vm-test-run-pihole-network.drv`. No boot em questão o FTL iniciou a ~14,31 s, o setup a ~21,18 s e recusou a resposta a 21,773834 s: `Invalid list API response; refusing to mutate gravity`. Localmente, na mesma derivação, três execuções históricas deram `0,1,0`, com a mesma recusa no segundo ensaio (a ~16,60 s, após início do FTL a ~8,90 s). São observações históricas, não três novos ensaios. Quatro execuções históricas instrumentadas passaram com HTTP 200 e `.lists` array; não explicam a falha.
- **Ponto de recusa**, não causa: o [setup](../../modules/server/networking/pihole/default.nix) depende do FTL; `active` não prova prontidão da API. O preflight nativo descobre a API via CHAOS TXT e consulta `/auth` (aceita 200 ou 401). Depois o setup autentica e consulta `lists?type=block`. Em Pi-hole 6.4.2, `GetFTLData` entrega o corpo em 200 e só o status nos demais casos. O setup só prossegue na deduplicação se `jq -e` aceitar um objeto com `.lists` array. A mensagem sozinha não distingue transporte, sessão recusada, HTTP incompatível, JSON inválido ou JSON válido com forma incompatível. Um SIGKILL intencional anterior não demonstra causalidade no boot seguinte.
- **O que foi descartado:** falha determinística em todo reboot da mesma derivação e ausência total de funcionamento da API. Retorno 401 de `/auth` no preflight não equivale a rejeição da sessão autenticada. A falta de credencial e o hash malformado produzem uma recusa anterior diferente nos casos exercitados. Isso não exclui falha intermitente de sessão, janela de prontidão da API/DB, erro HTTP ou forma inesperada; nenhuma foi observada na resposta espontaneamente rejeitada.
- **Controle negativo:** injetar `{"lists":{}}` em guest com DB existente fez o setup retornar falha e preservou o SHA-256 do arquivo `gravity.db` (comparado dentro do guest, não publicado). Isso demonstra a barreira antes do `pihole -g` nesse cenário, não a causa histórica, nem garante zero escrita anterior em primeiro boot: o bootstrap de DB ausente e a preparação de MAC vendor antecedem essa consulta.
- **Próximo diagnóstico, não executado:** definir novo orçamento; manter controle sem probe; classificar só a resposta rejeitada do curl existente, com status/rc/forma e contexto monotônico do FTL. Se capturar o mecanismo espontâneo, reproduzi-lo em teste determinístico antes/depois. Sem isso **não fechar #4 nem chamar o harness de correção**. Só considerar piloto físico com aceitação explícita do risco residual e gates do runbook.

## B. Código e resultados

**Código base avaliado:** [`a6634e8`](https://github.com/Rinyaresu/dots/commit/a6634e8bc21ebac757f7bf5576f8c12f45361f7f). Histórico: [implementação](https://github.com/Rinyaresu/dots/commit/649a7403e6a0e73daf94542a93d8593b57d09a30), [teste de credenciais inválidas](https://github.com/Rinyaresu/dots/commit/7cb52a7821d9f0b7749816affdfa7c214ec58988), [espera pelas respostas DNS exatas após recuperação](https://github.com/Rinyaresu/dots/commit/676c83de42a2067a2dcc9df80db35e8eb29dda0b), [gate de credencial](https://github.com/Rinyaresu/dots/commit/e852e809ead3d31a1542e9f655a51619c272d1f1), [módulo server/networking](https://github.com/Rinyaresu/dots/commit/0f6991d6c513aceea4b2d953f165fd9e8c6e2992) e [invariantes na avaliação](https://github.com/Rinyaresu/dots/commit/b93fcb9f0bebf21a0d3dde0ecabf90445b62a217). O [módulo](../../modules/server/networking/pihole/default.nix) declara FTL, registro idempotente de listas, atualização de gravity e sinalização com PID validado. O [consumidor Ordis](../../modules/hosts/ordis/pihole.nix) seleciona a interface, restringe o firewall e fixa uma lista por commit e hash, em `file://`. O snapshot elimina fetch de listas no boot, não a resolução exigida pelo preflight do gravity.

**Diff deste PR:** [`df3ce98`](https://github.com/Rinyaresu/dots/commit/df3ce981b8f476c585e179ca11f871365631435b) introduziu os experimentos para separar efeito do probe e testar a recusa. [`a5c99f4`](https://github.com/Rinyaresu/dots/commit/a5c99f41ab6eef9c204328903e1259f182bb0888) corrigiu o harness: a tentativa inicial bateu `EROFS` ao criar drop-in em `/etc/systemd/system`; excluída da matriz. O [instalador do guest](../../checks/pihole-test-setup.py) usa override persistente apenas no guest de observação, e override transitório para a injeção negativa depois dos reboots. O [probe](../../checks/pihole-observe.py) classifica respostas das chamadas existentes, sem GET extra nem corpo, URL, senha, hash, SID, token ou cabeçalho no marcador. Ele envolve atribuições e acrescenta trabalho no caminho quente; não se presume equivalência de timing ou dos caminhos de erro. `control` não usa esse classificador durante os reboots. A injeção é deliberada e só no último subteste de controle.

### Reproduzir localmente, sem Ordis

Use Nix com flakes, x86_64 e acesso a `/dev/kvm`, sem builders remotos. Execute em checkouts independentes e limpos. Evidência original: CachyOS, Nix 2.35.6. Histórico e comandos não implicam que os resultados sejam determinísticos.

```sh
export NIX_CONFIG='experimental-features = nix-command flakes
builders ='
# No checkout limpo de a6634e8:
nix flake check --show-trace --no-write-lock-file
nix build --no-link --no-write-lock-file .#nixosConfigurations.ordis.config.system.build.toplevel
nix build --no-link --rebuild -L .#packages.x86_64-linux.pihole
# No checkout limpo de a5c99f4, 3 pares alternados (cada execução faz 4 reboots):
for variant in observe control control observe observe control; do
  nix build --no-link --rebuild -L ".#packages.x86_64-linux.pihole-$variant" || break
done
```

Se a derivação experimental ainda não estiver realizada, faça a primeira rodada de cada variante com `--option substitute false` em vez de `--rebuild`, usando dependências já disponíveis. Registre exit status antes de interpretar o journal e pare na rejeição classificada ou bloqueio do ambiente. Não publique logs brutos. `nix path-info --derivation .#packages.x86_64-linux.pihole-observe` (ou `nix eval --raw ...drvPath`) ajuda a identificar o artefato.

| Gate/revisão | Resultado observado |
| --- | --- |
| Flake, `a6634e8` | Exit 0; `running 0 flake checks`. As VMs são `packages`, não checks executados por esse comando. |
| Build Ordis, `a6634e8` | Exit 0; `.drv` `hyq4ikh6faa9bafmbxcxz0p4bvvb764b-nixos-system-ordis-26.05.20261108.ac588ef.drv`, saída `lagakcxscvbmyk1dya7fh47n61vzw10r-nixos-system-ordis-26.05.20261108.ac588ef`. O toplevel também foi avaliado igual no commit do harness. |
| Gate original KVM, `a6634e8` | Exit 0 em 56,83 s; mesma derivação histórica, boot inicial e 1 reboot do servidor guest. |
| B1/B2/B3, `a5c99f4`, controle | Exit `0/0/0`, `114,60/112,63/116,48 s`; `m02mgrnfw80cb3q9lxicfb1pwj3nkv5g-vm-test-run-pihole-network.drv`. |
| B1/B2/B3, `a5c99f4`, observação | Exit `0/0/0`, `131,24/141,95/115,11 s`; `7pdnm471ym14cv5srkfbi3mj3bbfjvrz-vm-test-run-pihole-network.drv`. |

[Recortes KVM](kvm-recortes.txt) mostram cada rodada com 5 boots do servidor (inicial + 4 reboots; 24 reboots comparáveis no total), subtestes, recusa injetada e 21 consultas de listas observadas. Todas as 21: curl 0, HTTP 200, objeto/`lists=array`, `error=null`, sessão aceita. Na inicialização de B2 houve duas falhas de descoberta, recuperadas pelo preflight nativo antes da consulta autenticada. **Zero rejeições espontâneas dentro do orçamento, não prova de correção.**

### Matriz de segurança: o que foi comprovado e onde

| Requisito | Evidência | Limite |
| --- | --- | --- |
| DNS TCP/UDP só LAN IPv4 | [Regra Ordis](../../modules/hosts/ordis/pihole.nix) limita origem/interface; [VM](../../checks/pihole.nix) reaproveita regras adaptadas para a interface virtual; compara respostas permitidas e bloqueadas, recusa interface não confiável e transporte IPv6. | AAAA por IPv4 não é teste de transporte IPv6; a VM testa ambos separadamente. Falta validar firewall efetivo e rede física. |
| Administração privada | Bind `127.0.0.1:8080`; VM verifica bind, HTTP 401 sem credencial/com senha inválida e acesso com sessão válida. | O cliente do teste usa `curl --fail`, o que sozinho não distingue erro HTTP de bloqueio; `ss` complementa. No piloto exigir recusa de transporte externo e login pelo túnel. |
| Credencial fora do store e falha fechada | [Provisionador](../../modules/server/networking/pihole/admin-hash.py) + `LoadCredential`, validação antes do FTL, token em runtime tmpfs, [patch](../../modules/server/networking/pihole/api-no-argv-secrets.patch) e [teste argv](../../checks/pihole-argv.py). VM checa modos, hash ausente da TOML e falta/forma inválida antes da criação de gravity. | Não é auditoria de todo acesso privilegiado ao processo. Credencial real ainda não provisionada nem inspecionada. |
| DHCP/NTP/serviços extras | Asserção desliga DHCP, NTP IPv4/IPv6 e sync; VM verifica ausência de listeners UDP 67/123. | Não foi alterada nem testada a infraestrutura Nokia. |
| Persistência e recuperação | VM comprova estado e entrada customizada após restart/reboot e resolução após SIGKILL do FTL. | Sem reboot físico; não prova boot ou serviço no Ordis. |
| SSH, Tailscale e firewall | Comparação somente leitura do script gerado e da candidata preserva regras SSH de LAN e tailnet; nenhum diff de produção no PR. | VM não valida sessão SSH real ou Tailscale; tabela efetiva indisponível sem privilégio. |

## C. Ordis físico: leitura e preparação

Na inspeção, `/run/current-system`, `/run/booted-system` e perfil de sistema apontavam para a mesma geração 7 (`26.05.20261108.ac588ef`), **distinta** da build candidata. `bootctl status` indicava entrada dessa geração. SSH LAN novo funcionou; `sshd`, `tailscaled` e o gerenciador de rede estavam ativos; o oneshot de firewall concluiu, sem unidades falhas listadas. FTL e setup não estavam instalados/carregados; não se observaram os caminhos de estado/credencial esperados nem listeners 53, 8080, 67 ou 123. Interface física tinha IPv4 e IPv6; resolvedor do próprio host era externo, com resolução funcional. Raiz e store em Btrfs, ESP em vfat; havia espaço indicado em store e ESP, a revalidar. Não são publicados endereços observados, identidades de clientes, regras efetivas, aliases ou chaves da tailnet.

O export `/etc/nixos/flake` não tinha `.git` nem os arquivos Pi-hole; `flake.lock` comparado **coincidia** (`ac56a72d5bbe74ff73bdd9cb8a722fa53b63d2b4d6d9ab9e4ec15d4b836d2421`), mas a composição do flake/host diferia. Não deduzir SHA instalado desse lock. A inspeção das regras efetivas foi negada sem privilégio; sudo não interativo exigiu autenticação, e `git` não estava disponível no shell SSH observado. Acesso ao console, sudo interativo, nova conexão pela tailnet e verificação completa do boot/ESP não foram comprovados. Estes são relatos sanitizados de comandos como `readlink -f`, `systemctl`, `ss`, `ip`, `findmnt`, `df`, `bootctl status` e comparação por `sha256sum`, não gates de runtime da candidata.

**[Runbook proposto](ativacao-rollback.md):** revalidar geração funcional e acesso, usar fonte limpa fixada, guardar estado fora do store, preparar credencial em console privado, `nixos-rebuild test` temporário e consultas explícitas de **um único cliente** sem mudar o DNS padrão. Rollback de sistema e restauração de dados são distintos. `switch` é decisão posterior com nova autorização; reboot não faz parte do piloto. **Nada foi ativado, escrito ou reconfigurado no Ordis/Nokia.** Antes de qualquer execução: revisão do PR, decisão registrada para #4, janela e autorizações separadas para transferência/backup/provisionamento/teste; verificar alternativa de recuperação sem depender do candidato. Não há aprovação implícita por CI ou pela publicação.
