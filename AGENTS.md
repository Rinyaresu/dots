# dots

O flake declara NixOS; não é configuração aplicada ao CachyOS. Para operação e recuperação, use o [procedimento do host](README.md). Para localizar os demais repositórios pessoais, use o mapa do Home.

## Composição

- import-tree descobre módulos flake-parts em `modules/`. Prefixe hardware importado explicitamente com `_` para excluir da descoberta.
- Publique por domínio em `flake.modules.nixos.<nome>` ou `flake.modules.homeManager.<nome>`. Contribua ao grupo diretamente, salvo quando houver consumidor independente. Use imports nativos e chaves distintas para contribuições anônimas reutilizadas por múltiplos caminhos.
- Selecione capacidades em `modules/hosts/<host>/modules.nix`. O montador usa as chaves diretas de `configurations.nixos.<host>.modules` para associar Home Manager, nunca nomes transitivos. Associe a conta NixOS local via `homeUser`. Preserve separadamente `system.stateVersion` e `home.stateVersion`.
- `common` é só NixOS; `base` reúne a base de CLI, `gui` os gráficos, e `desktop-personal` é exclusivo do desktop. Lab deve permanecer sem store, diretórios, chaves ou rede compartilhados com o host; Ordis não recebe Home Manager nem a conta pessoal.

## Verificar e operar

- Use os [gates nativos do README](README.md#verificar-sem-ativar). Para evidência, registre o SHA de uma fonte Git limpa; não use `path:` para contornar o recorte. Rode VMs pertinentes em KVM somente quando o contrato de runtime ou a derivação for afetado. Build não comprova hardware ou serviços reais.
- Mantenha chaves privadas, identidades age, tokens, estado pessoal e recuperação fora de Git, store, logs e artefatos. A exceção é o ciphertext revisado de [`modules/system/users/rinyaresu/ssh/secrets.yaml`](modules/system/users/rinyaresu/ssh/secrets.yaml). Para provisionar, rotacionar ou recuperar, leia [o guia de credenciais](secrets/README.md).
