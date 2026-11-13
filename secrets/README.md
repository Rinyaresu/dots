# Usar a chave SSH cifrada

`ssh.yaml` contém a cópia SOPS cifrada da chave SSH atual. A regra em `.sops.yaml`
usa um destinatário age público. Nenhuma chave privada em texto simples pertence
ao repositório ou ao Nix store.

Somente o host `desktop` importa `personal-secrets` e provisiona esse arquivo.
O perfil `lab` não recebe o segredo pessoal.

## Guardar a recuperação no Bitwarden

A identidade age inicial está em
`~/.local/share/sops-nix/bootstrap/key.txt`, fora do Git e do Nix store.
O arquivo tem permissão 0600 e seu diretório tem permissão 0700.

Guarde o conteúdo completo em uma nota segura no Bitwarden. Não cole a identidade
no chat nem a adicione ao Git. Ao copiar, não deixe o conteúdo em histórico de
clipboard. Confira o item em outro aparelho antes de considerar a recuperação
pronta. O assistente não acessa o cofre nem confirma essa cópia por você.

Preserve a identidade local até concluir a migração e verificar a recuperação.
O ciphertext não recupera a chave SSH sem essa identidade. A chave SSH original
em `~/.ssh/id_ed25519` foi preservada, sem alteração da passphrase.

## Preparar o primeiro boot

Recupere a identidade age do Bitwarden no ambiente de instalação. Mantenha o
arquivo fora do repositório. Como root, depois de montar os volumes do novo
NixOS, copie a identidade para o sistema de destino.

```sh
install -d -m 0700 -o root -g root /mnt/var/lib/sops-nix
install -m 0600 -o root -g root /caminho/seguro/key.txt /mnt/var/lib/sops-nix/key.txt
```

Substitua `/caminho/seguro/key.txt` pelo arquivo recuperado. Esses comandos são
para o instalador com o destino montado, não para executar no CachyOS agora.
Não coloque a identidade no flake, em argumentos Nix ou em uma derivação.

No sistema instalado, sops-nix usa `/var/lib/sops-nix/key.txt`. Ele não gera uma
identidade alternativa nem usa chaves SSH como fallback. Sem a identidade, o
provisionamento falha em vez de substituir a chave.

O SSD não usa LUKS. Quem puder ler esse disco offline poderá acessar a identidade
age instalada e decifrar o segredo. SOPS protege o conteúdo no Git e no Nix store,
não criptografa o disco inteiro.

## Usar a chave provisionada

No primeiro boot, sops-nix decifra a chave em runtime. Home Manager cria
`~/.ssh/id_ed25519` como symlink para `/run/secrets/rinyaresu-ssh-key`.
O alvo tem dono `rinyaresu` e permissão 0600. O diretório `~/.ssh` usa 0700.
Um arquivo regular já existente nesse destino não é sobrescrito.

O ssh-agent nativo não carrega a chave automaticamente. Execute `ssh-add` e digite
a passphrase quando solicitada. Não remova a passphrase nem ative agent forwarding
por conveniência.

## Editar o segredo depois da instalação

O host `desktop` inclui o comando `sops`. Com a identidade acessível, execute da
raiz do repositório.

```sh
EDITOR='nvim -n -i NONE -u NONE' \
  SOPS_AGE_KEY_FILE=/caminho/seguro/key.txt sops secrets/ssh.yaml
```

O editor recebe o conteúdo decifrado. Use um editor que não deixe backups ou
arquivos de swap com esse conteúdo. Fora da edição, somente `ssh.yaml` cifrado e
`.sops.yaml` com o destinatário público pertencem ao repositório.
