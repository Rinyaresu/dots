# Segunda rodada de revisão

A [comparação de gerações](comparacao-geracoes.md) mostra que aplicar a candidata não altera só os serviços Pi-hole: há novas configurações de logrotate/tmpfiles, triggers de D-Bus/polkit diferentes e artefatos de conta/SSH que exigem reconciliação. A comparação e o [runbook atualizado](ativacao-rollback.md) são gates de pré-ativação; nenhum passo do runbook foi executado no servidor.

## Controle negativo: preservação lógica

Na VM, a conexão ao `gravity.db` consultou `PRAGMA journal_mode` **antes e depois** da recusa: `delete` em ambas as capturas. Isso é observado naquele banco guest, não presumido para outros builds, bancos ou o Ordis. Em `delete`, o arquivo principal é o estado durável de uma transação já encerrada quando não há journal quente; o checksum antigo não verificava integridade, leitura lógica, presença da entrada de teste ou artefatos auxiliares. Em WAL, uma alteração confirmada pode estar só no `-wal` e deixar os bytes do arquivo principal iguais.

O teste agora abre leitura `mode=ro`, `query_only`, transação de leitura (sem `immutable=1`, que excluiria a visão correta do WAL em uso). Compara hash do dump lógico ordenado, versões do schema/usuário, `application_id`, journal mode e exige `integrity_check=ok` e a presença da entrada persistente de teste. Inclui o estado lógico de outros `gravity*.db` e o inventário/digest de arquivos retidos de backups rotacionados, temporários de gravity e cache/arquivo de listas. Não pretende demonstrar igualdade byte a byte de `-wal`/`-shm`, logs, sessão ou toda a árvore do FTL; o que é confirmado no WAL aparece na leitura lógica. São instantâneos antes/depois, não prova de ausência de qualquer escrita transitória.

A fixture WAL cria uma mutação confirmada sem checkpoint e exige que o checksum do arquivo principal **não mude** mas o digest lógico mude. O subteste do Pi-hole usa outra fixture: a forma inválida é injetada somente no setup do guest, o serviço precisa retornar `exit-code` com a mensagem de recusa e a nova comparação deve permanecer igual. Nenhuma alteração na configuração de produção ou alegação de reprodução espontânea de #4.

### Execuções manuais KVM

Nos SHAs abaixo, a partir da fonte Git limpa, com Nix 2.35.6 x86_64, `builders =` e `/dev/kvm`, usou-se `nix build --no-link -L .#packages.x86_64-linux.<variante>` (com `--option substitute false` nas primeiras realizações das variantes de laboratório). Tempos são os do script de teste; reboots abaixo são apenas do guest servidor.

| SHA | Variante | Resultado e derivação |
| --- | --- | --- |
| `600dc053cf04034d8e5e8909db4bc4746392e966` | `pihole` | Exit 0, 61,38 s, 1 reboot, `5hlkqyxmpjxr1q0fyl8fsx6xry8hvf7n-vm-test-run-pihole-network.drv` |
| `600dc053cf04034d8e5e8909db4bc4746392e966` | `pihole-control` | Exit 0, 119,90 s, 4 reboots, `72cfqa64cy00ifahiggfij9hshx5i897-vm-test-run-pihole-network.drv` |
| `d2a17a6cd706e822c8b3fe9fd40f79aeb4b01d05` | `pihole` | Exit 0, 56,50 s, 1 reboot, `anjq2wbdclhqlyabcgzl7vrv14dy38qk-vm-test-run-pihole-network.drv` |
| `d2a17a6cd706e822c8b3fe9fd40f79aeb4b01d05` | `pihole-control` | Exit 0, 107,01 s, 4 reboots, `1gqfqf9x354rr583q3bvbsf2x4mcwwd4-vm-test-run-pihole-network.drv` |
| `d2a17a6cd706e822c8b3fe9fd40f79aeb4b01d05` | `pihole-observe` | Exit 0, 112,08 s, 4 reboots, `7j77c5jga0in2g415ybjdn02n6m74l4p-vm-test-run-pihole-network.drv` |

Recorte do controle final (cinco linhas de boot KVM para `server`; marcadores de guest, sem dumps de banco):

```text
GRAVITY WAL fixture: logical change detected with main file unchanged
GRAVITY before: journal=delete marker=present integrity=ok
Invalid list API response; refusing to mutate gravity
GRAVITY after: journal=delete marker=present integrity=ok logical-and-auxiliary=unchanged
test script finished in 107.01s
```

A derivação de produção continuou `hyq4ikh6faa9bafmbxcxz0p4bvvb764b-nixos-system-ordis-26.05.20261108.ac588ef.drv`.

## CI do commit publicado na rodada anterior

[Workflow Checks, run 44631926480](https://github.com/Rinyaresu/dots/actions/runs/44631926480), head `5d16ea2fa04ddff991bbdb0b0c125e85997940a1`. `prepare` e `Build ordis` concluídos com sucesso; `check`, `Build desktop` e `Build lab` ainda em andamento na consulta. Não há falha observada nem resultado final nessa consulta. Workflow verifica/avalia o checkout do evento e constrói os sistemas; as VMs são `packages` e não correspondem às execuções manuais acima. O CI do novo head é uma execução separada.
