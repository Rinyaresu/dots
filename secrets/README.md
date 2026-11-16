# Provisionar a chave SSH fora da fonte pública

Somente o desktop seleciona `nixos.rinyaresu-ssh` e
`homeManager.rinyaresu-ssh`. Lab e Ordis não recebem a chave pessoal.
A avaliação e o build usam apenas caminhos de runtime, sem ler arquivos privados.

## Contrato de ativação

O módulo SOPS usa estes arquivos externos.

| Caminho instalado | Conteúdo | Dono e modo |
| --- | --- | --- |
| `/var/lib/sops-nix/key.txt` | Identidade age recuperada pelo operador | root:root, 0600 |
| `/var/lib/sops-nix/ssh.yaml` | Documento SOPS com campo `ssh_private_key` | root:root, 0600 |

O diretório é root:root, 0700. O preflight recusa arquivos ausentes, vazios,
symlinks ou permissões diferentes. Não há identidade gerada como fallback.
`sops.validateSopsFiles = false` evita copiar o ciphertext ao store durante a
avaliação. O manifest ainda é validado no build. A validação e a decifragem do
documento externo ocorrem na ativação pelo `sops-install-secrets` real.
Esse limite não transforma um build aprovado em prova de recuperação da chave.

O ciphertext e a regra privada de edição ficam em armazenamento privado separado.
Não os copie para este checkout, para logs ou para argumentos de comandos Nix.
A identidade age nunca pertence ao Git, mesmo em repositório privado.

## Preparar uma instalação autorizada

Antes de substituir qualquer sistema, confirme em outro aparelho a recuperação
da identidade age e do ciphertext correto. No instalador, depois de montar o
sistema de destino, provisione os dois arquivos nos caminhos acima sob `/mnt`.
Use arquivos de origem privados e confira os donos e permissões sem imprimir seu
conteúdo. A instalação também exige senha da conta e material de recuperação do
outro sistema operacional. Siga [o guia de instalação](../docs/instalacao.md).

O Home Manager depende da unidade SOPS. A chave decifrada aparece em
`/run/secrets/rinyaresu-ssh-key`, com dono `rinyaresu` e modo 0600.
`~/.ssh/id_ed25519` é um symlink para esse arquivo. Um arquivo regular existente
não é substituído silenciosamente. `~/.ssh` permanece com modo 0700.

A chave mantém sua passphrase. GNOME Keyring, agente SSH e Bitwarden têm
responsabilidades distintas. O agente SSH pede a passphrase graficamente e
reutiliza a chave carregada. Bitwarden é recuperação, não um agente SSH.

## Editar e recuperar

Edite o ciphertext somente na cópia privada, usando SOPS e a regra correspondente.
Use um editor sem backups ou swap com conteúdo decifrado. Para atualizar o arquivo
runtime, confira a origem e preserve o ciphertext anterior antes de substituí-lo.
Aplique mudanças somente com autorização operacional.

Sem criptografia do SSD, alguém com leitura física offline pode obter a
identidade age instalada e decifrar o documento. SOPS protege a cópia cifrada,
não o disco instalado. Gerações Nix e snapshots locais não substituem a recuperação
externa da identidade.
