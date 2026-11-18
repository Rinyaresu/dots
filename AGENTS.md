# Trabalhar nesta configuração

## Composição

- import-tree descobre módulos flake-parts em `modules/`. Prefixe hardware importado explicitamente com `_` para excluir da descoberta.
- Publique por domínio em `flake.modules.nixos.<nome>` ou `flake.modules.homeManager.<nome>`. Contribua ao grupo diretamente, salvo quando houver consumidor independente. Use imports nativos e chaves distintas para contribuições anônimas reutilizadas por múltiplos caminhos.
- Selecione capacidades em `modules/hosts/<host>/modules.nix`. O montador usa as chaves diretas de `configurations.nixos.<host>.modules` para associar Home Manager, nunca nomes transitivos. Associe a conta NixOS local via `homeUser`. Preserve separadamente `system.stateVersion` e `home.stateVersion`.
- `common` é só NixOS; `base` reúne a base de CLI, `gui` os gráficos, e `desktop-personal` é exclusivo do desktop. Lab deve permanecer sem store, diretórios, chaves ou rede compartilhados com o host; Ordis não recebe Home Manager nem a conta pessoal.

## Verificar sem ativar

- Revise os arquivos rastreados antes de avaliar. Nix usa a fonte Git; alterações de arquivos rastreados numa árvore suja também podem entrar. Para evidência de entrega, execute em checkout limpo e registre o SHA. Não use `path:` para contornar esse recorte.
- Não inclua chaves privadas, identidades age, tokens, estado pessoal ou material de recuperação na fonte, store, logs ou artefatos. Apenas o ciphertext SOPS revisado de `secrets/ssh.yaml` é autorizado. Para provisionamento ou recuperação de credenciais, leia [secrets/README.md](secrets/README.md).
- Execute `nix flake check --show-trace` e construa os toplevels afetados com `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel`. Formate arquivos Nix com `nix fmt -- <arquivo.nix>`.
- Para mudanças em contratos de runtime, execute as [VMs pertinentes](README.md#verificar-sem-ativar) com KVM. Build não comprova comportamento em runtime ou em hardware físico.
- Autorização para editar, construir ou publicar não inclui merge, deploy, ativação, reboot, operação remota ou mudança de visibilidade. Para operação autorizada em Ordis, leia [docs/ordis.md](docs/ordis.md).
