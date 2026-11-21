# Instruções para agentes

Use o [README](README.md) para entender os hosts, a arquitetura e os comandos de verificação. Para outros repositórios pessoais, consulte o mapa do `home`.

- **Escopo:** o flake configura NixOS, não o CachyOS atualmente em execução. Não confunda fonte declarada, geração ativa e bootada.
- **Composição:** `import-tree` descobre módulos sob `modules/`; arquivos de hardware importados diretamente usam prefixo `_`. Novas capacidades pertencem ao domínio responsável e são selecionadas por host em `modules/hosts/<host>/modules.nix`. Preserve `system.stateVersion` e `home.stateVersion`.
- **Isolamento:** o `lab` permanece sem rede, diretórios ou store compartilhados; Ordis não recebe Home Manager nem a conta pessoal. Não amplie grants, SSH, firewall ou acesso entre máquinas incidentalmente.
- **Segredos:** versionar apenas ciphertext SOPS revisado; identidades age, chaves privadas, senhas, tokens e estado mutável ficam fora de Git, store e logs publicados. Declare cada segredo junto da funcionalidade responsável; não copie credenciais entre hosts.
- **Evidência:** valide a menor superfície relevante e registre commit, comandos, resultados e limitações no Draft PR. Build não equivale a ativação; VMs não comprovam a rede ou o hardware real.
- **Operações:** não faça merge, deploy, reboot, reparticionamento ou rotação de credenciais sem autorização específica. Preserve a recuperação e não interfira em worktrees ou sessões em uso.
- **Documentação:** mantenha este arquivo mínimo. Decisões permanentes ficam preferencialmente no módulo ou teste; investigações, procedimentos temporários e relatórios ficam no PR, não em novos manuais.
