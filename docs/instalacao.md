# Preparar uma instalação do desktop

Este guia descreve o contrato do perfil `desktop`. Ele não particiona discos ou
autoriza instalação. Não o execute a partir do sistema em uso que será substituído.
Inventário pessoal, seriais, recuperação e evidências de ensaio ficam fora deste
repositório público.

## Resolver os bloqueios

1. Revise a configuração, os checks e os builds dos três hosts na revisão pretendida.
2. Ensaie a instalação em VM descartável. Iniciar o lab existente não substitui
   ensaiar os volumes e o perfil desktop.
3. Comprove que o firmware aceita a mídia e o boot Linux com a política Secure Boot
   existente. A configuração Limine não assina o executável nem altera essa política.
   Se houver recusa, pare antes de mudar firmware ou chaves.
4. Confira a recuperação age, ciphertext SOPS e BitLocker em outro aparelho.
5. Reidentifique os discos por modelo, serial e partições no instalador.
   Preserve integralmente o disco do Windows e sua EFI.
6. Prepare rede, teclado de recuperação, console e acesso administrativo.
   A exceção LAN limitada ao notebook depende de identificação estável e continua
   pendente. Não abra SSH para toda a LAN para contornar esse requisito.
7. Obtenha autorização específica para substituir o Linux no disco escolhido.

Não há backup externo geral do desktop nesta configuração. Snapshots da home
ficam no mesmo Btrfs e não sobrevivem à perda do disco. Não interprete essa escolha
como autorização para descartar arquivos, bancos ou serviços do sistema em uso.

## Preparar os volumes autorizados

O perfil espera uma EFI Linux separada em VFAT, com rótulo `NIXOS_BOOT`, e um
filesystem Btrfs com rótulo `NIXOS`. Os nomes de dispositivo podem mudar.
O layout não usa LUKS nem swap no SSD.

| Subvolume | Destino no instalador | Destino instalado |
| --- | --- | --- |
| `@` | `/mnt` | `/` |
| `@home` | `/mnt/home` | `/home` |
| `@nix` | `/mnt/nix` | `/nix` |

Monte a EFI Linux em `/mnt/boot`. Os três subvolumes usam compressão zstd e
compartilham o espaço livre. Este guia não contém comandos de formatação.
Não monte os volumes Windows para preparar o Linux.

A entrada Windows do Limine usa um GUID de EFI específico do host. Confira-o
no instalador antes de depender da entrada. O menu do firmware é um caminho
independente de recuperação.

## Construir e instalar

Disponibilize o checkout revisado no destino. Um clone público HTTPS não exige a
chave SSH que ainda será provisionada. Confira a revisão e use uma exportação
explícita antes de construir.

```sh
source=$(python3 -B scripts/export-source.py)
nix --extra-experimental-features 'nix-command flakes' build --no-link --no-write-lock-file \
  "path:$source#nixosConfigurations.desktop.config.system.build.toplevel"
```

Provisione a identidade age e o ciphertext em `/mnt/var/lib/sops-nix/`, conforme
[o contrato SOPS](../secrets/README.md). Esses arquivos ficam fora da fonte.
Provisione também as chaves públicas verificadas dos clientes SSH no arquivo
runtime descrito em [serviços](servicos.md). A ausência delas recusa login remoto.

Somente no instalador autorizado, depois desses bloqueios resolvidos e volumes
montados, instale o perfil da fonte exportada e defina a senha da conta.

```sh
nixos-install --option experimental-features 'nix-command flakes' \
  --flake "path:$source#desktop"
nixos-enter --root /mnt -c 'passwd rinyaresu'
```

Nenhuma senha de produção pertence ao flake. A senha pública do lab nunca deve
ser usada no desktop. Não ative o perfil lab no disco físico.

## Validar o primeiro início

Entre no console. Inicie `niri-session`. Use `startx` como alternativa i3 somente
depois de encerrar a outra sessão. Confira rede e SSH por conexão nova, cadastro
Tailscale como dispositivo novo, socket SSH compartilhado e bootstrap Home e Agent.
Não abra Pi antes de o bootstrap concluir ou de revisar os destinos já existentes.

Valide monitores, escalas, teclado no console e nas duas sessões, áudio, USB e KVM,
Bluetooth, bloqueio e retomada. Confira capturas salvas e coladas. Valide Discord,
OBS e Meet separadamente com imagem e áudio recebidos ou gravados.
Confirme Windows pelo Limine e pelo menu do firmware.

Não habilite a manutenção automática antes de conferir rollback e continuidade
dos agentes. As opções preparadas são semanais, com gerações acima de 30 dias.
O opt-in exige alterar explicitamente `nix.gc.automatic` na configuração revisada.

## Recuperar sem destruir dados

Preserve uma geração funcional e a fonte correspondente. O instalador Limine
fixado escolhe a geração de maior número. Mudar apenas o symlink com
`nix-env --rollback` não garante a entrada escolhida no próximo boot.
Prefira restaurar a fonte e o lock conhecidos e construir uma nova geração.
Uma entrada antiga do menu também pode ajudar enquanto seus arquivos existirem.

Rollback de sistema não restaura arquivos pessoais ou snapshots. Não apague
gerações nem execute garbage collection durante recuperação.
