# Credenciais e recuperação

## Provisionar SOPS e SSH do desktop

Antes de instalar, confirme em outro aparelho que consegue recuperar a identidade age sem depender da chave SSH que ela protege. Preserve uma revisão conhecida e seu `secrets/ssh.yaml`. Só esse ciphertext revisado pode entrar em Git e no store. Não rastreie identidades, backups, senhas, chaves, tokens ou estado de serviços. Metadados dos destinatários ficam legíveis e cópias antigas do ciphertext podem sobreviver.

No [instalador autorizado](../README.md#instalar-ou-recuperar-o-desktop), com os volumes já montados, provisione o arquivo regular `/mnt/var/lib/sops-nix/key.txt` como root:root 0600, em diretório root:root 0700. No sistema iniciado, o caminho não tem o prefixo `/mnt`. Confira origem e metadados sem imprimir conteúdo. O preflight recusa arquivo ausente, vazio, symlink ou metadados inseguros. Não gere identidade substituta: uma nova não decifra dados existentes, e a chave do host não é fallback.

Para editar o ciphertext existente, use a identidade autorizada **fora** do checkout. SOPS usa os destinatários do documento:

```sh
SOPS_AGE_KEY_FILE=/CAMINHO_PRIVADO/key.txt sops secrets/ssh.yaml
```

Use editor sem backups ou swap em plaintext. Antes de comitar ou construir, confirme que o documento continua cifrado e que não sobraram temporários. Preserve a passphrase da chave SSH. Para trocar destinatários, mantenha uma identidade que ainda decifra ou uma cópia recuperável do material original; valide a recuperação antes de retirar a antiga. Em caso de exposição, revogue as autorizações da chave nos serviços externos e substitua-a; recifrar não revoga cópias antigas. Uma falha de SOPS também não remove uma chave já carregada do agente: remova-a explicitamente na sessão autorizada.

O desktop não usa LUKS: acesso físico offline pode expor dados e a identidade age instalada. SOPS não substitui criptografia de disco; a chave SSH decifrada ainda tem passphrase. Rollback Nix não recupera identidade perdida. Guarde backup independente da identidade, senhas e revisão correspondente; BitLocker é recuperação separada.

## Primeiro login e bootstrap

1. Após boot, confira `sops-install-secrets.service` e `home-manager-rinyaresu.service` com `systemctl status`, sem publicar logs privados. SOPS falho impede HM, não necessariamente o boot. Corrija origem, destinatário ou metadados e, só no alvo autorizado, reinicie SOPS antes de HM. O segredo fica em `/run/secrets/rinyaresu-ssh-key` (rinyaresu:users 0600), com link `~/.ssh/id_ed25519` e diretório 0700. Se houver arquivo regular conflitante, inspecione e preserve antes de resolver; não sobrescreva.
2. Entre com a senha local, inicie a sessão gráfica e aceite o askpass com a passphrase SSH. Se cancelar, o bootstrap espera sem repetir o prompt nesse processo: carregue a chave com `ssh-add ~/.ssh/id_ed25519` na própria sessão ou reinicie explicitamente o serviço de usuário após corrigir o problema. Confira `ssh-add -l` (em particular numa pane Herdr nova e numa existente). Outra identidade não libera o bootstrap. Bloquear a tela não descarrega a chave; encerrar o agente exige novo desbloqueio. GNOME Keyring usa a senha de sessão e pode pedir desbloqueio separado. Bitwarden não substitui o agente SSH.
3. Com rede e autorização GitHub, confira `journalctl --user -u pi-config-restore` localmente. O bootstrap restaura Home antes de Agent e exige `references/personal.md` em Home. Ele tenta novamente após falha de clone, preserva destinos existentes e não faz pull. Antes de abrir Pi, espere concluir ou revise os destinos existentes (`~/personal/home` e `~/.pi`), inclusive symlinks ou diretórios incompletos. Git não recupera autenticação, sessões ou arquivos ignorados: refaça autorizações externas separadamente.

O build valida o ciphertext, não a descriptografia. VMs e checks usam material descartável e não comprovam askpass visível, cofres reais ou acesso GitHub.

## Provisionar e recuperar Pi-hole

Siga primeiro os [gates de Ordis](../README.md#manter-ordis). Em console ou sessão administrativa autorizada, use `sudo pihole-admin-hash` para provisionar ou rotacionar. Digite e confirme a senha interativamente. Não passe a senha por argumentos ou histórico, nem use tracing. O utilitário substitui atomicamente `/var/lib/pihole-secrets/admin-hash` (hash Balloon-SHA256 v6, root:root 0600, diretório 0700). Confira metadados: o validador de partida checa o formato, não dono/modo. Guarde a senha em recuperação privada independente.

A rotação só entra em uso após reiniciar `pihole-ftl.service` com autorização. Confira FTL e `pihole-ftl-setup.service`; sem hash válido, não contorne a recusa nem tente forçar alteração do gravity. Administre pelo loopback via túnel, por exemplo `ssh -N -L 127.0.0.1:8080:127.0.0.1:8080 <conta>@<ordis>` (substitua os placeholders), e abra `http://127.0.0.1:8080/`. Valide recusa sem autenticação e login com a nova senha. Não abra o painel na rede.

De um cliente LAN autorizado, compare o resultado de um nome permitido e um bloqueado com `dig @ENDERECO_LAN NOME` e `dig +tcp @ENDERECO_LAN NOME`. Confirme recusa a partir de rede/interface não autorizada, inclusive IPv6 como transporte; uma consulta AAAA via IPv4 é diferente. Confira o resolvedor do servidor de forma independente. Consulte [a política do host](../modules/hosts/ordis/pihole.nix) em vez de inferir alcance a partir de uma VM.

Antes de upgrade ou recuperação, pare os serviços com autorização e guarde cópia consistente dos bancos, hash e revisão em armazenamento privado protegido. Não copie SQLite ativo sem mecanismo transacional. Se setup ou swap do gravity falhar, preserve o estado e investigue antes de tentar novamente. Rollback Nix não remove listas persistentes, não reverte hash e pode ser incompatível com banco migrado. Para recuperar, use a revisão e a cópia compatíveis, confirme permissões, reinicie só com autorização e repita as verificações de DNS e autenticação. Não publique logs, histórico DNS ou backups.
