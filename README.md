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

[Vídeo demonstrando RF01 e RF02 funcionando](https://drive.google.com/file/d/1J5RTa-ySDZEJoS_Q5ESotugZLTXuZbnk/view?usp=drive_link)

### Diário de bordo

Cada integrante da equipe entrega seu diário de bordo individual (modelo "Diário de Bordo") junto com esta entrega, fora deste repositório.

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
