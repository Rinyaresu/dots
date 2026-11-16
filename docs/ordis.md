# Manter o perfil servidor

`nixosConfigurations.ordis` seleciona servidor, OpenSSH, Tailscale e Pi-hole.
Não seleciona Home Manager, usuário pessoal do desktop ou seus aplicativos.
Hardware, mounts, swap, console e systemd-boot pertencem à raiz do servidor.
Não aplique o layout de instalação do desktop nesse host.

As fontes contêm identificadores específicos de hardware e políticas de acesso.
Eles são necessários para construir o sistema existente, mas não comprovam o
estado instalado. O inventário e os procedimentos operacionais pessoais ficam
em documentação privada separada. A árvore local pode conter serviços ainda não
ativados no servidor. Nenhuma edição ou build autoriza deploy.

## Verificar uma revisão

Use `./scripts/check` e construa o toplevel Ordis a partir da exportação explícita,
conforme [AGENTS.md](../AGENTS.md). Mudanças compartilhadas também exigem os builds
de desktop e lab. Compare opções efetivas de SSH, firewall, rede, armazenamento e
boot com a revisão funcional antes de preparar qualquer aplicação.

O check Tailscale importa a raiz do servidor em uma VM. Credenciais e caminhos de
rede nessa VM são descartáveis. A prova não autentica o dispositivo real nem
acessa o servidor instalado. Veja [limites Tailscale](tailscale.md) e
[contratos Pi-hole](pihole.md).

## Aplicar somente com autorização própria

Preserve a geração funcional, fonte completa, estado persistente e acesso físico.
Confira uma conexão SSH nova e sudo antes de qualquer ativação.
Prepare rollback independente antes de mudar rede ou firewall.
Não sobreponha arquivos novos à árvore antiga. Import-tree também carregaria
módulos obsoletos deixados nela.

Uma aplicação temporária e sua validação devem preceder a persistência da revisão.
Confira conexão nova, sudo, DNS, serviços, mounts e boot. Reinício exige autorização
separada e recuperação preparada. Não confunda build com ativação ou inspeção
com permissão administrativa.

## Recuperação

Uma geração Nix não restaura bancos e arquivos pessoais. Preserve cópias consistentes
do estado antes de upgrades que possam migrar formatos.
Não presuma que uma geração antiga mantém a política atual de acesso.
Confira suas opções antes de usá-la para recuperação.

Se o boot falhar, use console, entrada funcional do bootloader ou mídia de
recuperação autorizada. Não reinstale, formate ou apague estado para contornar
uma falha de configuração. Não remova gerações ou execute garbage collection
até concluir a recuperação e sua validação.
