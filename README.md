# nix

Configuração pessoal do NixOS 26.05 estável com flakes, flake-parts, import-tree
e Home Manager. Os módulos seguem o padrão dendritic e se organizam por função.

`desktop` prepara a futura migração do PC CachyOS. `ordis` é o servidor doméstico
sem desktop, com usuário próprio, SSH e systemd-boot. Leia [a operação do Ordis](docs/ordis.md)
e [acesso privado pelo notebook com Tailscale](docs/tailscale.md).
`lab` é uma VM manual isolada, sem compartilhar
Nix store, diretórios ou chaves do host. O login `rinyaresu` com senha `nixos`
existe somente no laboratório. Nunca instale o perfil `lab` no PC.

O perfil Ordis seleciona Pi-hole e Tailscale. Atualizar este repositório não faz
deploy: somente um rebuild autorizado aplica os serviços. Antes de aplicar no
servidor, siga os requisitos de credenciais e recuperação dos guias de cada serviço.

## Conferir a configuração

Execute da raiz do repositório.

```sh
nix --extra-experimental-features 'nix-command flakes' flake check \
  "path:$PWD" --no-write-lock-file
nix --extra-experimental-features 'nix-command flakes' build --no-link --no-write-lock-file \
  "path:$PWD#nixosConfigurations.desktop.config.system.build.toplevel" \
  "path:$PWD#nixosConfigurations.lab.config.system.build.toplevel" \
  "path:$PWD#nixosConfigurations.ordis.config.system.build.toplevel"
```

O primeiro comando avalia o flake, constrói os checks arquiteturais e do sistema
de módulos e executa as integrações Pi-hole e Tailscale em VMs QEMU (KVM recomendado).
A VM Tailscale usa a raiz real do Ordis e também verifica a coexistência com Pi-hole,
sem autenticar dispositivos ou ativar o servidor instalado.
O segundo constrói os três sistemas sem aplicá-los. Os checks cobrem
composição, identidade, deduplicação, dependências e isolamento. Não testam sessões
gráficas nem hardware.

`path:` inclui arquivos locais mesmo antes do primeiro commit. Ele também pode
incluir arquivos ignorados pelo Git. Nunca coloque chaves privadas ou identidades
age em texto simples neste diretório. `.gitignore` não impede sua cópia para o
Nix store.

## Instalar e usar

Leia [o guia de instalação](docs/instalacao.md) antes de alterar discos.
O destino é o SSD SATA. O NVMe do Windows deve permanecer intacto.
Confira o repositório publicado, o acesso ao BitLocker e a aceitação da mídia
pelo firmware antes de instalar.

Faça login no console e execute `startx` para i3 ou `niri-session` para niri com
Noctalia. Super+Enter abre Ghostty. Não há início automático do desktop.

- [Desktop e atalhos](docs/desktop.md).
- [Mise, direnv, Herdr e Neovim](docs/desenvolvimento.md).
- [Rede, VPN, Docker e VMs](docs/servicos.md).
- [Pi-hole no Ordis: testes, implantação e recuperação](docs/pihole.md).
- [SSH cifrado com SOPS e recuperação](secrets/README.md).
- [Decisões da configuração](docs/decisoes.md).

## Alterar a configuração

`flake.nix` declara as fontes e `flake.lock` fixa suas revisões.
Cada arquivo em `modules/` é um módulo flake-parts descoberto pelo import-tree.

- `modules/hosts/` publica cada `nixosSystem` e compõe sua raiz `nixos.host-<host>` com hardware e estado próprios.
- `modules/features/` publica capacidades por função. Arquivos relacionados ficam juntos, como i3 e suas ferramentas.
- `modules/users/` contém identidade e integrações pessoais, incluindo SSH cifrado e bootstrap privado do Pi.
- `modules/nix/` contém a integração Home Manager e os checks.

Os hosts importam explicitamente módulos `flake.modules.nixos`. Cada conta
seleciona seus próprios módulos `flake.modules.homeManager` em
`home-manager.users.<nome>.imports`. A integração nativa deriva nome e home da
conta NixOS. Não existe usuário principal global ou matching por nomes de módulos.

Uma capacidade pode ter duas partes selecionáveis. `nixos.sound` configura
PipeWire, e `homeManager.sound` instala pavucontrol na conta escolhida. i3 inclui
suas ferramentas de clipboard e screenshots. Contribuições reutilizáveis usam
keys nativas qualificadas para deduplicar imports sobrepostos. Nomes publicados
e `_file` não fornecem essa garantia.

Leia o [contrato de desenvolvimento](AGENTS.md) antes de alterar a composição.

Leia [a composição dendritic](docs/estrutura.md) para acrescentar ou selecionar
uma funcionalidade.

Home Manager participa do rebuild do NixOS. Não há sincronização deste repo para
o CachyOS. Somente no NixOS já instalado, aplique uma alteração temporariamente
antes de torná-la persistente.

```sh
sudo nixos-rebuild test --flake "path:$PWD#desktop"
sudo nixos-rebuild switch --flake "path:$PWD#desktop"
```

`switch` também atualiza o boot. O Limine não exige assinatura nem chaves Secure
Boot. Isso não modifica o estado do Secure Boot na BIOS.

Atualizações do lockfile e limpeza do Nix store são operações sob demanda.
Preserve gerações conhecidas antes de garbage collection. Não altere
`system.stateVersion` ou `home.stateVersion` para acompanhar a release.
