# nix

Configuração NixOS estável com flakes, flake-parts, import-tree e Home Manager.
O lock fixa as dependências. O repositório publica três sistemas independentes.

- `desktop` usa niri com Noctalia, com i3 como alternativa de recuperação.
- `lab` é uma VM manual com store próprio e rede desabilitada. A senha pública
  `nixos` existe somente nesse perfil. Não instale o lab em máquina física.
- `ordis` é um servidor sem Home Manager ou aplicativos pessoais. Alterar suas
  fontes não autoriza aplicar a configuração no servidor instalado.

## Verificar sem ativar

Use Linux x86_64 com Git e Nix (flakes). Revise os arquivos rastreados e use
um checkout limpo para vincular a verificação a um commit. Nix copia o snapshot
Git para o store, inclusive documentação rastreada. Não rastreie credenciais
ou estado privado.

```sh
nix flake check --show-trace
for host in desktop lab ordis; do
  nix build --no-link ".#nixosConfigurations.$host.config.system.build.toplevel"
done
```

Formate com `nix fmt -- flake.nix` (ou passe os arquivos alterados). A CI testa
o merge sintético de PRs para `master` e a revisão de cada push a `master`, com
checks leves e uma matriz de hosts descoberta a partir do flake.

Os testes de runtime são separados. Execute com KVM, individualmente:

```sh
for test in desktop-access desktop-snapshots tailscale pihole secret-runtime bootstrap-runtime ssh-session; do
  nix build --no-link --rebuild -L ".#packages.x86_64-linux.$test" || exit
done
```

Nenhum desses comandos ativa um sistema. Procedimentos em `docs/` que ainda
mencionam o wrapper antigo devem usar os comandos nativos acima.

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
O montador associa Home Manager pelas chaves selecionadas diretamente pelo host.
