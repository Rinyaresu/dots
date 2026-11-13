# Usar serviços locais

## Ferramentas básicas

A base inclui `btop`, `ripgrep` (`rg`), `fd`, `fzf`, `jq`, `file`, `zip`, `unzip`,
`lsof`, `dnsutils` (`dig`), `pciutils` (`lspci`), `usbutils` (`lsusb`) e `gh`.
Elas usam os padrões nativos, sem aliases ou hooks de shell adicionais.
`rsync`, `curl`, `top`, `man` e `strace` já vêm na base do NixOS.
A presença de `gh` não configura login nem altera a autenticação SSH do Git.

## Áudio

Abra `pavucontrol` para escolher dispositivos e ajustar o volume de cada
aplicativo. Ele controla o áudio do PipeWire pela compatibilidade PulseAudio.
Também está disponível no niri, além dos controles do Noctalia.

## Arquivos e volumes

Nautilus tem suporte GVfs/UDisks2 para acessar arquivos e montar volumes por
solicitação. A montagem automática e a abertura automática de mídia estão
desativadas. Escolha explicitamente o dispositivo na interface e desmonte ou ejete
a mídia antes de removê-la. Isso não autoriza montar o volume BitLocker.

## Conectar a rede

Use `nmtui` no console ou as interfaces de rede da sessão gráfica. NetworkManager
administra as conexões. Não importei senhas Wi-Fi ou perfis do CachyOS.

## Conectar a VPN de trabalho manualmente

Mantenha o arquivo WireGuard fora deste repositório e do Nix store. Copie-o
localmente em cada instalação, por exemplo para `/etc/wireguard/trabalho.conf`,
com dono root e permissão 0600. Não habilite uma unidade de autostart.

Conecte e desconecte explicitamente com a ferramenta nativa.

```sh
sudo wg-quick up /etc/wireguard/trabalho.conf
sudo wg-quick down /etc/wireguard/trabalho.conf
```

`wg-quick` usa as rotas e o DNS definidos no arquivo quando você pede a conexão.
Não use importação automática do NetworkManager para esse perfil. Ela pode
ativar a conexão antes de desabilitar autoconnect. Confira o DNS e os scripts
exigidos pelo perfil corporativo.

## Executar containers

Docker inicia no boot. Seu usuário não pertence ao grupo docker e não tem daemon
rootless paralelo.

```sh
sudo docker compose up
sudo docker compose down
```

A configuração usa loopback como endereço padrão das portas publicadas nas
bridges novas. Isso não muda redes existentes ou uma publicação explícita
como `0.0.0.0:3000:3000`. `network_mode: host` também fica fora dessa proteção.
Revise as portas dos projetos compartilhados antes de executá-los. O firewall sozinho não é garantia contra exposição pelo Docker.

Os serviços nativos de projeto são manuais. Não configurei PostgreSQL ou Redis
globais no boot.

## Criar uma VM

Abra `virt-manager` na sessão gráfica. Use uma conexão QEMU/KVM de sistema para
as máquinas que precisam de recursos de rede do libvirt. A operação administrativa
usa Polkit com senha, sem incluir o usuário no grupo libvirtd.

QEMU e `virsh` também estão disponíveis. A configuração não cria hóspedes,
compartilhamentos de diretórios, passthrough ou bridge com a rede física.
Nenhuma VM de laboratório começa automaticamente por esta configuração.
