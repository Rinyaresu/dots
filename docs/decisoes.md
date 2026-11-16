# Escolhas da configuração

## Composição

O flake fixa NixOS estável e Home Manager integrado. Flake-parts e import-tree
publicam módulos. Imports selecionam capacidades. Dependências na mesma classe
usam imports nativos; dependências entre classes verificam opções efetivas.
Contas, homes e versões de estado pertencem aos consumidores.
Veja [os contratos e suas contraprovas](estrutura.md).

## Desktop

Niri e Noctalia são a sessão principal. i3 permanece como alternativa manual.
O login é no console, sem autologin ou display manager. Fish é o shell de login
e das panes Herdr. Terminais gráficos fazem autoattach sem criar um daemon próprio.

Mise e direnv têm integração automática, mas confiança e instalação continuam
explícitas. Neovim começa pequeno. A aparência é clara Rosé Pine Dawn.
Firefox é padrão, Chrome é secundário. Bitwarden desktop não fornece agente SSH.
Jogos permanecem fora do Linux. Impressão e scanners não são configurados.

Linux usa Btrfs persistente com zstd, subvolumes separados para raiz, home e store,
sem LUKS ou swap no SSD. Zram tem capacidade lógica de 100% da RAM com zstd.
Snapshots diários de home retêm sete pontos. Não há snapshots automáticos da raiz
ou backup externo geral. Leitura física offline expõe os dados.

O Limine não usa assinatura. Isso não altera Secure Boot do firmware e não prova
aceitação do executável. A mídia e o boot devem ser validados mantendo a política
existente antes da instalação. Windows e seu disco devem permanecer intactos.

## Confiança e ciclo de vida

A chave SSH mantém passphrase. Um agente OpenSSH atende a sessão, Herdr e bootstrap.
O primeiro uso pede desbloqueio gráfico. Bloqueio de tela não descarrega a chave.
GNOME Keyring atende Secret Service, separado de SSH e Bitwarden.
SOPS recebe identidade age e ciphertext por caminhos externos em runtime.
Avaliação e build não consomem o material pessoal.

SSH de entrada usa o overlay Tailscale e chave pública. A recuperação LAN limitada
a um cliente depende de identificação estável, ainda pendente. DNS permanece da
rede. O desktop novo não reutiliza identidade Tailscale anterior.

Docker inicia no boot, com administração por sudo e publicação local por padrão.
Libvirt exige autorização Polkit e não cria hóspedes automáticos.
Não há PostgreSQL nativo selecionado. Essa ausência não autoriza remover bancos
ou serviços de uma instalação existente.

Atualizações e ativações são manuais. A manutenção semanal de gerações acima de
30 dias está preparada, mas desabilitada até validação de rollback e continuidade
dos agentes. Lab e servidor preservam políticas próprias.

## Limites das provas

Checks de opções protegem merges e contratos. Configurações são validadas pelos
binários fixados. Testes de scripts usam ferramentas simuladas onde indicado.
VMs exercem permissões, SSH, firewall, SOPS e Btrfs com credenciais descartáveis.
Nenhuma dessas provas substitui firmware, discos, GPU, monitores, suspensão,
cofres reais ou chamadas Discord, OBS e Meet no desktop instalado.
