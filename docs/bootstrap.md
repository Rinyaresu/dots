# Bootstrap de uma máquina limpa

O sistema público fornece programas, serviços e ciphertext SOPS. O operador fornece
credenciais externas e aprovações que uma configuração não pode criar.
Este contrato não autoriza instalação, ativação física ou publicação.

## Fases e transições

| Fase e transição | Responsável, entradas e saídas | Intervenção humana | Sucesso observável | Ausência, erro e repetição |
| --- | --- | --- | --- | --- |
| Preparação, máquina compatível para fonte | Operador obtém revisão pública HTTPS e exporta `source-files.txt`. Saída é fonte com manifest, incluindo ciphertext. | Conferir revisão e integridade. | Bytes, permissões e manifest correspondem à revisão. | Exportador recusa caminho fora da lista, arquivo ausente ou symlink. Novo export não modifica o anterior. |
| Preparação, fonte para build | Nix resolve dependências públicas do lock e constrói sistemas e checks. | Rede quando não há dependências em cache. | Outputs e resultados registrados para a fonte testada. | Não precisa de Home, agente SSH ou identidade age. Falha não causa ativação. Outputs idênticos podem ser reutilizados. |
| Instalador, fonte para insumos privados | Operador recupera identidade age e instala no target com dono e modo seguros. Ciphertext já está na fonte. | Recuperação independente do SSH restaurado, senha de conta e autorização dos clientes. | Identidade regular no caminho target esperado, com origem conferida. | Sem identidade, build passa, mas SOPS e HM falham no sistema iniciado. Não gerar chave substituta. Reprovisionamento preserva recuperação anterior. |
| Instalador, insumos para sistema instalado | `nixos-install` define perfil e instala bootloader. `nixos-enter` executa ativação no chroot, incluindo contas e configuração. | Volumes autorizados, senha de conta e revisão dos erros. | Perfil e bootloader instalados, conta configurada. | O enter pode tolerar erro de ativação. Seu sucesso não prova serviços. Repetir só no target autorizado. Não pressupor descriptografia no chroot. |
| Primeiro boot, sistema para SOPS | Serviço valida identidade age e descriptografa o ciphertext do store. Saída é segredo SSH runtime com dono e modo definidos. | Nenhuma quando a identidade está correta. | SOPS ativo e segredo disponível ao usuário, não a terceiros. | Ausência, identidade inválida, symlink ou metadados inseguros impedem serviço. O boot inteiro não é necessariamente bloqueado. Reinício válido preserva identidade e passphrase. |
| Primeiro boot, SOPS para home | HM tem `After` e `Requires` sobre SOPS. Instala link out-of-store para a chave. | Resolver conflitos preexistentes sem descarte automático. | HM concluído, link para segredo runtime e diretório SSH protegido. | SOPS falho bloqueia HM. Arquivo regular conflitante não é sobrescrito silenciosamente. Reativação converge. |
| Login, home para agente | Gerenciador de usuário inicia agente OpenSSH nativo e bootstrap em `default.target`. | Login com senha local. | Socket SSH compartilhado pela sessão. | Bootstrap espera agente disponível. Não há GCR concorrente. Encerramento do agente exige novo desbloqueio. |
| Primeira sessão, agente para desbloqueio | Bootstrap compara fingerprint provisionado e identidades carregadas. Consulta ambiente gráfico do gerenciador do usuário. | Passphrase SSH por askpass ou desbloqueio manual. | A identidade provisionada está no agente. | Só outra identidade não libera clones. Sem GUI espera. Cancelamento pede desbloqueio manual ou reinício explícito do serviço, sem repetir prompt nesta execução. Identidade correta carregada evita novo prompt. |
| Restauração, desbloqueio para Home e Agent | Clona Home main em temporário, valida arquivo canônico e depois clona Agent main. Publica apenas destinos ausentes. | Chave autorizada no GitHub, rede e acesso aos repositórios. | Destinos restaurados e unidade concluída. | Clone falho remove temporários e provoca retry após 30 segundos. Destinos existentes ou concorrentes são preservados. Repetição não faz pull nem sobrescreve estado. |

SOPS e HM são serviços do sistema. O bootstrap é serviço do usuário e não depende
diretamente de uma unidade gráfica. Pode começar no console e aguardar GUI ou
carregamento manual da identidade. Destinos preexistentes não são certificados
como íntegros ou atualizados pelo sucesso do bootstrap. Revise-os antes de abrir Pi.

## Insumos por host

| Host e fase | Material ou aprovação |
| --- | --- |
| Todos, avaliação e build | Fonte e dependências públicas. Nenhuma credencial pessoal. |
| Desktop, instalação e primeiro boot | Identidade age externa para o ciphertext público e senha da conta configurada no target. |
| Desktop, primeira sessão e restauração | Passphrase SSH, acesso GitHub aos repositórios privados e rede. Tokens dos provedores pessoais são autorizações posteriores, não conteúdo fabricado pelo bootstrap. |
| Desktop, login SSH remoto | Chaves públicas verificadas dos clientes no arquivo runtime de autorização, cadastro Tailscale e grants. Essas chaves autorizam entrada, não substituem a identidade usada nos clones. |
| Lab | Credencial pública descartável já declarada. VM sem rede ou compartilhamentos do host. Não recebe chave pessoal nem bootstrap. |
| Ordis, administração | Senha da conta para sudo e chave privada do cliente autorizado pela chave pública declarada. Cadastro e grants Tailscale para caminho overlay. Sem identidade age ou chave pessoal do desktop. |
| Ordis, Pi-hole | Hash administrativo externo seguro e recuperação da senha correspondente. Não pertence ao Git ou store. Veja [Pi-hole](pihole.md). |
| Recuperação física desktop | Identidade age, revisão com ciphertext, recuperação BitLocker e acesso a outro aparelho. Secure Boot e identificação dos discos são gates físicos separados. |

Não forneça valores desses insumos em chat, diffs de relatório ou logs.
Autorizações de login OpenSSH e Tailscale são controles independentes.
O arquivo público de configuração não contém estado privado da tailnet.

## Limites das provas

Checks de build não descriptografam a chave pessoal. Testes de runtime usam age,
SOPS e OpenSSH com fixtures descartáveis. Testes de scripts podem substituir GUI e
Git. Isso não prova janela GTK visível, autenticação externa ou hardware físico.

Um ensaio parcial não aprova instalação física. Recuperação real, Secure Boot,
acesso por rede externa, cadastro Tailscale, GPU e dispositivos mantêm seus gates.
Siga [instalação](instalacao.md), [serviços](servicos.md) e
[provisionamento SOPS](../secrets/README.md) antes de uma aplicação autorizada.
