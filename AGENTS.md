# Trabalhar nesta configuração

Este repositório configura NixOS estável para `desktop`, `lab` e `ordis`.
Preserve os programas e as preferências existentes em refatorações arquiteturais.
Use recursos nativos de NixOS, Home Manager e flake-parts antes de criar opções próprias.

## Composição

- Todo `.nix` em `modules/` é um módulo flake-parts descoberto por import-tree.
- Descoberta publica definições. Somente `imports` seleciona funcionalidades.
- Publique capacidades em `flake.modules.nixos.<nome>` ou `flake.modules.homeManager.<nome>`.
- Dependências na mesma classe usam `imports`. Dependências entre classes usam asserções sobre opções efetivas do consumidor.
- Nomes iguais entre classes não criam associação. Selecione cada lado explicitamente. Uma capacidade somente Home Manager não precisa de módulo NixOS vazio.

## Identidade

A funcionalidade é referenciada por classe e nome em `flake.modules`. Um arquivo
pode publicar várias funcionalidades da mesma classe. Vários arquivos podem
contribuir para a mesma funcionalidade. O nome público não identifica tecnicamente
cada contribuição. `_file` informa origem e diagnósticos, não deduplicação.

## Deduplicação

- Nix seleciona contribuições por `key` antes do merge. Isso não memoiza funções.
- Caminhos importados diretamente já têm identidade automática. Não adicione wrappers ou keys para reproduzir essa garantia.
- Attrsets e funções anônimos têm identidade posicional. Nas contribuições reutilizáveis publicadas, declare uma `key` nativa com namespace de arquivo e rótulo local distinto, como no exemplo abaixo.
- O rótulo costuma indicar classe e nome, mas não é uma segunda API funcional. Não precisa acompanhar uma renomeação pública. Duas contribuições distintas do mesmo arquivo precisam de rótulos diferentes, mesmo quando contribuem para o mesmo nome.
- Instâncias parametrizadas diferentes precisam de identidades distintas, ou devem permanecer anônimas quando não se pretende deduplicá-las.
- Fragmentos inline privados sob um único pai identificado usam o fallback nativo. Um helper compartilhado por pais diferentes precisa de identidade se deve representar uma única contribuição. Raízes de host usadas uma vez não precisam de keys explícitas.
- Não use apenas o arquivo ou apenas a capacidade como key. Uma colisão pode descartar definições silenciosamente. Não remova dependências dos componentes para obrigar o host a coordenar diamantes.

Os comportamentos e contraexemplos estão em `checks/modules/` e
`modules/nix/module-system-checks.nix`. Leia [estrutura](docs/estrutura.md) ao
alterar o contrato. Não crie um registro ou deduplicador próprio.

Exemplo completo de publicação de uma capacidade somente Home Manager:

```nix
{
  flake.modules.homeManager.exemplo = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.exemplo";
    home.packages = [ pkgs.hello ];
  };
}
```

## Hosts e contas

`modules/hosts/<host>/modules.nix` publica a saída nativa `nixosSystem`, com
`modules = [ config.flake.modules.nixos.host-<host> ]`. Os demais arquivos daquele
host contribuem para a mesma raiz `flake.modules.nixos.host-<host>`.
Importe capacidades na raiz. Uma raiz de host não é uma capacidade compartilhável.

Contas pertencem a `users.users.<nome>`. Home Manager é opcional e pertence a
`home-manager.users.<nome>`. Importe `nixos.home-manager` no host que o utiliza.
A integração upstream deriva nome, home e UID da conta NixOS. A ponte local verifica
que nome e home continuam correspondentes. Declare `home.stateVersion` por conta,
independentemente de `system.stateVersion` do host. Preserve ambas nas atualizações.

Exemplo de seleção dentro de um módulo raiz existente:

```nix
{ config, ... }:
{
  flake.modules.nixos.host-exemplo = {
    imports = [ config.flake.modules.nixos.home-manager ];
    users.users.alice = { isNormalUser = true; home = "/srv/alice"; };
    home-manager.users.alice = {
      home.stateVersion = "26.05";
      imports = [ config.flake.modules.homeManager.git ];
    };
  };
}
```

Esse fragmento não substitui hardware, filesystem raiz ou a saída do host.

## Responsabilidades

- `modules/features/` contém capacidades reutilizáveis. Use uma pasta quando houver arquivos relacionados, como i3 e suas ferramentas.
- `modules/users/` contém identidade e integrações pessoais. A conta e o Git de rinyaresu, seu SSH cifrado e seu bootstrap Pi ficam juntos.
- `modules/hosts/` contém seleção, hardware, boot, contas particulares e versões de estado de cada máquina.
- `modules/nix/` contém a ponte Home Manager e os checks. `checks/modules/` contém fixtures usadas somente pelos testes, fora da descoberta de funcionalidades.
- `secrets/` documenta o contrato de provisionamento externo. Ciphertext pessoal, identidades age, chaves privadas e perfis VPN ficam fora deste repositório e da fonte Nix. O módulo pessoal usa caminhos de runtime e falha se os insumos não forem provisionados.

Não recrie `base`, `gui`, `development`, matching por nomes ou um registro paralelo
de usuários. Não use aliases globais de usuário, módulos vazios ou opções `enable`
próprias para substituir imports. Mantenha políticas pessoais fora dos mecanismos
compartilhados. Preserve diferenças reais de locale, memória e console entre hosts.

## Verificar e concluir

Para mudanças de composição ou contratos compartilhados, execute da raiz.
Para uma capacidade isolada, avalie e construa os consumidores afetados.
Em mudanças somente de documentação, confira os links e avalie exemplos alterados.

```sh
./scripts/check --quick
./scripts/check
source=$(python3 -B scripts/export-source.py)
nix build --no-link --no-write-lock-file \
  "path:$source#nixosConfigurations.desktop.config.system.build.toplevel" \
  "path:$source#nixosConfigurations.lab.config.system.build.toplevel" \
  "path:$source#nixosConfigurations.ordis.config.system.build.toplevel"
git diff --check
```

Antes de executar Nix, revise `source-files.txt`. `scripts/check` exporta somente
esses arquivos atuais e registra hashes fora da fonte. Inclua novos consumidores
na lista explícita. Não teste um HEAD antigo como prova de alterações locais.
O modo rápido ainda executa formatter por `nix run`, que pode realizar ou baixar
dependências. O `flake check --no-build` posterior não executa builders ou VMs.
Documentação privada e relatórios ficam fora do checkout publicável.

`checks.architecture` protege hosts, contas, dependências e os diamantes reais de
Ghostty e Pi. `checks.module-system` separa identidade, deduplicação e
contraexemplos, incluindo múltiplas funcionalidades por arquivo e multifile.
Ao mudar um contrato, ajuste seu caso positivo e seu caso de recusa.
Avaliação não substitui build. Build não substitui teste de runtime.
Atualize `docs/estrutura.md` quando mudar os contratos. Confira os exemplos contra o código.

Ordis é uma máquina instalada. Inspeção SSH não autoriza ativação, reboot ou escrita
remota. Antes de qualquer deploy autorizado, preserve a geração funcional e confira
SSH novo, sudo, rede, armazenamento e boot. Siga `docs/ordis.md`.
O perfil lab não pode compartilhar store, diretórios ou chaves do host.
Commits e publicação remota respeitam a autorização explícita da tarefa.
Não faça push direto na branch padrão, merge, reescrita remota ou mudança de
visibilidade sem autorização específica. O proprietário pode fornecer uma política
privada adicional. Ela não é insumo de avaliação ou build deste repositório.
A autorização de entrega não autoriza ativações ou deploy.
