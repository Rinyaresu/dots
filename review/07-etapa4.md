# Etapa 4: documentação operacional

Base: `dcbf565b51dd4e411d3976396e8e0c69398f9df1`. Referência: `kiriwalawren/dotnix@50ad795e920d187bb56e064430f92c10326e6f66`. Comparei a matriz de [03-plano](03-plano.md) com os três guias de entrada e os onze documentos de `docs/`, lidos integralmente antes da remoção.

| Documento | Destino | Conhecimento preservado / conteúdo retirado |
| --- | --- | --- |
| README | [README](../README.md) | Perfis, gates nativos, instalação, uso e recuperação; retirado o índice dos guias anteriores. |
| AGENTS | [AGENTS](../AGENTS.md) | Descoberta, chaves e seleção de HM; ponteiros para os procedimentos e limites de autorização, sem repetir comandos. |
| secrets/README | [Credenciais](../secrets/README.md) | Recuperação independente, permissões, recusa de identidade inválida, edição/rotação SOPS, passphrase e revogação; retirado contrato do exportador. |
| bootstrap | Credenciais | Ordem SOPS → HM → sessão → agente → Home/Agent, cancelamento, retry, destinos preservados, credenciais externas e limites do build. |
| decisões | README e credenciais | Gate físico de Secure Boot, recuperação e impacto de ausência de criptografia; retiradas listas e preferências inferíveis. |
| desenvolvimento | README e credenciais | Trust/allow só após revisar código local, devShell nativa, escape do autoattach e preservação de servidor ativo; retirado catálogo de editor e ferramentas. |
| desktop | README e credenciais | Entrada e recuperação de sessão, validação de captura/áudio/hardware, cuidados com clipboard e keyring; retirados atalhos, aparência e inventário. |
| estrutura | AGENTS e módulos | Preservadas regras operacionais de contribuição. Removidos diagrama e exemplos do montador anterior, caminhos de módulos antigos e catálogo de checks. |
| herdr-tree | README | Pins externos, execução no servidor correto, verificação da view/action, confirmação de subscriber, rollback sem matar por nome e sem sobrescrever config concorrente. Removidos inventário pessoal, layout declarativo, histórico de checkouts e detalhes do algoritmo. |
| instalação | README e credenciais | Identificação de disco/EFI, Windows intacto, BitLocker, ensaio, Secure Boot, montagem pela declaração do host, senha no console, validação no boot e peculiaridade do rollback Limine. Retirado comando de exportação. |
| ordis | README | Conexão nova, sudo, recuperação independente, estado persistente, aplicação temporária antes da persistência e reboot separado. Retirado inventário declarativo. |
| pihole | Credenciais | Hash externo, permissões, rotação autorizada, túnel, DNS TCP/UDP e recusa externa, backup consistente e recuperação. Retiradas descrição da implementação e chamada ao check antigo. |
| serviços | README e credenciais | Chaves públicas runtime, recusa de contorno LAN, recuperação seletiva Snapper e GC manual. Retirado catálogo de serviços e ferramentas. |
| tailscale | README | Login no backend fixado, MFA, grants aditivos, chave de host, conexão realmente externa e recusa de cliente não autorizado. Não inclui URL de autenticação, IP pessoal ou estado do daemon. |

Não sobrou procedimento que exija um guia separado. O Markdown rastreado pode integrar a fonte Git, por isso os novos guias não incluem seriais, UUIDs, endereços privados, inventário de máquinas externas, valores de credenciais, tokens ou logs. Os pins do Herdr são referências de versão, não prova de acesso ao fork. As referências aos guias históricos em 02 e 03 passam a apontar para blobs fixados; os relatórios 01–07 continuam no PR.

## Verificação

- Em `32a6dddefaa43d1335f4ee78dbe7ab6c125513c2` (consolidação) e `51a6e6bb1219e46b972b8132a91422d12b1c8608` (limpeza), `nix flake check --offline --show-trace --no-write-lock-file "$src"` e `nix build --offline --no-link --print-out-paths "$src#nixosConfigurations."{desktop,lab,ordis}.config.system.build.toplevel` saíram 0. `src` era a URL `git+file://$PWD?rev=<SHA>`. Os builds reutilizaram outputs válidos.
- Avaliei e comparei com a base os drvPaths dos três toplevels, dez checks e sete packages: todos idênticos. O check nativo reutilizou as realizações. `nix fmt -- --check flake.nix` passou. Não houve reexecução KVM.
- Conferi 42 links e âncoras dos guias ativos e referências movidas; verifiquei os blocos shell com `bash -n` e comparei procedimentos com os módulos e guias anteriores. Nenhuma referência ativa a exportador, wrapper ou hook. Somente Markdown mudou; lock, CI, serviços e código permanecem idênticos.
- Nenhum comando operacional de instalação, login externo, ativação, rotação, recuperação ou deploy foi executado. Validação local não substitui CI bem-sucedida no novo head nem ensaio em hardware ou em serviços reais.
