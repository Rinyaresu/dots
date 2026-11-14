# Composição dendritic multi-host

`flake.nix` carrega flake-parts, seu namespace de módulos e `import-tree ./modules`.
Todo arquivo Nix dessa árvore é um módulo flake-parts. Descobrir um arquivo publica
suas definições. Isso não instala programas nem seleciona suas funcionalidades.

O arquivo externo entra na avaliação flake-parts pelo caminho. As contribuições
publicadas são valores consumidos em outras avaliações NixOS e Home Manager.
A deduplicação automática do arquivo externo não se transfere a esses valores.

## Saídas e raízes de hosts

Cada `modules/hosts/<host>/modules.nix` publica uma saída nativa:

```nix
{ config, inputs, ... }:
{
  flake.nixosConfigurations.exemplo = inputs.nixpkgs.lib.nixosSystem {
    modules = [ config.flake.modules.nixos.host-exemplo ];
  };
}
```

Os arquivos do host contribuem para `flake.modules.nixos.host-exemplo`. Assim,
hardware, seleção, valores específicos e home podem ficar em arquivos separados
sem outro gerador. A raiz `host-<host>` pertence à máquina e não deve ser importada
como dependência de outro host. Não há registro customizado `configurations.nixos`.

## Funcionalidades e classes

`modules/features/` publica capacidades por responsabilidade. Arquivos pequenos
podem ficar diretamente nessa pasta. i3 possui uma pasta porque sessão e ferramentas
são contribuições relacionadas para a mesma capacidade.

Uma funcionalidade pode publicar NixOS, Home Manager ou ambos. `sound.nix` publica
PipeWire em `nixos.sound` e pavucontrol em `homeManager.sound`. O host escolhe o
primeiro em seus imports NixOS. Cada conta escolhe o segundo em seus imports HM.
A parte HM verifica que o serviço de áudio necessário está habilitado.

Ghostty é somente Home Manager. Fonts é somente NixOS. Não existe módulo vazio
para completar pares. Compartilhar o nome não ativa a outra classe.

Dependências da mesma classe usam imports nativos. i3 e niri importam Ghostty na
parte HM. Herdr e os provedores importam Fish. O bootstrap pessoal do Pi importa
Pi em HM e ssh-agent em NixOS. A parte HM verifica agente e chave conhecida do GitHub.
Esses testes não provam que uma chave foi carregada ou que o clone privado funcionará.
O preset Noctalia usa GNOME Keyring como Secret Service e verifica essa opção.
Outros provedores precisam de adaptação e validação próprias. A asserção não prova
que o keyring estará desbloqueado na sessão.

## Identidade funcional, módulo e localização

O endereço `flake.modules.<classe>.<nome>` identifica a funcionalidade para o
consumidor. Nomes iguais entre classes são independentes. O nome não é uma key
técnica. Um arquivo pode publicar várias funcionalidades da mesma classe. Vários
arquivos podem contribuir para o mesmo nome, como `i3/default.nix` e `i3/tools.nix`.

Flake-parts agrega essas contribuições com `types.deferredModule` e publica um
wrapper com `_class`, `_file` e `imports`. No input fixado, o wrapper não define
key. Cada definição continua sendo uma contribuição interna separada. O `_file`
sintético identifica a publicação nos diagnósticos, mas não a deduplica.

O sistema de módulos normaliza cada contribuição com uma `key` técnica. Essa key
identifica um nó dentro de uma avaliação. `_file` atribui origem e mensagens de
erro. A localização do código fornece um namespace possível, não uma exigência
sobre como organizar funcionalidades.

Usar somente `key = __curPos.file` nas duas funcionalidades de um arquivo pode
fazer uma delas desaparecer silenciosamente. Usar somente o nome da funcionalidade
como key nas partes de arquivos diferentes também pode eliminar uma contribuição.
Nenhuma dessas limitações pertence ao padrão dendritic.

## Deduplicação nativa

`lib/modules.nix` coleta o grafo e usa `genericClosure` para selecionar módulos
únicos por key antes de mesclar suas opções. A identidade automática depende da
forma do import:

| Import | Key padrão | Repetição na mesma avaliação |
| --- | --- | --- |
| Caminho direto `./module.nix` | Caminho convertido para string | Uma contribuição. |
| Attrset ou função anônima | Posição na árvore de imports | Pode contribuir novamente. |
| Resultado de `import ./module.nix` | Posição, pois agora é um valor | Não conserva a identidade automática do caminho. |
| Valor com `_file`, sem key | Posição | Origem igual não deduplica. |
| Módulo com key explícita | Key declarada | Uma contribuição por key. |

Um módulo carregado por caminho pode substituir sua key padrão. A deduplicação
não compara configurações ou funções. Uma key igual em módulos diferentes pode
ocultar definições, imports ou conflitos. Ela também não garante executar o corpo
de uma função uma única vez. Obter a estrutura do módulo e selecionar definições
para o merge são operações diferentes. A saída `graph` é coletada separadamente
e mostra ocorrências, não apenas módulos retidos.

Nas contribuições anônimas de capacidades reutilizáveis, declaramos a key nativa
com namespace de arquivo e rótulo local. Por exemplo:

```nix
{
  flake.modules.homeManager.terminal = {
    key = "${__curPos.file}#homeManager.terminal";
    programs.ghostty.enable = true;
  };
  flake.modules.homeManager.busca = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.busca";
    home.packages = [ pkgs.ripgrep ];
  };
}
```

Cada contribuição reutilizável declara sua key onde é definida. O consumidor
continua usando apenas `imports`. O rótulo costuma incluir classe e nome por
clareza, mas não é outra identidade funcional. Renomear o atributo público não
exige renomear esse rótulo. Se um arquivo fornece duas contribuições distintas ao
mesmo nome, use rótulos diferentes ou agrupe-as em um pai identificado. Partes de
arquivos diferentes continuam distintas pelo namespace de arquivo.

Não exigimos keys em todo módulo. Caminhos diretos já têm identidade automática.
Filhos inline privados de um único pai identificado usam fallbacks posicionais
estáveis sob esse pai. Um helper anônimo alcançado por pais diferentes recebe
identidades diferentes. Se deve ser uma única contribuição compartilhada, ele
também precisa de identidade estável. Raízes de host usadas uma vez não precisam
de metadata explícita.
A regra das capacidades reutilizáveis evita que o importador precise conhecer
seleções de outros ramos. Não há helper, registro, wrapper ou deduplicador próprio.

Factories com argumentos diferentes podem criar instâncias distintas do mesmo
arquivo. Elas precisam de keys por instância quando se deseja deduplicação, ou
podem permanecer anônimas. `lib.modules.importApply` preserva localização e
argumentos, não adiciona identidade por instância. Keys não são globais entre
hosts, contas ou avaliações. `_class` verifica compatibilidade e não acrescenta
um namespace automático à key. Mudar uma key pode afetar `disabledModules`, que
trabalha com essas chaves técnicas, não com nomes funcionais.

### Ghostty e Pi

Ghostty chega ao Home Manager pela conta, por i3 e por niri. Pi chega pela conta e
pelo bootstrap. Essas são dependências intencionais, não duas funcionalidades
independentes ou dois processos iniciados. Sem identidade estável nas contribuições
anônimas, os caminhos recebem keys posicionais diferentes. A reprodução produziu
três entradas de tema e fonte no Ghostty e duas ocorrências de Pi em `home.packages`.

Remover somente o import direto de Ghostty ainda deixa os dois ramos transitivos.
Remover dependências dos componentes transferiria a coordenação ao host. Mantemos
os imports e identificamos as contribuições. Não removemos valores de listas depois
do merge para esconder a duplicação.

Quatro keys seletivas bastam para os outPaths do grafo atual. Isso não daria aos
demais exports compartilháveis o mesmo contrato de reimportação. Mantemos a
identidade nas contribuições dessas capacidades para que uma nova dependência
não exija revisar seleções prévias. As raízes privadas de host ficam fora dessa
política. A escolha é um contrato de reutilização, não uma necessidade universal
do avaliador Nix.

## Contas e Home Manager

Contas NixOS são declaradas em `users.users`. A composição pessoal reutilizada de
rinyaresu vive em `modules/users/rinyaresu/default.nix`. Ordis declara sua própria
conta no host. Não existe usuário principal global nem identidade no construtor.

O módulo `nixos.home-manager` importa a integração upstream e compartilha `pkgs`.
Cada conta gerenciada tem `home-manager.users.<nome>.imports` e sua própria
`home.stateVersion`. O upstream deriva `home.username`, `home.homeDirectory` e,
quando definido, UID da conta NixOS. A ponte verifica que nome e home correspondem
à conta. Não assume `/home/<nome>` nem deriva a versão de home da versão do sistema.

`modules/hosts/desktop/home.nix` e `modules/hosts/lab/home.nix` selecionam as
capacidades pessoais para rinyaresu. Ordis não importa a ponte e não possui HM.
Uma máquina pode declarar várias contas com listas e versões diferentes. A fixture
arquitetural exercita Alice em `/srv/alice` e Bob em `/home/bob`, com aplicativos
independentes e versões de estado distintas.

## Políticas e particularidades

Não há grupos `base`, `gui` ou `development`. Seus nomes escondiam decisões que
não eram universais. Os hosts selecionam diretamente locale, networking, Nix,
memória, ferramentas, aplicações e compatibilidade de desenvolvimento.

`nix-settings`, `networking`, `locale` e `sudo` são compartilhados explicitamente
pelos três hosts. A seleção não cria uma base obrigatória. Locale contém apenas
os valores realmente comuns. Ordis acrescenta suas categorias regionais e keymap
de console. Desktop e lab usam `console.useXkbConfig`.

`system.stateVersion` fica no host. `home.stateVersion` fica na conta daquele host.
Hardware, dispositivos, mounts, boot e a senha pública do laboratório não saem da
máquina a que pertencem. Políticas de sessão e memória do desktop não vão ao Ordis.

SOPS genérico conhece somente a integração e a localização da identidade age.
`modules/users/rinyaresu/ssh.nix` possui o ciphertext pessoal, dono, permissões,
diretório SSH, dependência da unidade HM e link. Somente desktop seleciona suas
duas partes. Lab mantém a infraestrutura SOPS sem segredos pessoais. Ordis não a importa.
O bootstrap privado Pi também pertence à pasta do usuário e só desktop o seleciona.

## Verificação dos contratos

`modules/nix/checks.nix` publica `checks.x86_64-linux.architecture`. A verificação
avalia os três hosts e uma fixture sem identidade pessoal. Ela testa composição
somente HM, imports sobrepostos, homes não convencionais e versões independentes.
Casos negativos recusam classes trocadas, conta ausente, identidade divergente,
pré-requisitos mistos ausentes e uso do link pessoal por outra conta. Os diamantes
reais de Ghostty e Pi também são verificados.

`checks.x86_64-linux.module-system` separa resultados de identidade, deduplicação
e contraexemplos. As fixtures em `checks/modules/` estão fora da descoberta de
funcionalidades. Elas publicam múltiplas capacidades por arquivo e contribuições
multifile, incluindo duas contribuições para o mesmo nome no mesmo arquivo.
A mesma fixture é consumida por `lib.evalModules` e por NixOS com duas contas HM.
Os testes de colisão demonstram perda silenciosa e conflito mascarado. Não esperam
uma recusa automática que o Nix não implementa.

Os checks `architecture` e `module-system` avaliam a configuração. O build desses
checks produz o resultado JSON. Não iniciam uma VM, acessam segredos, conectam ao
GitHub nem ativam máquinas.

Pi-hole é uma capacidade somente NixOS selecionada explicitamente pela raiz Ordis
em `modules/hosts/ordis/pihole.nix`. Esse arquivo possui a política da LAN e o
snapshot da lista; `modules/features/pihole/` contém serviço nativo e autenticação.
`checks.pihole-policy` verifica isolamento dos hosts e a política efetiva.
`checks.pihole` executa VMs QEMU com DNS real e estado persistente, com fixtures
fora da descoberta em `checks/pihole.nix`. Veja [operação e aceitação](pihole.md).
Os comandos de formatação, check e build estão no [AGENTS.md](../AGENTS.md).

## Referências e decisões

A leitura usa revisões fixas para permitir conferir as escolhas:

- [nixpkgs, carregamento e keys](https://github.com/NixOS/nixpkgs/blob/ac588ef1c914865dad517b337ea0eb9694a4021c/lib/modules.nix) fundamenta os fallbacks, `genericClosure`, `_file`, `disabledModules` e a distinção entre seleção e avaliação de funções.
- [nixpkgs, deferredModuleWith](https://github.com/NixOS/nixpkgs/blob/ac588ef1c914865dad517b337ea0eb9694a4021c/lib/types.nix) fundamenta a agregação de contribuições sem identidade estável automática por valor.
- [flake-parts, publicação de módulos](https://github.com/hercules-ci/flake-parts/blob/ea2630b7470978622c7689a1ff75d2b389175399/extras/modules.nix) mostra os wrappers de classe e localização, ainda sem key automática nesse input.
- [dotnix, WSL](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/system/wsl.nix) publica `base` e `wsl` na mesma classe e arquivo, sem keys. Isso comprova a organização possível, não idempotência de imports.
- [dotnix, registro e associação HM](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/nixos-configurations.nix) fundamenta a distinção entre descoberta, publicação e composição. Mantivemos flake-parts e módulos publicados. Removemos o matching por chaves e o registro customizado porque as opções nativas já representam hosts e contas.
- [dotnix, integração HM](https://github.com/kiriwalawren/dotnix/blob/50ad795e920d187bb56e064430f92c10326e6f66/modules/nix/home-manager.nix) mostra a identidade única na base. Aqui a identidade pertence à conta de cada host e a versão de home é independente.
- [dots, contrato operacional](https://github.com/bdsqqq/dots/blob/cd6ec69feef9a52ad8ddf607a04512a57f94bbb3/AGENTS.md) fundamenta a separação entre avaliação, build e runtime adotada no nosso AGENTS.md.
- [dots, módulos por capacidade](https://github.com/bdsqqq/dots/blob/cd6ec69feef9a52ad8ddf607a04512a57f94bbb3/modules/README.md) fundamenta a colocação de arquivos relacionados por funcionalidade. Não adotamos suas políticas de arquivos editáveis em runtime ou propagação automática.
- [dots, usuário principal](https://github.com/bdsqqq/dots/blob/cd6ec69feef9a52ad8ddf607a04512a57f94bbb3/modules/primary-user.nix) e [Ghostty](https://github.com/bdsqqq/dots/blob/cd6ec69feef9a52ad8ddf607a04512a57f94bbb3/modules/ghostty/default.nix) mostram uma abstração de usuário ainda acompanhada de literais pessoais. Aqui não criamos esse alias. Usamos a integração nativa por conta.
