# Atualização do Pi-hole no Ordis

Este procedimento não autoriza operação. Separe a aprovação da atualização, a ativação das listas e a adoção residencial. Use também o [procedimento de DNS residencial](ordis-household-dns.md) e o [guia de recuperação](../secrets/README.md#provisionar-e-recuperar-pi-hole).

## Preparação e implantação

1. Por SSH novo para `192.168.1.196`, registre a revisão efetivamente instalada, gerações em execução e de boot, versões, estado de FTL/setup/timer, contagens e grupos da Gravity, `dnscrypt-proxy`, regras carregadas e DNS do próprio Ordis. Confirme console local e DNS independente na mídia de recuperação do desktop. No Nokia, registre DHCP e RA, reservas, configurações WAN/UPnP e acesso por IP. Guarde o registro em local privado; não publique fotos do painel nem exportações.
2. Com janela aprovada, impeça atualizações concorrentes da Gravity e faça backup cifrado e independente de `/var/lib/pihole`, estado necessário de `/etc/pihole`, hash externo, material TLS/ACME e geração/configuração anterior. Para uma cópia fria, pare FTL e setup antes de copiar. Para copiar banco ativo use SQLite `.backup`, não `cp` apenas do `.db` que pode ter WAL. Não copie o token transitório de `/run/pihole-cli`. Registre proprietário, permissões e versão de origem; confirme `PRAGMA quick_check` em ambos os bancos. Antes de aplicar, restaure em ambiente isolado autorizado e prove DNS, autenticação e TLS. O ensaio com fixtures não substitui esse teste do backup real.
3. Faça a atualização em checkout limpo e com rollback para a geração anterior pronto. Se o Ordis ainda tiver StevenBlack, prepare uma revisão de implantação que mantenha a política ativa durante a troca dos binários: a revisão deste PR inclui o #10, e ativá-la diretamente pode atualizar as listas pelo setup. Valide `pihole-ftl.service`, `pihole-ftl-setup.service`, acesso SSH novo, confiança TLS, autenticação e DNS UDP/TCP (A e AAAA) antes de seguir. Não reinicie a máquina sem aprovação separada.
4. Ative Multi PRO e Gambling Medium via setup declarativo. Confirme grupos, exceções e `PRAGMA quick_check`; pilote em um cliente e verifique bloqueios e permissões no Query Log. Use o timer/setup, não um `pihole -g` fora do ambiente declarativo. Confirme consultas via Ordis → `127.0.0.1:5053` → Cloudflare DoH.
5. Resolva os dois caminhos de DNS IPv6 **antes** de mudar a LAN: verifique por captura a supressão dos anúncios de DNS mantendo RA/SLAAC, ou desenhe uma solução separada com DNS IPv6 do Ordis. Confira se o equipamento TP-Link ainda responde fora do Pi-hole e se algum cliente o recebe automaticamente. Se o firmware só permitir `HGWProxy`, não trate desmarcar a opção de informações DHCPv6 como supressão de RDNSS; verifique o pacote. Preserve a conectividade IPv6.
6. Só com os gates anteriores satisfeitos, configure o DHCP do Nokia para distribuir exclusivamente `192.168.1.196`. Não use DNS público secundário. Valide a opção DHCP 6 real e o resolvedor efetivo do Ordis; se a interface exigir um segundo endereço, não presuma que em branco, repetido ou `0.0.0.0` funcione. Mantenha o DHCP no Nokia, DNS/DHCP do AP sem alteração não aprovada e Pi-hole sem DHCP. Renove um cliente por vez.
7. Em Ethernet, Wi-Fi, celular, tablet e TV, confira DNS efetivo, Query Log, IPv4/IPv6, apps e serviços essenciais. Diferencie DNS do sistema de Private DNS, DoH e VPN; não imponha redirecionamento nem bloqueios. Inspecione port forwarding e UPnP e faça teste externo autorizado de ausência de exposição DNS/admin. O Ordis é ponto único de falha.

## Se o firmware impedir a adoção

- **DNS manual por cliente:** menor impacto e preserva IPv6. Não cobre bem TVs/IoT e exige inventário; confirme que o perfil ignora DNS automático tanto de IPv4 quanto de IPv6.
- **RDNSS com ULA do Ordis:** preserva DNS nativo IPv6, mas exige um anunciante autorizado, retirada das propagandas concorrentes e regras futuras limitadas à LAN para TCP/UDP 53. Anunciar mais um endereço sem retirar os concorrentes não elimina bypass.
- **Gateway próprio e Nokia em bridge:** permite controlar DHCP/RA com um só roteador, mas muda a topologia e contraria o requisito de manter DHCP no Nokia. Só considere com nova aprovação, avaliação do provedor, telefonia/IPTV, IPv6-PD, e plano para recuperar gerenciamento e acesso.

## Rollback por etapa

| Etapa | Reverter e comprovar |
| --- | --- |
| DHCP IPv4 | Restaure DNS, pool e reservas registrados; valide a opção 6 e renove apenas os clientes afetados. Use o painel Nokia por IP. |
| RA/DHCPv6 | Restaure a configuração registrada separadamente. Capture RA/DHCPv6; aguarde expiração do RDNSS anterior (600 s observado) e demais lifetimes efetivos ou retire somente as entradas afetadas em clientes de teste. Confirme default route, SLAAC e DNS efetivo. |
| Listas | Suspenda o refresh em janela autorizada. Restaure a Gravity consistente e a política declarativa compatível, ou o timer reaplicará a migração. Verifique `quick_check`, grupos, exceções e respostas novas após recarregar FTL. |
| Binários | Por IP/console, preserve uma cópia do estado pós-falha, pare os escritores, prepare o retorno à geração anterior e restaure **os dois** bancos a partir do backup compatível antes de voltar a servir. Não suponha downgrade de esquema, nem reutilize WAL/SHM da instância substituída. Valide integridade, permissões, consulta permitida e bloqueada em UDP/TCP. |
| Autenticação/TLS | Restaure hash externo e material TLS/ACME pela rotina do host, com permissões originais. Valide certificado e login a partir do desktop permitido; confirme ausência de acesso administrativo sem sessão. Deixe o FTL gerar um token CLI transitório novo. |

Não faça GC nem apague a geração funcional antes do fim da janela. Se a rede estiver afetada, retire primeiro a dependência residencial restaurando os anúncios anteriores; recupere o Ordis separadamente.
