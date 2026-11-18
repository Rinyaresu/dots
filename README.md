# NixOS

- `desktop`: estação física com Home Manager; sessão Niri e recuperação via i3.
- `lab`: VM descartável sem rede nem compartilhamento com o host. A senha pública do lab é só para essa VM; não instale esse perfil em disco físico.
- `ordis`: servidor sem Home Manager. [O procedimento do servidor](#manter-ordis) é independente da instalação desktop.

## Verificar sem ativar

Use Linux x86_64 com Nix, Git e flakes habilitados. Revise o que está rastreado: a fonte Git, incluindo Markdown, pode entrar no store. Para registrar evidência, use checkout limpo e anote o SHA. Build não exige Home, Agent, identidade age ou login na tailnet.

```sh
nix fmt -- --check flake.nix
nix flake check --show-trace --no-write-lock-file
for host in desktop lab ordis; do
  nix build --no-link ".#nixosConfigurations.$host.config.system.build.toplevel" || exit
done
```

Troque `flake.nix` pelos arquivos Nix alterados para formatá-los e retire `--check` para aplicar. Para comportamento afetado, escolha um dos sete packages críticos e execute individualmente com KVM:

```sh
# desktop-access desktop-snapshots tailscale pihole secret-runtime bootstrap-runtime ssh-session
test_name=desktop-access
nix build --no-link --rebuild -L ".#packages.x86_64-linux.$test_name"
```

Se a derivação ainda não foi realizada, tente sem `--rebuild` e confira que a VM realmente executou; substituição por cache não conta. A CI verifica o merge sintético de PRs para `master` e constrói a matriz de hosts, sem rodar essas VMs. Avaliação verifica opções; build não ativa nada; VM usa credenciais e rede descartáveis. Nenhuma dessas provas comprova discos, firmware, GPU, login GitHub, grants da tailnet ou serviços no host físico.

## Instalar ou recuperar o desktop

1. Antes de tocar nos discos, obtenha autorização para o alvo, ensaie o **perfil desktop** em VM descartável (o lab não substitui esse ensaio) e valide a revisão. Guarde backup dos dados a preservar fora do disco; confirme em outro aparelho acesso à identidade age, à revisão com ciphertext e à recuperação BitLocker. Separe mídia de recuperação, teclado, console e rede.
2. No instalador, use `lsblk -o NAME,MODEL,SERIAL,SIZE,FSTYPE,LABEL,PARTUUID,MOUNTPOINTS` para reidentificar o disco Linux, o disco Windows e suas EFIs. Não confie no nome do dispositivo nem em rótulo duplicado. Preserve o disco e a EFI do Windows; não os monte para preparar o Linux. Compare a EFI Windows com o GUID da [entrada Limine](modules/hosts/desktop/configuration.nix). Valide a mídia e o boot com a política Secure Boot existente; o Limine deste perfil não é assinado. Pare se o firmware recusar, sem mudar a política ou as chaves por tentativa.
3. Somente nos volumes Linux autorizados, prepare e monte o Btrfs em `/mnt`, os subvolumes de home/store e a EFI Linux separada em `/mnt/boot`. [O módulo de hardware](modules/hosts/desktop/_hardware-configuration.nix) é a referência para rótulos, subvolumes e destinos. Confira com `findmnt -R /mnt` antes de prosseguir. Não há comando de formatação neste guia.
4. Obtenha o checkout Git revisado por canal autorizado que não dependa da chave SSH a restaurar. Na raiz desse checkout no instalador, confirme o SHA, avalie e construa o toplevel `desktop` como acima. Provisione a [identidade age no alvo](secrets/README.md#provisionar-sops-e-ssh-do-desktop) e as [chaves públicas de entrada](#autorizar-acesso-via-tailscale) se precisar de acesso remoto.
5. Só no instalador autorizado, com o alvo conferido, instale e defina a senha da conta local:

   ```sh
   nixos-install --option experimental-features 'nix-command flakes' --flake .#desktop
   nixos-enter --root /mnt -c 'passwd rinyaresu'
   ```

   Confira erros de ativação no chroot: `nixos-enter` pode tolerá-los. Instalação do perfil e do bootloader não prova SOPS ou Home Manager; valide no primeiro boot.

No console, faça login e confira [SOPS, Home Manager e bootstrap](secrets/README.md#primeiro-login-e-bootstrap). Inicie `niri-session`; para recuperar pela sessão i3, encerre a outra sessão e use `startx`. Valide no hardware rede e SSH novo, monitores/escalas, teclado, áudio, USB/KVM, Bluetooth, bloqueio e retomada. Confira captura salva e colada e teste imagem e áudio recebidos/gravados em Discord, OBS e Meet separadamente; o seletor do portal não prova entrega. Confirme Windows tanto pelo Limine quanto pelo menu do firmware. Evite copiar segredos: o histórico do CopyQ não é cifrado e bloquear a sessão não o limpa.

Em falha de boot, use uma entrada funcional do Limine enquanto seus arquivos existirem ou mídia de recuperação. Preserve a geração funcional e sua fonte com lock. O Limine fixado escolhe a geração de maior número: mudar só o symlink com `nix-env --rollback` não garante o próximo boot. Prefira construir uma nova geração da fonte e lock conhecidos para aplicação autorizada. Snapshots de home não recuperam raiz nem perda do SSD. Para recuperar um arquivo, liste com `sudo snapper -c home list`, copie de `/home/.snapshots/NUMERO/snapshot/CAMINHO_RELATIVO` para um destino de revisão e confira conteúdo, dono e modo antes de substituir. Não faça GC durante recuperação; a manutenção é manual. Não mude versões de estado como parte de um upgrade comum.

No desktop, o [Docker](modules/system/interfaces/cli/docker.nix) publica portas em `127.0.0.1` por padrão na bridge padrão e em novas bridges. Revise endereços explícitos, redes existentes, IPv6 e modo host: podem expor serviços além do loopback. Não conte com o firewall do NixOS para isolar portas publicadas pelo Docker.

## Manter Ordis

Antes de qualquer operação autorizada, compare rede, SSH, firewall, armazenamento e boot efetivos com a revisão funcional. Preserve a geração, checkout completo e lock, e cópias consistentes do estado persistente antes de mudanças que possam migrar formatos. Use um checkout limpo: sobrepor uma árvore antiga pode deixar módulos obsoletos na descoberta. Confirme uma **nova** conexão SSH e sudo e prepare console/mídia e rollback que não dependam do caminho de rede que vai mudar.

Uma aplicação temporária autorizada precede a persistência. Confirme conexão nova, sudo, [DNS/Pi-hole](secrets/README.md#provisionar-e-recuperar-pi-hole), serviços e mounts. Reboot exige autorização separada e caminho de recuperação preparado. Se falhar, use console e entrada funcional do systemd-boot ou mídia de recuperação; confira a política de acesso da geração de retorno. Não formate, reinstale, apague estado, gerações ou faça GC para recuperar uma falha de configuração. Rollback de Nix não reverte bancos migrados.

## Autorizar acesso via Tailscale

No desktop, por console autorizado, instale somente chaves **públicas** verificadas dos clientes em `/var/lib/desktop-ssh/authorized_keys/rinyaresu` (root:root 0644; diretório root:root 0755). A home não autoriza SSH de entrada. Preserve as chaves privadas nos clientes. Não abra SSH na LAN como substituto do console; a exceção LAN de [Ordis](modules/hosts/ordis/configuration.nix) não vale para o desktop.

Cadastre uma instalação nova como dispositivo novo em conta/tailnet autorizada com MFA. Não copie estado antigo. No [cliente fixado](modules/system/networking/tailscale.nix), inicie o fluxo no backend existente:

```sh
sudo tailscale debug localapi POST login-interactive >/dev/null
sudo tailscale debug prefs | jq '{CorpDNS,RouteAll,RunSSH,RunWebClient,NetfilterMode,AdvertiseRoutes,ExitNodeID,ExitNodeIP}'
```

Consulte apenas a URL de autorização em terminal privado e abra-a no navegador; status e journal podem contê-la, não os publique. Não use `tailscale login`, `up` ou `--reset` nesse cliente bloqueado sem revalidar o pin: podem trocar perfil antes de falhar. A LocalAPI de debug pode mudar. Compare a saída filtrada com a política do módulo; o DNS segue na rede local.

Revise a política completa de grants: regras são aditivas e um grant estreito não cancela permissões amplas. SSH de entrada requer tanto grant quanto chave OpenSSH. Confira a chave de host por canal confiável, depois teste uma conexão nova de rede externa com cliente permitido e confirme recusa para não permitido. Ping ou sessão SSH antiga não valem como prova.

## TreeView do Herdr

O [layout do desktop](modules/system/interfaces/cli/herdr.nix) é gerado por Home Manager. Não aplique dotfiles de Dev por cima do HM; clientes externos precisam só do layout local para exibir a view remota, sem outro subscriber. Isso não instala plugin nem pacote Pi. Não altere Ordis ou lab para habilitar TreeView.

1. A combinação validada usa Herdr 0.9.5 (protocolo 22). Confirme `hostname`, `id -un`, `herdr --version`, `herdr status server --json` e `herdr plugin list --json` **no servidor que executa Pi**, verificando o socket real. Não substitua outra view de Agents: confirme ausência de projetor ou o único `plugin:agent-tree` com label `tree`. Se não puder comprovar propriedade, pare. Guarde fora do Git cópias conferidas das configs anterior e planejada e registre estágio, socket, raiz, binário e state dir do plugin. Não exporte sessões nem catálogo privado.
   Para conferir a propriedade quando necessário, o RPC local `agent.view.clear` com `params.source="plugin:agent-tree-probe"` no socket conferido retorna a view sem limpar a de outro source no Herdr 0.9.5. É escrita condicional, não getter: não use o source real para sondar. Confira antes que o source de probe não é proprietário.
2. Antes de substituir o checkout ativo, reconcilie as alterações locais de áudio, workspace separado por filho e exclusão de `ask_user_question` nos filhos: o pin versionado de `pi-subagent` não garante que elas estejam presentes. Backup sozinho não preserva o comportamento. Em uma instalação autorizada, confira que o checkout gerenciado do pacote Pi está limpo e que nenhuma funcionalidade local será perdida. Instale o publisher pelo Pi e o subscriber pelo Herdr nos pins abaixo; primeiro confirme que as revisões estão acessíveis às contas autorizadas. Se um pin não estiver disponível, pare em vez de trocar para `main` ou `latest`. Não duplique a entrada de pacote, não copie o settings inteiro e só use `/reload` do Pi quando ocioso. Herdr compila o plugin com Cargo bloqueado; prepare a toolchain na máquina de execução. Se a revisão já estiver ativa com um único subscriber e view correta, não reinstale.

   ```sh
   pi install git:github.com/Rinyaresu/pi-subagent@71c959a995b6d23f2bb37f298931af475414ba86
   herdr plugin install Algorant/herdr-agent-tree --ref c14c3ee4fa9fa709b4e6e984fc53f47cd9bc2a28 --yes
   ```

3. Valide o ref resolvido e o HEAD da fonte gerenciada. Deixe o plugin desabilitado até validar a configuração. Execute `herdr config check`, `herdr server reload-config`, `herdr plugin enable agent-tree` e `herdr plugin action invoke agent-tree.reload`, nessa ordem. Acompanhe o mesmo `log_id` em `herdr plugin log list --plugin agent-tree` até `succeeded`; resposta inicial não é conclusão. Confirme view `tree`, um único subscriber e foco/navegação no cliente real, sem criar agentes só para testar.
4. Se o plugin não chegou a ser instalado, restaure só as alterações de configuração reconhecidas, sem invocar actions. Se instalado mas não ativado, confirme ausência de subscriber e mantenha-o desabilitado. Para reverter uma ativação ou trocar pin, desabilite hooks e aguarde actions. **Disable não para subscriber.** Confira presença/ausência por executável e argv **e** ambiente do plugin no UID/namespace certos, com socket, raiz e state dir registrados. Não confie em nome, PID ou lock isolado. Se existir, confira start time e identidade novamente após abrir pidfd, sinalize somente por esse pidfd e confirme saída. Se não puder provar a identidade, ler `/proc` ou fechar as actions, pare e deixe a recuperação pendente.
5. Só após provar ausência em dois inventários, execute `clear` síncrono pelo launcher original usando o contexto conferido:

   ```sh
   HERDR_PLUGIN_ID=agent-tree HERDR_PLUGIN_ROOT="$plugin_root" \
     HERDR_PLUGIN_STATE_DIR="$state_dir" HERDR_SOCKET_PATH="$socket" \
     "$plugin_root/src/agent-tree" clear
   ```

   Preserve aliases do publisher e tokens alheios. Restaure apenas configs ainda iguais à cópia planejada ou anterior; em HM, reverta na fonte/geração autorizada, não no symlink do store. Valide e recarregue a config, confira view nativa e ausência de republicação antes de desinstalar. Reverter o publisher é separado: deixe os aliases expirarem após reload de Pi ocioso ou encerramento natural, preservando `pi_*`.

Para ambiente de projeto, revise a config antes de `mise trust` ou `mise install` e a `.envrc` antes de `direnv allow` (executa código). Use `HERDR_NO_AUTO=1 fish` para abrir shell sem autoattach. Não encerre um servidor Herdr ocupado para renovar ambiente.
