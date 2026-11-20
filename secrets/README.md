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

A rotação só entra em uso após reiniciar `pihole-ftl.service` com autorização. Confira FTL e `pihole-ftl-setup.service`; sem hash válido, não contorne a recusa nem tente forçar alteração do gravity. Administre pelo loopback via túnel, por exemplo `ssh -N -L 127.0.0.1:8080:127.0.0.1:8080 <conta>@<ordis>` (substitua os placeholders), e abra `http://127.0.0.1:8080/`. Valide recusa sem autenticação e login com a nova senha. Não habilite acesso direto ao painel fora da ACL declarada para Ordis.

De um cliente LAN autorizado, compare o resultado de um nome permitido e um bloqueado com `dig @ENDERECO_LAN NOME` e `dig +tcp @ENDERECO_LAN NOME`. Confirme recusa a partir de rede/interface não autorizada, inclusive IPv6 como transporte; uma consulta AAAA via IPv4 é diferente. Confira o resolvedor do servidor de forma independente. Consulte [a política do host](../modules/hosts/ordis/pihole.nix) em vez de inferir alcance a partir de uma VM.

### HTTPS privado de Ordis

O painel atual usa `https://pihole.rinyaresu.dev/admin/`. O Pi-hole resolve o
nome para o IPv4 LAN; não publique A/AAAA na Cloudflare. O nome do certificado
público pode aparecer nos logs públicos de Certificate Transparency.

Crie um token Cloudflare com **Zone / DNS / Edit** e **Zone / Zone / Read**
restritas à zona `rinyaresu.dev`. Provisione só o valor em
`/var/lib/pihole-secrets/cloudflare-dns-token` (`root:root`, `0600`) usando
entrada interativa sem eco; não use argumentos, variáveis de ambiente do
shell, OAuth do MCP, Git ou Nix store. O systemd entrega o arquivo ao lego
como credencial. Em rotação, troque o arquivo atomicamente e só revogue o
token antigo após verificar o novo.

Verifique `acme-order-renew-pihole.rinyaresu.dev.timer`, o resultado da
unidade `.service` de mesmo nome e `pihole-publish-tls.service`. Para tentar
novamente após corrigir uma falha, inicie a unidade de renovação; se só a
publicação falhou, inicie apenas `pihole-publish-tls.service`. Nunca remova
`/var/lib/pihole-tls/server.pem` para forçar emissão: o último PEM válido
continua em uso se a renovação falhar. Se ele expirar, use o túnel SSH para
`127.0.0.1:8080`; não ignore alertas TLS. Preserve o material legado para
rollback à geração 9 até encerrar a migração.

#### CA privada legada (somente rollback à geração 9)

No CachyOS, fora de Git e do Nix store, crie uma CA dedicada ao painel.
Use um diretório privado em tmpfs e `umask 077`. O OpenSSL pede a
passphrase no terminal; não passe por argumentos, ambiente ou histórico:

```sh
openssl req -new -x509 -newkey rsa:3072 -sha256 -days 1825 \
  -keyout ca.key -out ca.crt -subj '/CN=Ordis Pi-hole CA' \
  -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign'
```

No Bitwarden pessoal, crie uma nota segura dedicada à CA do Pi-hole:
anexe o PEM **ENCRYPTED PRIVATE KEY** se o cofre oferecer anexos; caso
contrário, guarde o PEM cifrado na nota, sem retirar a passphrase. Guarde
também o certificado público e sua impressão digital SHA-256. Se guardar a
passphrase no Bitwarden, use uma nota distinta. Duas notas no mesmo cofre
não são backup nem oferecem separação contra comprometimento do cofre.

Recupere o PEM do cofre em tmpfs, valide que abre com a passphrase e confira
que a chave pública coincide com a do certificado. Remova a cópia de
trabalho quando terminar; nunca copie a chave da CA para Ordis, Git, Nix
store, logs ou perfil do navegador. O Bitwarden é a única cópia durável
registrada para Ordis; não há backup independente confirmado. Se perder
acesso ao cofre, à chave ou à passphrase, gere nova CA e leaf, substitua a
confiança no Firefox e remova a CA antiga. Se houver suspeita de exposição,
remova a confiança antiga imediatamente.

No Ordis, na sessão administrativa interativa, use um diretório de preparação
root:root 0700 em `/var/lib/pihole-secrets`. Com `umask 077`, gere uma chave
RSA 3072 e CSR com `openssl req -new -newkey rsa:3072 -noenc -keyout leaf.key
-out leaf.csr -subj /CN=pihole.home.arpa`. Envie **só o CSR** para assinar.
No CachyOS, recupere a chave cifrada apenas para assinar e escreva um
arquivo de extensões no diretório privado em tmpfs:

```ini
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:pihole.home.arpa
```

Assine com `openssl x509 -req -in leaf.csr -CA ca.crt -CAkey ca.key
-set_serial "0x$(openssl rand -hex 16)" -days 90 -sha256 -extfile leaf.ext
-out leaf.crt`. Devolva **só** `leaf.crt` e `ca.crt`. Antes de instalar,
confira a impressão digital da CA, SAN, prazo, chave correspondente e
`openssl verify -purpose sslserver -verify_hostname pihole.home.arpa
-CAfile ca.crt leaf.crt`. Instale a CA como
`/var/lib/pihole/ordis-ca.crt` e o PEM concatenado **certificado, depois
chave** como `/var/lib/pihole/ordis-tls.pem`, ambos root:pihole 0640. Use
temporários no próprio diretório de destino e rename; não sobrescreva o
PEM ativo in-place e não deixe cópias soltas da chave.

No CachyOS, importe **apenas o certificado público da CA**, depois de comparar
a impressão digital, nas Autoridades do perfil Firefox escolhido para
administrar Ordis (confiança para identificar sites). Não instale globalmente
nem no navegador corporativo. Teste com `curl --cacert ca.crt
https://pihole.home.arpa:8443/admin/` e no próprio perfil, sem exceção TLS,
usando o resolvedor real do desktop. Se um navegador usar DNS seguro externo
para o nome local, mantenha o resolvedor do sistema nesse perfil. Faça login
pelo navegador, sem capturar a senha, o histórico DNS ou cookies. Sem CA no
perfil ou a partir de cliente não autorizado, teste a recusa separadamente.

Após cada emissão, registre um lembrete no calendário para 30 dias antes
do vencimento (`openssl x509 -enddate -noout -in leaf.crt`). Não há renovação
automática. Na data do lembrete, emita nova leaf com chave nova;
preserve o PEM anterior em armazenamento privado até validar; substitua
atomicamente e reinicie **apenas** o FTL numa janela autorizada. Repita
SSH/túnel, resolução e bloqueio, handshake e login real e confirme o
serial/validade novos. Se a validação falhar, restaure o PEM anterior
atomicamente e reinicie o FTL; o túnel é o caminho de recuperação. Na troca
de CA, instale a nova confiança no cliente antes de servir a nova leaf e
remova a antiga após validar; se houver comprometimento, remova imediatamente
a confiança antiga e emita CA e leaf novas. Não use exceções de certificado.

Antes de upgrade ou recuperação, pare os serviços com autorização e guarde cópia consistente dos bancos, hash e revisão em armazenamento privado protegido. Não copie SQLite ativo sem mecanismo transacional. Se setup ou swap do gravity falhar, preserve o estado e investigue antes de tentar novamente. Rollback Nix não remove listas persistentes, não reverte hash e pode ser incompatível com banco migrado. Para recuperar, use a revisão e a cópia compatíveis, confirme permissões, reinicie só com autorização e repita as verificações de DNS e autenticação. Não publique logs, histórico DNS ou backups.

Para voltar **apenas** o Gravity, depois de confirmar que o banco ativo está
inválido ou que a lista nova está errada, pare o timer e aguarde o setup
terminar; confirme que não há atualização manual. Mantenha cópia privada do
estado, inclusive de possíveis journals. Pare o FTL. Verifique
`PRAGMA quick_check` em `/var/lib/pihole/gravity_old.db` e confirme que é
compatível e tem os domínios esperados. Não apague ou sobreponha arquivos se
houver journals não resolvidos. Copie o backup para temporário **no diretório
do banco**, com dono e modo corretos. Sincronize o arquivo, publique com
rename sobre `gravity.db` e sincronize o diretório. Preserve o arquivo
`gravity_old.db`. Suba o FTL e confira DNS e bloqueio antes de reativar o
timer. Se só o reload foi interrompido, um restart do FTL deve carregar o
banco já publicado; não restaure o banco sem necessidade.
