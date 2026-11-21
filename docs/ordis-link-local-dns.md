# DNS IPv6 link-local do Ordis

O endereço a anunciar é **`fe80::196:53`**, não o link-local automático do NetworkManager. O Ordis mantém IPv4, o perfil NetworkManager, SLAAC e rotas existentes. O serviço adiciona somente um /128 com DAD e sem rota de prefixo; o dispatcher restaura o endereço após `up` e `reapply`. O firewall usa o backend iptables do NixOS (binário ip6tables com compatibilidade nf_tables no host). UDP/TCP 53 são permitidos na `eno1` apenas para esse destino IPv6. A origem pode ser link-local ou um endereço unicast do cliente na LAN. O escopo link-local e a interface delimitam o acesso; não há liberação no endereço global do Ordis nem no Tailscale.

## Aplicação (somente após autorização)

1. Siga [Manter Ordis](../README.md#manter-ordis). Compare o sistema ativo, o de boot e o checkout limpo aprovado. Garanta console e uma nova sessão SSH por IPv4; não confie só em uma sessão já estabelecida. Em Ethernet e Wi-Fi, registre os resultados IPv4, IPv6 e os anúncios DNS antes da mudança. Verifique se o endereço escolhido não está em uso no enlace; DAD no Ordis é a confirmação decisiva.
2. No Ordis, com console disponível, registre o caminho de retorno e faça **ativação temporária**, não `switch` nem reboot:

   ```sh
   previous=$(readlink -f /run/current-system)
   printf '%s\n' "$previous"  # anote também fora desta sessão
   sudo nixos-rebuild test --flake .#ordis
   systemctl status pihole-link-local.service firewall.service pihole-ftl.service
   ip -6 address show dev eno1 to fe80::196:53/128
   sudo ip6tables -S nixos-fw
   ss -lnut 'sport = :53'
   ```

   O endereço deve aparecer com `scope link`, sem `tentative` ou `dadfailed`. Se houver conflito ou sumir após reativação autorizada do perfil, pare. Confirme no console que IPv4, rota IPv6, os prefixos SLAAC e a geração de boot não mudaram. Compare o firewall e confirme uma nova conexão SSH.
3. De um cliente pessoal na LAN (repita no Wi-Fi com a interface local correta):

   ```sh
   IF=enp7s0
   for type in A AAAA; do
     for transport in +notcp +tcp; do
       dig @"fe80::196:53%$IF" www.iana.org "$type" "$transport" +time=2 +tries=1
       dig @192.168.1.196 www.iana.org "$type" "$transport" +time=2 +tries=1
     done
   done
   ```

   Confirme respostas e Query Log do Pi-hole. Teste também com `dig -b ENDEREÇO_GLOBAL_DO_CLIENTE @"fe80::196:53%$IF" ...` se o cliente tiver um global on-link. Confirme que DNS UDP/TCP não responde nos IPv6 global e Tailscale do Ordis a partir de clientes com rota até cada endereço. Um caminho sem rota não prova bloqueio. Confira que HTTPS, SSH e conectividade IPv4/IPv6 continuam iguais.
4. Só depois da validação e com aprovação separada, persista a geração. Reboot e alteração no Nokia também exigem aprovação separada. No Nokia, quando autorizado, o DNS IPv6 estático preferencial é `fe80::196:53` (sem zona ou máscara); mantenha o alternativo vazio e não mude IPv4, prefixo nem RA/SLAAC. Verifique RDNSS (opção 25 em RA) e DHCPv6 (opção 23 no Reply) em Ethernet e Wi-Fi; o gateway pode continuar `fe80::1` sem ser DNS.

## Voltar

Se o Nokia ainda não anunciar o endereço novo, no Ordis use o caminho previamente registrado, por console se necessário: `sudo "$previous/bin/switch-to-configuration" test`. Se já estiver anunciado, primeiro reverta o DNS IPv6 no equipamento anunciante com autorização, confirme os anúncios e aguarde a expiração em clientes antes de retirar o endereço do Ordis. Confira a ausência do alias e das duas exceções IPv6 após a reversão, depois teste DNS IPv4, acesso novo SSH e conectividade dual-stack. Se já tiver persistido a alteração, restaure separadamente a geração de boot funcional conforme o [README](../README.md#manter-ordis).
