# nix

Configuração pessoal do NixOS 26.05 estável com flakes, flake-parts, import-tree
e Home Manager. Os módulos seguem o padrão dendritic e se organizam por função.

`desktop` é o host físico. `lab` é uma VM manual isolada, sem compartilhar
Nix store, diretórios ou chaves do host. O login `rinyaresu` com senha `nixos`
existe somente no laboratório. Nunca instale o perfil `lab` no PC.

## Conferir a configuração

Execute da raiz do repositório.

```sh
nix --extra-experimental-features 'nix-command flakes' flake check \
  "path:$PWD" --no-build
nix --extra-experimental-features 'nix-command flakes' build \
  "path:$PWD#nixosConfigurations.desktop.config.system.build.toplevel" --no-link
```

O primeiro comando avalia a configuração. O segundo constrói o sistema sem
aplicá-lo. Não há suíte de testes automatizados neste repositório.

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
- [SSH cifrado com SOPS e recuperação](secrets/README.md).
- [Decisões da configuração](docs/decisoes.md).

## Alterar a configuração

`flake.nix` declara as fontes e `flake.lock` fixa suas revisões.
Cada arquivo em `modules/` é um módulo flake-parts descoberto pelo import-tree.

- `modules/hosts/desktop/` seleciona funcionalidades, hardware, mounts e segredos pessoais.
- `modules/hosts/lab/` seleciona as funcionalidades da VM e mantém seu isolamento.
- `modules/nix/` gera os sistemas e integra NixOS com Home Manager.
- `modules/system/` configura serviços e políticas do sistema.
- `modules/desktop/` configura aplicativos e sessões gráficas.
- `modules/development/` configura shell, editor e ferramentas de desenvolvimento.

Os hosts selecionam funcionalidades em `configurations.nixos.<host>.modules`.
O gerador inclui automaticamente os módulos `flake.modules.homeManager` de mesmo
nome. Não há uma segunda lista de imports Home Manager.

Vários arquivos podem contribuir para um grupo. Git e Fish contribuem para
`base`. Aplicativos gráficos contribuem para `gui`. O arquivo de áudio publica
`nixos.sound` e `homeManager.sound`. Selecionar `sound` no host inclui PipeWire
e pavucontrol. `i3` também inclui suas ferramentas de clipboard e screenshots.

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
