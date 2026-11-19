# Ordis — roteiro para uma janela futura autorizada

**Não executar enquanto a decisão sobre a issue #4 estiver pendente.** A ponta avaliada para produção é `a6634e8bc21ebac757f7bf5576f8c12f45361f7f`, não o commit de laboratório. O roteiro exige autorização separada para transferência, build no Ordis, provisionamento, backup e teste/ativação; reboot físico não faz parte dele. Se a causa não for identificada, a alternativa é uma decisão explícita de aceitar o risco para um piloto isolado, não uma declaração de correção.

## 1. Gate operacional e fonte

- Separe console com login/sudo conferidos, mídia, operador e armazenamento protegido com cópia independente. Não dependa de DNS ou SSH fornecido pelo candidato para recuperar o servidor. Confirme que nenhum cliente depende do Pi-hole antes da janela; não altere o Nokia, DHCP, RA nem o DNS padrão de nenhum cliente.
- Revalide a rota e a chave ED25519 via known_hosts/canal confiável. O acesso observado usou a exceção LAN declarada; confira origem e destino na política do host e por canal privado. Se mudou, pare e reveja o candidato, não flexibilize a regra ao vivo. Mantenha a sessão original, defina `ORDIS_LOGIN` e `ORDIS_LAN_IPV4` pelos valores conferidos privadamente e abra uma nova:

```sh
ssh -t -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no \
  -o ControlPath=none -o ForwardAgent=no -o HostKeyAlgorithms=ssh-ed25519 \
  "$ORDIS_LOGIN@$ORDIS_LAN_IPV4" 'hostname; id -un; sudo -v && sudo -l'
```

- Com privilégio autorizado, inspecione localmente `iptables-save`, `ip6tables-save` e `nft list ruleset` (último se instalado), incluindo regras do Tailscale, loopback e exceções. Confira `ip -br addr`, `ip route`, `ss -lntup`, `findmnt -T /boot`, `df -h / /nix /boot`, `bootctl list`, existência da entrada funcional e espaço para novo kernel/initrd. Não publique o ruleset, journal bruto ou dados da tailnet. Verifique SSH e Tailscale (`sshd`, `tailscaled`, `tailscale0` e, se disponível, conexão nova a partir de um cliente permitido pela política real; não modifique grants). Registre DNS do host (`/etc/resolv.conf`, `getent ahostsv4 example.com`), compare dispositivos/UUIDs de mounts com a fonte e confirme acesso a upstreams `1.1.1.1`/`1.0.0.1` e resolução de `github.com`/`raw.githubusercontent.com` pelo próprio host (preflight do gravity mesmo com `file://`). Se portas 53/8080 estiverem ocupadas ou se o firewall não puder ser validado, pare.
- Obtenha por canal autorizado um **novo** checkout Git limpo, completo, com o commit e lock testados, e Git utilizável por root. `/etc/nixos/flake` observado é export sem `.git`, não faça overlay nem inicialize Git ali. Se não houver Git/PATH, disponibilize-o por meio autorizado antes de prosseguir. Preserve a fonte funcional existente inteira, mesmo sem SHA comprovável. No shell root do console, configure `SRC` e `B` para o checkout novo e uma pasta nova em armazenamento privado protegido (não no store, não no checkout). Todos os blocos administrativos abaixo são para essa janela, com `umask 077`, sem tracing; pare em qualquer erro.

```sh
umask 077
SRC=/etc/nixos/ordis-candidato                  # caminho do novo checkout
B=/CAMINHO_PRIVADO_PROTEGIDO/ordis-pre-pihole     # ainda não existente
REV=a6634e8bc21ebac757f7bf5576f8c12f45361f7f
EXPECTED=/nix/store/lagakcxscvbmyk1dya7fh47n61vzw10r-nixos-system-ordis-26.05.20261108.ac588ef
cd "$SRC" || exit 1
test "$(git rev-parse HEAD)" = "$REV" && test -z "$(git status --porcelain)" || exit 1
OLD=$(readlink -f /run/current-system)
OLD_PROFILE=$(readlink /nix/var/nix/profiles/system)
test "$OLD" = "$(readlink -f /run/booted-system)" &&
  test "$OLD" = "$(readlink -f /nix/var/nix/profiles/system)" &&
  test -x "$OLD/bin/switch-to-configuration" || exit 1
mkdir -m 700 -- "$B" || exit 1
printf '%s\n%s\n' "$OLD" "$OLD_PROFILE" > "$B/geracao-anterior"
printf '%s\n' "$REV" > "$B/candidato"
tar --acls --xattrs -cpf "$B/fonte-anterior.tar" -C /etc/nixos flake || exit 1
nix build --no-write-lock-file --out-link "$B/toplevel-candidato" \
  '.#nixosConfigurations.ordis.config.system.build.toplevel' || exit 1
NEW=$(readlink -f "$B/toplevel-candidato")
test "$NEW" = "$EXPECTED" || exit 1
```

Mantenha os links das gerações e do build e não rode GC. Revalide a geração de retorno em vez de usar o número da inspeção anterior. Se `/run/current-system`, `/run/booted-system` e o perfil divergirem, pare e reconcilie antes de seguir. Confirme que `bootctl list` mostra a entrada de retorno e que o console pode selecioná-la.

## 2. Estado consistente e credencial fora do store

Na primeira ativação esperava-se ausência dos três diretórios abaixo. Se houver estado inesperado, não o sobrescreva. Identifique todos os escritores (incluindo operações manuais de gravity) e pare os serviços existentes com autorização, primeiro o setup, depois FTL, e confirme que não estão rodando. Templates de estado SQLite ativo não são backup. Verifique também outros mounts/serviços persistentes que o diff da geração possa afetar; se houver migração fora do escopo, trate-a antes da janela.

```bash
for u in pihole-ftl-setup.service pihole-ftl.service; do
  if [ "$(systemctl show "$u" -p LoadState --value)" = loaded ]; then
    systemctl stop "$u" || exit 1
  fi
  if systemctl is-active --quiet "$u"; then exit 1; fi
done
paths=()
for p in etc/pihole var/lib/pihole var/lib/pihole-secrets; do
  if [ -e "/$p" ] || [ -L "/$p" ]; then
    paths+=("$p"); printf 'presente %s\n' "$p"
  else printf 'ausente %s\n' "$p"; fi
done > "$B/pihole-manifesto"
if ((${#paths[@]})); then
  tar --acls --xattrs --numeric-owner -cpf "$B/pihole-estado.tar" -C / "${paths[@]}" || exit 1
  tar --acls --xattrs --numeric-owner -df "$B/pihole-estado.tar" -C / >/dev/null || exit 1
fi
```

Confira recuperação do arquivo privado, da senha (cofre independente), da fonte e geração. Não copie `/run`, credenciais Tailscale ou chaves SSH para artefatos. Não sobrescreva hash válido existente sem aprovação para rotação; para primeiro provisionamento use o binário **da closure candidata**, ainda sem ativar:

```sh
"$NEW/sw/bin/pihole-admin-hash" || exit 1      # console TTY, senha digitada duas vezes
p=/var/lib/pihole-secrets
test ! -L "$p" && test "$(stat -c '%a %u:%g' "$p")" = '700 0:0' &&
  test -f "$p/admin-hash" && test ! -L "$p/admin-hash" && test -s "$p/admin-hash" &&
  test "$(stat -c '%a %u:%g' "$p/admin-hash")" = '600 0:0' || exit 1
```

Não imprima o hash, não passe senha por argv/env do shell, não use histórico/tracing para a senha.

## 3. Aplicação temporária, antes de persistir

`test` aplica a configuração no sistema real, pode alterar serviços e dados e **não** tem rollback automático. Não execute para revisão documental. Este roteiro cobre a primeira ativação (geração anterior sem Pi-hole). Se a geração anterior já tiver Pi-hole, pare e revise a ordem de rollback com ela desativada para evitar que o FTL antigo abra o banco novo.

```sh
nixos-rebuild test --flake "$SRC#ordis" --no-write-lock-file &&
  test "$(readlink -f /run/current-system)" = "$NEW" &&
  test "$(readlink -f /nix/var/nix/profiles/system)" = "$OLD" &&
  test "$(readlink -f /run/booted-system)" = "$OLD"
```

Em falha nesses comandos, **não apenas saia**: execute rollback abaixo. No console e por uma **nova** conexão SSH verificada, confirme `sudo` (como acima), redes, mounts, DNS próprio sem apontar ao Pi-hole e Tailscale preservado. Confira em separado:

```sh
systemctl show pihole-ftl -p LoadState -p ActiveState -p SubState -p MainPID -p Result
systemctl show pihole-ftl-setup -p LoadState -p ActiveState -p SubState \
  -p Result -p ExecMainCode -p ExecMainStatus -p ExecMainStartTimestamp -p ExecMainExitTimestamp -p InvocationID
ss -lntup
```

FTL deve estar `active/running` com PID válido. Para o setup oneshot, `inactive/dead` **pode** ser sucesso: exija execução concluída desta ativação, `Result=success`, exit 0 e journal privado sem recusa de listas/erro de bootstrap, gravity ou reload. Não force um segundo setup para mascarar falha do primeiro. Confira no ruleset efetivo a permissão DNS TCP/UDP só para IPv4 do prefixo LAN declarado entrando pela interface física declarada (mais tráfego local de loopback), sem abertura na tailnet nem IPv6. Em `ss`, confirme painel só `127.0.0.1:8080`, sem serviço Pi-hole de DHCP/NTP. `LISTEN` em DNS não comprova exposição: compare regras e testes de transporte.

De **um** cliente LAN autorizado, sem mudar o resolvedor padrão nem configurar DHCP/DNS no Nokia, teste `A` explicitamente contra o IP conferido. O snapshot declarado contém `doubleclick.net`; compare `example.com` com uma resposta real não nula. Use `dig` com status e resposta, não só o exit code:

```sh
LAN=${ORDIS_LAN_IPV4:?Defina o endereço IPv4 conferido}
for transport in +notcp +tcp; do
  dig @"$LAN" example.com A "$transport" +time=2 +tries=1 +noall +comments +answer
  dig @"$LAN" doubleclick.net A "$transport" +time=2 +tries=1 +noall +comments +answer
done
curl --noproxy '*' --connect-timeout 2 --max-time 4 -sS -o /dev/null \
  -w '%{http_code}\n' "http://$LAN:8080/"
```

Esperado: `NOERROR` com A real para permitido e `NOERROR` + `0.0.0.0` para bloqueado em UDP e TCP; painel direto deve falhar no transporte, não basta retornar 401/403. Do mesmo cliente onde houver IPv6, confirme rota e use `dig -6 @IPV6_ORDIS ...` via UDP e TCP; nenhuma resposta DNS. Se houver ponto de observação autorizado em interface não LAN, confirme recusa também por ele. Não improvise abertura de acesso se não houver ponto de teste. Um AAAA consultado via IPv4 não prova isolamento IPv6.

```sh
ssh -N -o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no \
  -o ControlPath=none -o ForwardAgent=no -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:8080:127.0.0.1:8080 "$ORDIS_LOGIN@$LAN"
# Em outro terminal no cliente:
curl --noproxy '*' -sS -o /dev/null -w '%{http_code}\n' \
  http://127.0.0.1:8080/api/stats/summary
```

Espere 401 sem sessão; no navegador, faça login em `http://127.0.0.1:8080/admin/` com a senha do cofre. Não capture sessão/corpo/cabeçalhos. Pare e reverta se SSH novo, sudo, Tailscale, mounts, DNS próprio, setup, DNS do cliente, isolamento ou login falhar. Só após todos os gates e autorização de persistência, use o **mesmo** SHA/closure e repita as verificações de runtime e boot:

```sh
nixos-rebuild switch --flake "$SRC#ordis" --no-write-lock-file &&
  test "$(readlink -f /run/current-system)" = "$NEW" &&
  test "$(readlink -f /nix/var/nix/profiles/system)" = "$NEW" &&
  bootctl list
```

Não reinicie o Ordis nesta janela. `switch` não comprova boot real. Não altere Nokia/DHCP mesmo após sucesso.

## 4. Rollback de sistema e recuperação de dados são ações separadas

Se a conexão nova falhar, use a sessão antiga apenas se ainda for confiável e privilegiada, ou vá direto ao console. Não dependa de criar SSH sobre a rede alterada. Use `$B/geracao-anterior` (linha 1 = store antigo; linha 2 = `system-N-link`) para preencher `OLD` e `OLD_PROFILE` após perder o shell.

```sh
# No console/shell root da janela; conferir os valores antes de executar.
case "$OLD_PROFILE" in system-[0-9]*-link) ;; *) exit 1 ;; esac
OLD_NUM=${OLD_PROFILE#system-}; OLD_NUM=${OLD_NUM%-link}
test "$(readlink -f /nix/var/nix/profiles/"$OLD_PROFILE")" = "$OLD" || exit 1
# Se só fez test (perfil ainda aponta ao anterior):
"$OLD/bin/switch-to-configuration" test
# Se fez switch, use a geração exata, não um --rollback ambíguo:
nix-env --profile /nix/var/nix/profiles/system --switch-generation "$OLD_NUM" &&
  "$OLD/bin/switch-to-configuration" switch
```

Use **só o ramo aplicável**. Verifique geração, regra SSH, nova sessão e sudo, montagens, resolvedor, Tailscale e (depois de switch) entrada/default no systemd-boot. Se nem console do sistema permitir recuperação, com autorização separada para reboot selecione a entrada conhecida no systemd-boot pelo console, ou mídia de recuperação se indisponível; corrija perfil/default com o sistema funcional iniciado. Não limpe as gerações/discos.

Rollback Nix não restaura bancos, listas ou hash. Confira que setup e FTL estão parados (nessa ordem) e que não há escritores antes de mover ou restaurar os dados. Se a regra de escopo acima não se aplicar, não execute o rollback genérico de sistema: primeiro obtenha um procedimento revisado que mantenha setup e FTL parados até restaurar dados compatíveis. Conserve o estado pós-falha separadamente; prepare quarentena no mesmo filesystem de cada caminho ou faça uma cópia consistente verificada antes de qualquer movimento entre filesystems; não sobrescreva nenhum lado. Para restaurar a cópia consistente da revisão anterior, com ambos os serviços parados e sem escritores, em shell root:

```sh
umask 077
Q="$B/estado-pos-falha"
mkdir -m 700 -- "$Q" || exit 1
for p in etc/pihole var/lib/pihole var/lib/pihole-secrets; do
  if [ -e "/$p" ] || [ -L "/$p" ]; then
    mkdir -p -- "$Q/${p%/*}" && mv --no-copy -- "/$p" "$Q/$p" || exit 1
  fi
done
if [ -f "$B/pihole-estado.tar" ]; then
  tar --acls --xattrs --numeric-owner -xpf "$B/pihole-estado.tar" -C / || exit 1
fi
```

Confira o manifesto, tipo/dono/modo, cópia compatível, bancos completos e list config. Se a instalação anterior não tinha Pi-hole, os caminhos originalmente ausentes ficam ausentes; não inicie serviço. Se já tinha, recupere com revisão e credencial compatíveis e só inicie com autorização; repita DNS e autenticação. Guarde as evidências em privado e não descarte os dois estados até concluir a recuperação.
