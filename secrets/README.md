# Provisionar SSH com ciphertext público

Somente o desktop seleciona `nixos.rinyaresu-ssh` e
`homeManager.rinyaresu-ssh`. Lab e Ordis não recebem a chave pessoal.
Avaliação e build não dependem do Home privado, agente pessoal ou credenciais.

## Fronteira de fonte e runtime

| Material | Local | Exposição |
| --- | --- | --- |
| Documento SOPS com campo `ssh_private_key` | `secrets/ssh.yaml` | Público, inclusive destinatários e metadados. Pode entrar no store. |
| Identidade age | `/var/lib/sops-nix/key.txt` | Externa, root:root 0600, diretório root:root 0700. Nunca Git ou store. |
| Chave SSH com sua passphrase preservada | `/run/secrets/rinyaresu-ssh-key` | Runtime, rinyaresu:users 0600. Nunca entrada de build. |
| Link da home | `~/.ssh/id_ed25519` | Home Manager cria indireção para o segredo runtime, não uma cópia da chave no store. |

O exportador aceita somente o caminho SOPS listado acima. Essa exceção não permite
outros YAML, backups, plaintext ou identidades privadas na fonte.

`sops.validateSopsFiles = true` valida o documento cifrado no build, sem usar a
identidade age. Isso não prova recuperação ou descriptografia. A identidade não
é gerada automaticamente e chaves SSH do host não são fallback.

O preflight recusa identidade ausente, vazia, symlink, dono ou grupo diferente
de root, ou modo diferente de 0600. SOPS real recusa identidade incapaz de decifrar.
Home Manager depende de sucesso da unidade SOPS. Um arquivo regular já existente
em `~/.ssh/id_ed25519` não é substituído silenciosamente. `~/.ssh` fica em 0700.

Ciphertext é diferente de plaintext, mas sua publicação é permanente. Metadados
permitem correlação e cópias antigas podem sobreviver a mudanças de destinatários.
Aprovar uma versão não aprova outras versões ou inventário histórico.

## Preparar uma instalação autorizada

Recupere a identidade age por canal independente da chave SSH que será restaurada.
O ciphertext já acompanha a revisão pública. Não é necessário clonar Home ou
Agent por SSH para obter o material que recupera essa mesma chave.

Confirme a recuperação em outro aparelho antes de substituir qualquer sistema.
Depois dos volumes autorizados montados, provisione a identidade em
`/mnt/var/lib/sops-nix/key.txt`, preservando os donos e modos descritos acima.
Confira metadados e origem sem imprimir o conteúdo. Não copie uma identidade
pessoal para teste. Siga [o guia de instalação](../docs/instalacao.md).

O instalador executa ativação no chroot. Este perfil, porém, descriptografa por
serviço systemd no sistema iniciado. Não trate `nixos-install` como prova de SOPS.
No primeiro boot, confira as unidades `sops-install-secrets.service` e
`home-manager-rinyaresu.service`. Se SOPS falhar, corrija a origem e metadados da
identidade sem gerar outra como substituta. Depois, reinicie SOPS e HM no target
somente com autorização operacional. O contrato completo está em
[bootstrap](../docs/bootstrap.md).

A chave mantém sua passphrase. GNOME Keyring, agente SSH e Bitwarden têm
responsabilidades distintas. O agente OpenSSH pede a passphrase e reutiliza a
identidade carregada. Bitwarden é recuperação, não agente SSH.

## Editar o ciphertext

Use uma cópia revisada da fonte e uma identidade autorizada fora do checkout.
Para editar o documento existente, SOPS usa os destinatários nos seus metadados.
Não é necessário um input privado de flake ou uma regra `.sops.yaml` pública.

O caminho abaixo é um placeholder, não material de recuperação.

```sh
SOPS_AGE_KEY_FILE=/CAMINHO_PRIVADO/key.txt sops secrets/ssh.yaml
```

Use editor sem backups ou swap de plaintext. Confira que o resultado continua
cifrado e que não há arquivos temporários privados no checkout antes de exportar,
comitar ou construir. Nunca passe a identidade ou chave privada como opção Nix.
Revisar e construir a mudança não autoriza publicação ou ativação.

Trocar destinatários exige uma identidade ainda capaz de decifrar, ou uma cópia
recuperável do material original. Gerar uma identidade nova não recupera dados
cifrados para uma identidade perdida. Preserve recuperação independente antes
de trocar destinatários ou chaves. Cópias antigas não são revogadas por Git.

## Recuperação e proteção instalada

Mantenha backup independente da identidade age, das senhas e de uma revisão
conhecida com seu ciphertext. Perder a identidade não é resolvido por rollback Nix.
A recuperação BitLocker é um requisito físico separado, não entrada do SOPS.

O desktop não usa LUKS. Alguém com leitura física offline pode obter a identidade
age instalada e decifrar o documento. SOPS não substitui criptografia de disco.
A passphrase SSH continua protegendo a chave decifrada, mas não torna a identidade
age pública. Gerações e snapshots locais não substituem recuperação fora do disco.

Uma falha posterior de SOPS não revoga automaticamente uma chave já carregada no
agente. Remoção da identidade no agente e revogação em serviços externos são
operações próprias, não efeitos prometidos por este provisionamento.
