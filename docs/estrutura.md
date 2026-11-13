# Composição dendritic

O repositório usa a composição do
[dotnix](https://github.com/kiriwalawren/dotnix) como referência. Cada arquivo em
`modules/` é um módulo flake-parts. O import-tree descobre esses arquivos, mas
não habilita todas as funcionalidades que eles publicam.

## A seleção pertence ao host

`modules/hosts/desktop/modules.nix` e `modules/hosts/lab/modules.nix` selecionam
módulos NixOS nomeados. Hardware e ajustes específicos pertencem à pasta do host.

```nix
{ config, ... }:
{
  configurations.nixos.desktop.modules = {
    inherit (config.flake.modules.nixos) base gui sound;
  };
}
```

Esse trecho ilustra a seleção, não substitui o host completo. O desktop atual
também seleciona boot, segredos pessoais e restauração privada do Pi. O lab não
seleciona essas funcionalidades.

`modules/nix/nixos-configurations.nix` gera `nixosConfigurations` a partir desse
registro. Ele inclui módulos Home Manager cujos nomes aparecem na seleção do
host. A chave selecionada precisa manter o nome da funcionalidade. Use `inherit`
como no exemplo, sem criar aliases.

## Uma funcionalidade pode configurar duas camadas

`modules/system/sound.nix` publica `flake.modules.nixos.sound` para PipeWire e
`flake.modules.homeManager.sound` para pavucontrol. O host seleciona `sound` uma
vez. Não precisa importar sua parte Home Manager separadamente.

Um arquivo também pode contribuir para um grupo compartilhado. Git e Fish
contribuem para `base`. Ghostty e Firefox contribuem para `gui`. As ferramentas
de desenvolvimento contribuem para `development`.

Os grupos não exigem um arquivo central com a lista de suas contribuições.
As definições com o mesmo nome se combinam pelo sistema de módulos. Um programa
que só precisa de Home Manager pode contribuir a um grupo existente sem criar
um módulo NixOS vazio.

## Os arquivos têm responsáveis definidos

- `modules/nix/` contém a composição dos hosts, a integração Home Manager e a política do Nix.
- `modules/system/` contém locale, usuários, SSH, serviços, memória, energia, boot e SOPS.
- `modules/desktop/` contém aplicativos, gráficos, fontes, i3 e niri.
- `modules/development/` contém Fish, Git, toolchain, provedores de ambientes, Neovim, Herdr e Pi.
- `modules/hosts/` contém as seleções e os ajustes de cada máquina.

i3 e suas ferramentas publicam a mesma funcionalidade `i3`. O host não precisa
saber que há mais de um arquivo. Mise e direnv ficam juntos em
`modules/development/providers.nix`, pois compartilham a política de ativação
explícita e de prevenção de hooks concorrentes.

SOPS separa a infraestrutura `secrets` da declaração `personal-secrets`. O host
físico seleciona ambas. A declaração pessoal continua em
`modules/system/secrets.nix` e aponta para o ciphertext em `secrets/ssh.yaml`.
A identidade age permanece fora deste repositório.

Pi faz parte de `development`. O bootstrap privado tem o nome `pi-bootstrap` e
só o desktop o seleciona. Assim, instalar o programa no lab não restaura o repo
privado nem disponibiliza a chave real.

## Acrescentar uma funcionalidade

Para uma capacidade selecionável, publique `flake.modules.nixos.<nome>` e sua
contraparte `flake.modules.homeManager.<nome>`, quando necessária. Selecione o
nome no arquivo `modules.nix` de cada host que precisa dela.

Para uma configuração comum de um grupo existente, acrescente um arquivo que
contribua para esse grupo. Não crie opções `enable`, módulos vazios ou outra
lista de imports apenas para um programa.

Os comandos de avaliação e build estão no [README](../README.md). Eles não
aplicam a configuração ao sistema em execução.
