# Decisão pré-piloto — acesso, recuperação e CI

**Status: ainda não liberar o piloto.** A credencial SSH usada pela LAN é preservada no declarado; a conectividade após aplicação não foi testada. O operador confirmou acesso físico e informou que consegue recuperar a máquina. Isso é relato do operador, não um teste de login, privilégio ou boot executado nesta revisão.

## Reconciliação somente leitura

A geração ativa era a mesma da [comparação anterior](comparacao-geracoes.md). Compararam-se `users-groups.json` de ambas as closures, limitando a leitura aos campos de identidade (nome, UID, grupo, home, shell, criação de home e tipo de conta) e à configuração de grupos (nome, GID e membros). Na geração ativa, cruzaram-se nomes, IDs declarados e vínculos com `getent passwd`, `getent group` e `id`. Não se leram senhas, hashes de senha ou chaves privadas.

- **Contas e grupos:** 47→48 contas e 39→40 grupos declarados; a única adição é a identidade de serviço `pihole`, com UID/GID dinâmicos e sem associação administrativa nova. Nenhuma remoção nem mudança nos campos comparados das entradas existentes; `mutableUsers=true` em ambas. No inventário NSS obtido, não se encontraram contas ou grupos fora do declarado, divergências nos IDs explícitos nem vínculos declarados ausentes. UID, grupo primário, home, shell e associação a `wheel` do login operacional conferiram. `wheel` não demonstra sudo funcional.
- **Chaves:** foi aberta nova conexão por chave na LAN, sem reutilizar sessão, sem agent forwarding e com verificação estrita da chave de host. O servidor aceitou uma chave que coincide com a única entrada tanto no arquivo do home quanto em `/etc/ssh/authorized_keys.d` ativo, no artefato gerado ativo e no gerado candidato. A comparação foi por identidade da chave e opções, sem depender de comentários ou formatação; nenhuma das entradas tinha opções. O arquivo do home e o gerado candidato não eram iguais em bytes, mas **não houve divergência na autorização de chave**. O `sshd_config` comparado mantém ambas as fontes, login por chave e root/senha desabilitados.
- **Conclusão:** não foi identificada perda declarada da conta, dos grupos ou da chave SSH observada, nem concessão adicional de chave. O login pela LAN funciona **na geração ativa**. Isso não comprova login após aplicação, a política efetiva da tailnet, autenticação por senha no console, sudo ou recuperação.

## Verificações operacionais ainda pendentes

| Verificação | Quem e qual autorização | Evidência esperada |
| --- | --- | --- |
| Firewall efetivo | Operador privilegiado no Ordis, ou sessão autorizada para leitura por privilégio (`iptables-save`, `ip6tables-save`, `nft list ruleset` conforme o backend). | Confirmar ordem, políticas, SSH LAN, interação com Tailscale, loopback e ausência de abertura inesperada; publicar apenas conclusão, não o ruleset. |
| Sudo e recuperação sem rede | Operador autentica localmente, sem compartilhar senha. `sudo -l` no console é uma opção se o caminho de rollback for o login local; não é obrigatório se houver outro caminho administrativo independente da rede que esteja verificado. `sudo -l` por SSH, se autorizado, só confirma permissões pelo canal SSH. | Caminho administrativo utilizável sem depender do SSH, com privilégios suficientes para executar o rollback e acesso ao material necessário. Acesso físico reportado não substitui essa evidência. |
| Boot e recuperação | Operador com console e permissão para ler `bootctl status/list` e metadados da partição EFI; elevar privilégio só se necessário e autorizado. A verificação de acesso à mídia e ao backup é humana. | Entrada funcional presente, geração de retorno identificada e material de recuperação acessível independentemente da máquina/rede. Não selecionar entrada, restaurar nem reiniciar nesta etapa; não declarar boot de recuperação demonstrado. |
| SSH pela tailnet | Teste autorizado a partir de um cliente já permitido, com chave de host verificada; operador indica o cliente ou realiza o teste. Não requer sudo. | Nova conexão autenticada, sem alterar grants. A LAN não substitui essa evidência. |

Nenhuma dessas operações pendentes foi executada nesta revisão. Não se alteraram políticas de acesso.

## Risco residual e decisão

- **#4 permanece aberta, causa desconhecida.** A falha histórica é intermitente e apareceu após reboot em KVM; a matriz limitada não a reproduziu espontaneamente e não permite estimar frequência no Ordis. O controle SQLite demonstra apenas a recusa e preservação observada no caso injetado. O risco operacional é o FTL estar escutando mas o setup não concluir bootstrap/atualização de listas, deixando filtragem antiga ou incompleta. Responder a DNS não passa o gate se o setup falhar.
- **Limite do piloto:** um único cliente faz consultas explícitas ao IP do Ordis, sem trocar seu resolvedor padrão nem mexer em Nokia, DHCP, RA ou regras da tailnet. Isso limita a dependência intencional de DNS, mas não restringe a escuta a um cliente nem elimina efeitos da ativação sobre acesso e serviços do servidor. Não inclui persistência/reboot. Qualquer recusa da API, falha de setup, exposição indevida ou perda de acesso dispara rollback no [runbook](ativacao-rollback.md).
- **Decisão recomendada:** manter bloqueado até fechar as verificações operacionais e obter aceite explícito do risco de #4 e autorização separada para uma janela temporária. Não repetir o KVM sem nova justificativa técnica.

## CI concluído

| Head | GitHub Actions | Resultado |
| --- | --- | --- |
| `29edd58bb1ac0a2d393a079088e02bb8344ac7d4` | [44634141089](https://github.com/Rinyaresu/dots/actions/runs/44634141089) | `success`: `prepare`, `check`, builds desktop, lab e Ordis concluídos com sucesso. |
| `5d16ea2fa04ddff991bbdb0b0c125e85997940a1` | [44631926480](https://github.com/Rinyaresu/dots/actions/runs/44631926480) | `success` nos mesmos cinco jobs; substitui a observação anterior de execução em andamento. |

Nenhuma falha a investigar nesses dois runs. CI não substitui [KVM manual](rodada-2.md) nem confirma runtime no Ordis. O commit que publica esta evidência é só documentação e dispara CI separado.
