# Usar o cliente Tailscale fixado

Desktop e Ordis selecionam `nixos.tailscale`. Lab não o seleciona.
O módulo fornece transporte privado, não SSH Tailscale. OpenSSH e as políticas
de firewall pertencem a cada host. Não transfira a exceção LAN do servidor ao desktop.

## Contrato do daemon

O pacote fixado aceita configuração `alpha0` aplicada antes de conectar.
`acceptDNS` e `acceptRoutes` são falsos. Não há exit node, rotas anunciadas,
Taildrop, SSH Tailscale, cliente web, configuração remota ou atualização automática.
`NetfilterMode=off` impede que o daemon aceite portas antes do firewall NixOS.
Não torne `tailscale0` uma interface confiável para todas as portas.

A política fica bloqueada contra drift por `tailscale set`. O módulo não usa
`authKeyFile` ou credenciais no store. A identidade persiste no StateDirectory
nativo. Não copie esse estado entre máquinas ou para Git, logs e relatórios.
O desktop novo deve registrar uma identidade nova.

## Autorizar um dispositivo

Use uma conta e tailnet autorizadas, com MFA. A configuração bloqueada do pin
exige iniciar o login no backend existente, sem trocar perfis.

```sh
sudo tailscale debug localapi POST login-interactive >/dev/null
```

Abra o link de autorização somente em terminal ou navegador privado. Se precisar
consultá-lo, filtre apenas `AuthURL` e não grave a saída em logs. O daemon também
pode incluir a URL no status ou journal durante esse fluxo. Não publique essas saídas.

Não use `tailscale login`, `tailscale up` ou `--reset` nesse cliente bloqueado sem
revalidar sua interação com a versão fixada. O fluxo errado pode trocar o perfil
antes de falhar. A LocalAPI de debug é instável e precisa de teste ao atualizar.
Os checks offline provam aceitação do pedido e preservação das preferências,
não login no control plane.

Confira preferências filtradas sem imprimir o estado privado completo.

```sh
sudo tailscale debug prefs | jq '{CorpDNS,RouteAll,RunSSH,RunWebClient,NetfilterMode,AdvertiseRoutes,ExitNodeID,ExitNodeIP}'
```

Os quatro booleanos são falsos, `NetfilterMode=0`, sem rotas ou exit node.
O DNS do host continua administrado pela rede. Apelidos SSH com IPs reais da
tailnet não dependem de aceitar DNS Tailscale no desktop.

## Validar acesso real

Grants da tailnet e chave OpenSSH são controles independentes. Regras de grants
são aditivas. Acrescentar uma regra estreita não revoga um allow amplo existente.
Revise a política completa e teste dispositivos permitidos e não permitidos.
Não altere a política de outros serviços por copiar um exemplo deste projeto.

Confira a chave de host por canal confiável antes de usar um endereço novo.
Não desabilite StrictHostKeyChecking ou copie chave privada para facilitar acesso.
Teste uma conexão SSH nova por uma rede externa, além da LAN doméstica.
`tailscale ping` ou uma sessão SSH antiga não comprovam autenticação nova.

Os checks usam namespaces e interfaces sintéticas para verificar firewall,
preferências e preservação do resolver. Eles não provam grants reais, identidade
do notebook, login, caminho externo, DNS da tailnet ou persistência após boot físico.
Siga [o contrato de cada host](ordis.md) antes de aplicar mudanças operacionais.
