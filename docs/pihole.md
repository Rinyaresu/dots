# Contratos do Pi-hole

Ordis seleciona Pi-hole nativo do nixpkgs fixado. Desktop e lab não o selecionam.
A capacidade usa os serviços `pihole-ftl` e `pihole-web`, sem instalador remoto,
container paralelo ou atualização automática de pacotes.
A raiz do host possui a política de interface, rede e upstreams.
O módulo reutilizável possui provisionamento, sandbox e correções upstream.

## Autenticação fora do store

O serviço recusa iniciar sem `/var/lib/pihole-secrets/admin-hash`, root:root, 0600,
em diretório 0700. O conteúdo é um hash Balloon-SHA256 v6, não a senha em claro.
`LoadCredential` entrega o arquivo ao serviço. O wrapper passa o hash pelo
ambiente, não por argv. O provisionador `pihole-admin-hash` confirma a senha e
faz substituição atômica. Não passe senha em argumentos, opções Nix ou histórico.

O token efêmero de CLI fica em tmpfs. Sessões administrativas não persistem.
Core dumps e swap das unidades são restringidos. Isso não cifra disco ou swap do
host e não protege contra root ou captura de memória do kernel.
Não execute provisionamento com tracing ou captura do ambiente.

Uma correção local de `api.sh` usa pipes para passar senha e SID ao curl.
O check inspeciona o script empacotado e amostra processos durante autenticação.
Outro ajuste torna inclusão de listas idempotente e sinaliza o MainPID após a
troca do gravity. Listas existentes não são removidas automaticamente por rollback.

## Rede e persistência

DNS aceita TCP e UDP somente pela política LAN da raiz. IPv6 como transporte DNS
não é oferecido por essa política. Consultas AAAA por IPv4 continuam disponíveis.
O painel HTTP escuta em loopback e exige túnel SSH para administração remota.
O módulo não fornece DHCP, NTP ou anúncios de roteador.
O resolvedor do host continua independente do serviço que ele próprio fornece.

A lista de bloqueio é um snapshot imutável com revisão e hash fixos na fonte.
Atualizar esse snapshot é uma mudança deliberada, seguida dos testes.
Configuração TOML é declarativa. Estado de listas, bancos e histórico continua
persistente e pode conter dados privados. Não publique logs ou backups do serviço.

Para preservar estado, pare os serviços com autorização e faça cópia consistente
dos bancos, hash e revisão para armazenamento privado protegido. Não copie SQLite
ativo sem mecanismo transacional. Um downgrade pode não aceitar banco migrado.
Gerações Nix não substituem essa cópia. Não execute limpeza durante recuperação.

## Provas mantidas

`pihole-policy` verifica seleção e política efetiva. `pihole` usa VMs NixOS com
servidor real, upstream determinístico e clientes permitidos e não confiáveis.
As credenciais são fixtures geradas no ambiente descartável.

O teste verifica ausência de credencial, provisionamento e rotação, DNS permitido
e bloqueado por TCP e UDP, login e recusas de API, restrições de portas, permissões,
ausência de credenciais em argv e persistência após restart, morte do processo e
reboot virtual. Leitura de um drvPath não executa esse teste.

Execute `./scripts/check` ou construa o check específico a partir de uma
[exportação explícita](../README.md#verificar-sem-ativar).
O teste não comprova roteador real, saúde do disco, UI em navegador, restauração
de backup real ou alcance externo. Alterar os arquivos não autoriza ativar o
serviço instalado. Siga [as condições de deploy](ordis.md).

## Referências

- [Configuração FTL](https://docs.pi-hole.net/ftldns/configfile/).
- [Nixpkgs fixado](https://github.com/NixOS/nixpkgs/blob/ac588ef1c914865dad517b337ea0eb9694a4021c/nixos/modules/services/networking/pihole-ftl.nix).
- [Core v6.4.2](https://github.com/pi-hole/pi-hole/blob/v6.4.2/gravity.sh).
