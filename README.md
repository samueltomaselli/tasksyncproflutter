# TaskSync Pro

Aplicativo Flutter de gerenciamento de tarefas, com autenticação e sincronização via Firebase e cache local via SQLite.

## Sprint 1 — Análise, Projeto e Desenvolvimento Ágil (Equipe 6)

> Este repositório foi herdado como projeto legado para a disciplina de Análise, Projeto e Desenvolvimento Ágil. Esta seção documenta o trabalho da equipe sobre o projeto original de [Hamad Anwar](https://github.com/Hamad-Anwar/Task-Sync-Pro-Flutter).

**Equipe 6:** Davi Scheuer, Gustavo Nascimento Caballero, Hallan Rauber Sbardelatti, Otavio Augusto dos Santos e Samuel Henrique Tomaselli.

### Contexto (história de usuário)

> "Um colega meu testou o app e travou na hora de ver o nome dele na tela inicial, o nome dele é só uma palavra. Além disso, hoje só dá para marcar uma tarefa como prioridade alta ou baixa, e eu preciso de um nível médio também." — relato da professora, formatado como história de usuário do TaskSync Pro.

### Requisitos da Sprint 1

| Requisito | Descrição | Estimativa (Planning Poker) | MoSCoW | Status |
|---|---|---|---|---|
| RF01 | A saudação da tela inicial não exibia o nome de usuários com nome cadastrado composto por uma única palavra, e a tela travava. | 2 | Must have | ✅ Concluído (PR #1) |
| RF02 | Adicionar um terceiro nível de prioridade (Média) para tarefas, além de Alta e Baixa. | 5 | Must have | ✅ Concluído (PR #3) |

### O que foi feito até o momento

- Análise do repositório legado herdado (app Flutter com autenticação e sincronização via Firebase e cache local via SQLite).
- Correção de erros de build e atualização de pacotes desatualizados (migração de `connectivity` para `connectivity_plus`, ajustes no seletor de datas, configuração do Firebase) para o projeto voltar a rodar em todas as máquinas da equipe.
- Pesquisa e aplicação de conceitos de Scrum e Extreme Programming (XP) ao contexto do repositório herdado.
- Levantamento e detalhamento dos requisitos RF01 e RF02 a partir da história de usuário passada pela professora, com estimativa via Planning Poker e priorização via MoSCoW.
- Organização do backlog em um quadro Kanban no Trello, com tarefas adicionais criadas a partir de bugs e melhorias observados em testes do app.
- **RF01 implementado**: exigência mínima de 2 caracteres no nome (em vez de 5), nome do usuário passa a aparecer corretamente na Home mesmo quando composto por uma única palavra, e mensagem de aviso ajustada (PR #1).
- **RF02 implementado**: seletor de prioridade estendido de Alta/Baixa para Alta/Média/Baixa, integrado tanto na criação quanto na edição de tarefas (PR #3).
- Funcionalidades extras entregues a partir dos bugs e melhorias observados nos testes: edição de tarefas já criadas (PR #2), menu lateral com logout (PR #3), correção da busca que não filtrava a lista (PR #5) e tela de perfil com nome e e-mail (PR #6).

### Vídeo de demonstração

[Vídeo demonstrando RF01 e RF02 funcionando](https://drive.google.com/file/d/1J5RTa-ySDZEJoS_Q5ESotugZLTXuZbnk/view?usp=sharing)

### Diário de bordo

Cada integrante da equipe entrega seu diário de bordo individual (modelo "Diário de Bordo") junto com esta entrega, fora deste repositório.

---

## Sprint 2 — Análise, Projeto e Desenvolvimento Ágil (Equipe 6)

> Esta seção documenta o Sprint 2 (N2). Além de atender o pedido do cliente, o foco foi a qualidade técnica: teste antes de mexer no código, refatoração com teste de regressão, revisão por Pull Request e integração contínua.

**Papéis no Sprint 2:** Samuel Henrique Tomaselli (Scrum Master), Davi Scheuer (Product Owner), Gustavo Nascimento Caballero, Hallan Rauber Sbardelatti e Otavio Augusto dos Santos (Devs).

### Contexto (pedido do cliente)

> "Uma tarefa que eu criei sumiu sem eu apagar, acho que foi quando fiquei sem internet por um tempo." — relato da professora para o TaskSync Pro.

Investigando o código, a equipe encontrou a causa: ao criar uma tarefa com rede conectada mas sem internet, o `insert` do `DbHelper` gravava só na tabela `Tasks`, chamava o Firebase sem esperar a resposta e ignorava o erro. A tarefa nunca entrava na fila de envio (`PendingUploads`) e se perdia no logout, na reinstalação ou em outro aparelho. Além disso, o app não avisava o usuário de nada.

### Sprint Goal

Garantir que uma tarefa criada pelo usuário não se perca quando a conexão falha e que o usuário seja avisado quando algo não sincronizar, sem quebrar o que já funcionava na N1.

### User Story

**Como** usuário do TaskSync Pro, **quero** que as tarefas que eu crio sem internet fiquem salvas e sejam enviadas quando a conexão voltar, **para** não perder nada e saber quando alguma tarefa ainda não foi salva na nuvem.

**Verificação INVEST**

| Critério | Como a história atende |
|---|---|
| Independente | Pode ser entregue sem depender de outras histórias do backlog. |
| Negociável | O formato do aviso (banner, mensagem, diálogo) foi decidido pela equipe junto com o PO. |
| Valiosa | Resolve a perda de dados relatada pelo cliente. |
| Estimável | O problema foi localizado no `insert` e na sincronização do `DbHelper`. |
| Pequena | Coube no Sprint 2, dividida em dois PRs (#11 e #10). |
| Testável | Cada critério de aceite abaixo tem teste automatizado. |

**Critérios de aceite**

- **Dado** que o usuário está sem internet, **quando** ele cria uma tarefa, **então** ela aparece na lista e fica na fila de envio.
- **Dado** que existe tarefa na fila de envio, **quando** a internet volta, **então** a tarefa é enviada ao Firebase e sai da fila.
- **Dado** que o envio de uma tarefa falhou, **quando** o usuário reabre o app, **então** a tarefa continua na lista e o envio é tentado de novo.
- **Dado** que existem tarefas pendentes, **quando** o usuário está na tela inicial, **então** aparece um aviso com quantas tarefas faltam sincronizar.
- **Dado** que o envio falhou, **quando** a sincronização termina, **então** o usuário recebe uma mensagem de que a tarefa ainda não foi salva na nuvem.
- **Dado** que existem tarefas pendentes, **quando** o usuário tenta sair da conta, **então** o app avisa quantas tarefas serão perdidas antes de confirmar.
- **Dado** que a gravação local falhou, **quando** o usuário cria a tarefa, **então** o erro aparece na tela e o formulário não fecha.

### Backlog do Sprint 2

| Item | Descrição | Tipo | Estimativa (Planning Poker) | MoSCoW | Justificativa | Status |
|---|---|---|---|---|---|---|
| US01 | Tarefa criada offline não pode se perder (fila de envio e nova tentativa) | Correção | 8 | Must have | É o pedido central do cliente. | ✅ Concluído (PR #11) |
| US02 | Avisar o usuário sobre tarefas não sincronizadas e proteger o logout | Funcionalidade | 8 | Must have | A falha não pode ser silenciosa, segunda parte do pedido. | ✅ Concluído (PR #10) |
| PEND01 | Prioridade em três níveis visível nos cards e compatível com dados antigos (pendência da N1) | Funcionalidade | 3 | Should have | A prioridade Média já existia desde a N1, faltava exibir e tratar valores antigos. | ✅ Concluído (PR #13) |
| SM01 | Smell 1: SQL das tabelas repetido no `onCreate` | Refatoração | 3 | Should have | Exigência da N2 e base para a migração do banco. | ✅ Concluído (PR #15 e #16) |
| SM02 | Smell 2: prioridade como texto solto no código | Refatoração | 3 | Should have | Exigência da N2 e sugestão da avaliação de pares da N1. | ✅ Concluído (PR #14) |
| SM03 | Smell 3: conversão do Firebase para tarefa duplicada | Refatoração | 2 | Should have | Exigência da N2, evita ler tarefas novas e editadas de jeitos diferentes. | ✅ Concluído (PR #16) |
| BUG01 | Colunas sem tipo e coluna `TEXT` criada por engano no banco (migração para v2) | Correção | 5 | Could have | Corrige o schema sem perder as tarefas já salvas. | ✅ Concluído (PR #15) |
| BUG02 | Testes falhando no macOS e Windows por causa do Firebase | Correção | 1 | Must have | Sem isso a suíte não rodava nas máquinas da equipe. | ✅ Concluído (PR #12) |
| CI01 | Pipeline de CI com `flutter analyze` e `flutter test` | Configuração | 2 | Must have | Exigência da N2 e compromisso da retrospectiva da N1. | ✅ Concluído (PR #9) |

**Pendências para o próximo Sprint** (bugs encontrados durante o Sprint 2):

- A mensagem de tarefa não sincronizada pode aparecer várias vezes quando a conexão volta.
- Se o primeiro envio depois de reconectar estourar o tempo limite, o app só tenta de novo quando a conexão muda outra vez ou o app é reaberto.
- A busca da tela inicial não filtra a lista.
- O botão Voltar do Android na tela de tarefas volta para a splash e trava.
- Cadastro com e-mail que tem ponto antes do @ (ex.: `nome.sobrenome@gmail.com`) quebra, porque essa parte vira caminho no Realtime Database.
- `TaskModel.fromFirebase` usa `element.value as Map` e lança erro se um nó do Firebase vier vazio.

### Definition of Done (DoD)

Uma história ou tarefa só está pronta quando:

- tem teste automatizado cobrindo o caminho principal (correção de bug com teste que falha antes e passa depois, refatoração com teste de regressão que passa antes e depois)
- não introduz code smell conhecido
- foi revisada por pelo menos um colega, com comentário registrado no próprio PR
- o CI (`dart format`, `flutter analyze` e `flutter test`) está verde
- qualquer mudança no formato de dado continua lendo os dados já salvos
- está mergeada na `main`

### Catálogo de code smells

| # | Onde está | Smell | Refatoração aplicada | Teste de regressão | Tipo |
|---|---|---|---|---|---|
| 1 | `lib/view model/DbHelper/db_helper.dart`, `onCreate` criando `Tasks`, `PendingUploads` e `PendingDeletes` | Código duplicado: a mesma lista de colunas escrita três vezes no `CREATE TABLE` | Extrair a lista de colunas para a constante `_taskColumns` e gerar as três tabelas a partir dela em `createSchema` (PR #15 e #16) | `test/db_table_columns_test.dart` (colunas das três tabelas e leitura de volta) e `test/db_schema_migration_test.dart` | Refatoração |
| 2 | `lib/view model/controller/add_task_controller.dart` e `lib/view/new task/components/title.dart`, valores `'High'`, `'Medium'` e `'Low'` escritos à mão | Obsessão por tipos primitivos: prioridade como `String` solta, um erro de digitação passa sem aviso | Substituir o texto pelo `enum Priority { high, medium, low }`, mantendo `'High'`, `'Medium'` e `'Low'` no SQLite e no Firebase para ler dados antigos (PR #14) | `test/task_model_test.dart` (valores salvos, ausentes e inválidos) | Refatoração |
| 3 | `lib/view model/controller/home_controller.dart`, listeners `onValue` e `onChildChanged` | Código duplicado: o mesmo bloco de onze linhas convertendo um nó do Firebase em `TaskModel` | Extrair o construtor `TaskModel.fromFirebase` e usar nos dois listeners (PR #16, feito em Pair Programming) | `test/task_model_from_firebase_test.dart` (todos os campos, números, campos ausentes e ida e volta) | Refatoração |
| 4 | `lib/view model/DbHelper/db_helper.dart`, checagem de conexão em `insert`, `removeFromList` e `updateAndSync` | Código duplicado com regras divergentes: quatro cópias da checagem "está online?", e o `insert` ignorava ethernet | Extrair o método único `DbHelper.isOnline()` (PR #11) | `test/db_helper_connectivity_test.dart` e `test/db_helper_edit_test.dart` | Refatoração dentro de uma correção de bug |

### Pull Requests principais

Os PRs da história, da pendência da N1 e dos smells foram revisados por um colega, com comentário no PR, e entraram com o CI verde.

- [PR #11](https://github.com/samueltomaselli/tasksyncproflutter/pull/11) — Tarefa criada sem internet entra na fila de envio e só sai quando o Firebase confirma (US01)
- [PR #10](https://github.com/samueltomaselli/tasksyncproflutter/pull/10) — Aviso de tarefas não sincronizadas, mensagem de falha e logout protegido (US02)
- [PR #13](https://github.com/samueltomaselli/tasksyncproflutter/pull/13) — Prioridade exibida nos cards e compatível com dados antigos (PEND01)
- [PR #14](https://github.com/samueltomaselli/tasksyncproflutter/pull/14) — Prioridade como enum (Smell 2)
- [PR #15](https://github.com/samueltomaselli/tasksyncproflutter/pull/15) — Migração do banco para a v2 com colunas tipadas (BUG01 e Smell 1)
- [PR #16](https://github.com/samueltomaselli/tasksyncproflutter/pull/16) — `TaskModel.fromFirebase` e tabelas geradas da lista de colunas (Smell 3 e Smell 1)

Também entraram, sem comentário de revisão registrado:

- [PR #9](https://github.com/samueltomaselli/tasksyncproflutter/pull/9) — Pipeline de CI no GitHub Actions (CI01)
- [PR #12](https://github.com/samueltomaselli/tasksyncproflutter/pull/12) — Testes rodando sem Firebase em qualquer sistema (BUG02)

### Integração contínua

O workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda a cada push na `main` e a cada Pull Request, com `dart format`, `flutter analyze` e `flutter test`. [Ver as execuções do CI no GitHub Actions](https://github.com/samueltomaselli/tasksyncproflutter/actions/workflows/ci.yml).

### Como rodar os testes

Na raiz do projeto:

```
flutter pub get
flutter test
```

Para rodar as mesmas verificações do CI:

```
dart format --output=none --set-exit-if-changed .
flutter analyze --no-fatal-infos
flutter test
```

A suíte tem 80 testes e roda sem Firebase, então funciona em Linux, macOS e Windows.

### Vídeo de demonstração

[Vídeo do Sprint 2: tarefa criada offline, aviso de pendência, sincronização e testes passando](LINK_DO_VIDEO)

### Diário de bordo

Cada integrante entrega seu diário de bordo individual (modelo "Diário de Bordo N2") e o Skill Radar com a coluna da N2, fora deste repositório.

---

## Instalação

> **Rodando no Linux?** Veja [RUNNING_LINUX.md](RUNNING_LINUX.md) para configuração do Flutter/Android SDK via `mise`, uma correção de case-sensitivity, e como contornar um bug de foco de teclado entre o Android Emulator e o Hyprland usando `scrcpy`.

1. Clone este repositório: `git clone https://github.com/samueltomaselli/tasksyncproflutter.git`
2. Acesse a pasta do projeto: `cd tasksyncproflutter`
3. Instale as dependências: `flutter pub get`
4. **Adicione o `google-services.json`:** para configurar o Firebase, cada desenvolvedor precisa adicionar seu próprio arquivo `google-services.json`, obtido no projeto Firebase da equipe. Coloque este arquivo na pasta `android/app`.

5. **Configure a Autenticação do Firebase:**
   - Acesse o Firebase Console e crie um projeto.
   - Habilite o método de login por E-mail/Senha.
   - Adicione seu app Android ao projeto e baixe o arquivo `google-services.json`.
   - Se necessário, adicione seu app iOS e baixe o arquivo `GoogleService-Info.plist`.

6. **Configure o Firebase Realtime Database:**
   - No Firebase Console, crie um Realtime Database.
   - Defina as regras de segurança de acordo com a necessidade.
   - Atualize a configuração do Firebase no código do app Flutter.

7. Rode o app: `flutter run`

## Dependências

Principais dependências utilizadas pelo app (ver `pubspec.yaml` para a lista completa):

- **google_fonts**: acesso a uma ampla variedade de fontes do Google para a tipografia do app.
- **get**: gerenciamento de estado reativo, simplificando atualizações de UI e interações.
- **email_validator**: validação de endereços de e-mail no cadastro e login.
- **font_awesome_flutter**: biblioteca de ícones FontAwesome para os elementos visuais do app.
- **firebase_core**: inicialização e conexão do app Flutter com os serviços do Firebase.
- **firebase_auth**: autenticação de usuários.
- **firebase_database**: integração com o Firebase Realtime Database para sincronização em tempo real das tarefas.
- **shared_preferences**: armazenamento local de chave-valor no dispositivo.
- **google_sign_in** e **sign_in_with_apple**: login social via Google e Apple.
- **flutter_svg**: renderização de imagens SVG.
- **intl**: internacionalização e localização.
- **sqflite** e **sqflite_common_ffi**: banco de dados local, permitindo acesso offline e persistência de dados mesmo sem conexão com a internet (o `_ffi` dá suporte a desktop/Linux).
- **connectivity_plus**: monitoramento do estado da conexão com a internet.

## Licença

Este projeto está licenciado sob a [Licença MIT](/LICENSE).

---

### Projeto original desenvolvido por [Hamad Anwar](https://www.linkedin.com/in/hamad-anwar/), herdado e evoluído pela Equipe 6 na disciplina de Análise, Projeto e Desenvolvimento Ágil.
