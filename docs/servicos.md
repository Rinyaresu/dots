# Usar serviços do desktop

Este guia descreve o desktop. Lab e Ordis têm políticas próprias.
Construir a configuração não ativa serviços no sistema em uso.

## Rede e acesso remoto

NetworkManager administra endereços e DNS recebidos da rede. Perfis Wi-Fi são
locais, não declarados no flake. Tailscale não substitui DNS, não aceita rotas,
exit nodes ou SSH Tailscale. A instalação nova cadastra um dispositivo novo.
Não copie o estado do daemon anterior.

OpenSSH exige chave pública, sem senha, keyboard-interactive, root ou agent
forwarding. O firewall permite novas conexões TCP 22 somente em `tailscale0`.
A interface não é confiável para outras portas. Grants da tailnet continuam
necessários. O arquivo de autorização é externo à fonte.

| Caminho | Contrato |
| --- | --- |
| `/var/lib/desktop-ssh/authorized_keys/rinyaresu` | Chaves públicas verificadas dos clientes, root:root, 0644 |
| `/var/lib/desktop-ssh/authorized_keys/` | Diretório root:root, 0755, sem escrita por outros |

Provisione o arquivo por console ou canal administrativo já autorizado.
A ausência dele recusa login. Autorizações na home não são consumidas nesse
servidor. Não copie chaves privadas do notebook para o desktop.
Console e sudo continuam aceitando a senha local.

A exceção LAN de recuperação limitada ao notebook está pendente de identificação
estável e escolha de interfaces. Não use endereços observados como reservas nem
libere uma sub-rede inteira. Confira [o login do cliente Tailscale](tailscale.md)
antes de autenticar. A política de daemon bloqueada exige o fluxo compatível do pin.

## Áudio e arquivos

PipeWire e WirePlumber fornecem áudio, com compatibilidade ALSA e PulseAudio.
Use `pavucontrol` ou Noctalia para escolher saída e entrada. Não há regras fixas
de prioridade de dispositivos.

Nautilus usa GVfs para montagem explícita. Montagem e abertura automática de mídia
estão desabilitadas. O perfil não monta partições Windows. Uma ação no gerenciador
de arquivos não autoriza montar volumes que devam ser preservados.

## VPN opcional

`wireguard-tools` está disponível para conexão manual eventual. Não há perfil ou
autoconexão. Mantenha configurações locais fora do Git e do Nix store, com dono
root e modo 0600. Revise rotas, DNS e scripts antes de conectar.
Nenhuma configuração de VPN do notebook pertence a esta migração.

## Containers e VMs

Docker inicia no boot. A conta não pertence ao grupo docker. Use Compose com sudo.
Não existe daemon rootless paralelo. Portas publicadas em bridges novas usam
loopback por padrão. Publicação explícita em outro endereço, redes existentes,
IPv6 e modo host precisam de revisão própria. O firewall não garante isolamento
das portas publicadas pelo Docker.

Não há PostgreSQL nativo selecionado para o desktop. Isso não autoriza remover
serviços ou bancos de uma instalação existente. Cada projeto define suas
necessidades sem conversão automática para containers.

Libvirt e virt-manager oferecem VMs de sistema com autorização Polkit por senha.
QEMU não roda como root. Nenhum hóspede é criado ou configurado para autostart.
Não há bridge física, compartilhamento ou passthrough configurado por esse perfil.

## Snapshots e manutenção

Snapper cria pontos diários somente de `/home`, com sete pontos diários e execução
compensatória após desligamento. Não há snapshots automáticos da raiz ou backup
externo. O armazenamento fica em `/home/.snapshots`, root:root, 0700.
Arquivos apagados podem continuar presentes no histórico.

Para recuperar, liste os pontos com `snapper -c home list` em contexto
administrativo autorizado. Copie o arquivo de
`/home/.snapshots/NUMERO/snapshot/CAMINHO_RELATIVO_A_HOME` para um destino revisado.
Preserve atributos, confira dono, modo e conteúdo antes de substituir o arquivo
atual. Snapshots não protegem contra perda do SSD.

Atualizações e ativações são manuais, sem reboot automático. O desktop prepara
retenção semanal de gerações acima de 30 dias, mas `nix.gc.automatic` continua
falso. Só faça opt-in explícito depois de validar a migração, rollback e agentes.
Lab e Ordis continuam com manutenção manual. Não execute limpeza durante recuperação.
