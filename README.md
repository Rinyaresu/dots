# nix

Configuração NixOS estável com flakes, flake-parts, import-tree e Home Manager.
O lock fixa as dependências. O repositório publica três sistemas independentes.

- `desktop` usa niri com Noctalia, com i3 como alternativa de recuperação.
- `lab` é uma VM manual com store próprio e rede desabilitada. A senha pública
  `nixos` existe somente nesse perfil. Não instale o lab em máquina física.
- `ordis` é um servidor sem Home Manager ou aplicativos pessoais. Alterar suas
  fontes não autoriza aplicar a configuração no servidor instalado.

## Verificar sem ativar

Use Linux x86_64, Nix com flakes, Bash, Python 3 e Git. KVM permite executar os
checks de integração em VMs descartáveis.

```sh
./scripts/check --quick
./scripts/check
source=$(python3 -B scripts/export-source.py)
nix --extra-experimental-features 'nix-command flakes' build --no-link --no-write-lock-file \
  "path:$source#nixosConfigurations.desktop.config.system.build.toplevel" \
  "path:$source#nixosConfigurations.lab.config.system.build.toplevel" \
  "path:$source#nixosConfigurations.ordis.config.system.build.toplevel"
```

`scripts/check` exporta somente os arquivos enumerados em `source-files.txt`.
A exportação usa os bytes atuais, inclusive alterações ainda não commitadas.
Documentação, arquivos ignorados e histórico Git não entram nessa exportação.
O único documento SOPS permitido é `secrets/ssh.yaml`, cifrado e revisado.
Revise a lista ao acrescentar arquivos consumidos pelo flake ou pelos testes.
O exportador recusa caminhos privados, travessia de diretórios e symlinks.

Cada exportação fica em `~/.local/state/pi/work-artifacts/nix/check-source-*/`.
`manifest.json`, fora da fonte exportada, registra hashes e permissões executáveis.
Use esse conteúdo para identificar a revisão realmente testada. Não execute Nix
com `path:$PWD` sobre uma árvore que contenha planejamento, backups ou segredos.
`.gitignore` não filtra fontes `path:`.

O modo rápido executa testes Python, formatter e avaliação dos checks. O formatter
pode realizar ou baixar dependências. `flake check --no-build` não executa os
builders dos checks ou suas VMs. O modo completo os executa. Nenhum dos modos
substitui o build dos três sistemas acima ou a validação física.

O workflow `Checks` executa `./scripts/check` em push e pull request. Não aplica
sistemas e não usa credenciais pessoais. Os builds completos dos três hosts são
uma verificação separada. Para instalar o hook rápido neste checkout, execute
`git config --local core.hooksPath .githooks`. O hook examina a árvore de trabalho
atual, não cada ref enviada, e não substitui o CI.

## Usar e manter

- [Sessões, atalhos e capturas](docs/desktop.md).
- [Ambientes por projeto e terminal](docs/desenvolvimento.md).
- [TreeView do Herdr por máquina](docs/herdr-tree.md).
- [Serviços locais e acesso remoto](docs/servicos.md).
- [Instalação e limites de recuperação](docs/instalacao.md).
- [Provisionamento SOPS e recuperação](secrets/README.md).
- [Bootstrap de uma máquina limpa](docs/bootstrap.md).
- [Composição e contratos](docs/estrutura.md).
- [Servidor](docs/ordis.md), [Pi-hole](docs/pihole.md) e [Tailscale](docs/tailscale.md).

A avaliação e o build não dependem de um checkout Home, agente SSH pessoal ou
acesso à tailnet. O ciphertext SOPS acompanha a fonte pública e pode entrar no
store. A identidade age permanece externa. Sua ausência impede SOPS e Home
Manager, em vez de gerar uma chave substituta. A chave SSH só é descriptografada
em runtime e mantém sua passphrase.

Atualizações e ativações são manuais. A política semanal de retenção está
preparada, mas permanece desabilitada até validar a migração e a continuidade dos
agentes. Não execute garbage collection durante instalação ou recuperação.
Preserve `system.stateVersion` e `home.stateVersion` nas atualizações.

Leia [AGENTS.md](AGENTS.md) antes de alterar composição. Use imports nativos.
Não há registro de usuários ou mecanismo próprio de associação entre classes.
