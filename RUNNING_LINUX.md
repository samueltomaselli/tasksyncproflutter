# Rodando o projeto no Linux (Hyprland/Omarchy)

Guia específico para rodar este app Flutter+Firebase numa máquina Linux. O README.md
principal tem o passo a passo genérico; este arquivo cobre as pegadinhas específicas
de Linux que a gente resolveu configurando este ambiente.

## Scripts auxiliares (atalho para os comandos abaixo)

Em `scripts/`, pra não precisar decorar/digitar os comandos grandes:

| Script | O que faz |
|---|---|
| `./scripts/linux-build.sh [debug\|release]` | Builda o app Linux Desktop (seção 6) |
| `./scripts/linux-start.sh [debug\|release]` | Abre o binário já buildado (builda sozinho se faltar) — mais rápido que `flutter run` quando não precisa de hot reload |
| `./scripts/linux-run.sh` | `flutter run -d linux` com hot reload |
| `./scripts/android-build.sh [debug\|release]` | Sobe o emulador se precisar, builda o APK e instala no device (seção 5) |
| `./scripts/android-start.sh` | Sobe emulador+scrcpy se precisar e abre o app **já instalado**, sem rebuildar — pra depois de rodar `android-build.sh` |
| `./scripts/android-run.sh` | Sobe o emulador (`-no-window`) + scrcpy + `flutter run` com hot reload no Android |

Os pares `*-build.sh` + `*-start.sh` (Linux e Android) servem pro fluxo
"buildei, agora só quero reabrir rápido pra testar", sem recompilar nem
esperar o hot-reload attachar. `*-run.sh` é pro fluxo de desenvolvimento
ativo, com hot reload.

Todos assumem que você já rodou a seção 1 (Flutter/Android SDK via mise) pelo
menos uma vez. Os scripts de Android aceitam `AVD_NAME=Outro ./scripts/android-run.sh`
se o seu AVD não se chamar `Pixel_6_API_35`.

## 1. Instalar Flutter e Android SDK (via mise)

```bash
mise use -g flutter@latest
mise use -g android-sdk@latest

ANDROID_SDK_ROOT="$HOME/.local/share/mise/installs/android-sdk/23.0"
SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/23.0/bin/sdkmanager"

yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" "platforms;android-35" "platforms;android-36" \
  "build-tools;35.0.0" "emulator" \
  "system-images;android-35;google_apis;x86_64"

mise set ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" -g
mise set ANDROID_HOME="$ANDROID_SDK_ROOT" -g
```

> Flutter recente (3.47+) baixa sozinho, na primeira build, alguns componentes
> extras que faltarem (Build-Tools 36, NDK, CMake) — é normal a primeira
> `flutter build`/`flutter run` demorar bastante (15-20 min) por causa disso.

## 2. google-services.json

Baixe o arquivo do Firebase Console (projeto do colega/dono do app) e coloque em:

```
android/app/google-services.json
```

Esse arquivo é ignorado pelo git (`.gitignore`) — cada dev precisa colocar o seu.

## 3. Bug de case-sensitivity (já corrigido no código)

O projeto foi criado originalmente em Windows/macOS, que ignoram
maiúsculas/minúsculas nos nomes de arquivo. Linux não ignora, então dois imports
apontavam para `Data/...` quando a pasta real é `data/...`. Isso já foi corrigido
nos arquivos:

- `lib/data/network/firebase/firebase_services.dart`
- `lib/view model/controller/home_controller.dart`
- `lib/view/sign up/components/signup_options.dart`

Se aparecer erro `Error when reading '...': No such file or directory` ao buildar,
é esse tipo de problema — procure por imports `package:to_do_app/Data/...`
(D maiúsculo) e troque para `data/` minúsculo.

## 4. Criar o emulador (uma vez só)

```bash
AVDMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/23.0/bin/avdmanager"
echo "no" | "$AVDMANAGER" create avd -n "Pixel_6_API_35" \
  -k "system-images;android-35;google_apis;x86_64" -d "pixel_6"
```

## 5. Rodar o app — use scrcpy, não a janela padrão do emulador

**Problema conhecido:** no Hyprland (e outros compositores Wayland tiling), a
janela Qt do Android Emulator abre em *duas* janelas separadas (a tela do
celular + uma barrinha fina de controles). A barrinha rouba o foco de teclado
e às vezes abre em outra workspace — o resultado é: você digita e nada
acontece, e os atalhos de Home/Voltar/Apps recentes também não funcionam.

**Solução:** rodar o emulador sem janela própria (`-no-window`) e usar o
[scrcpy](https://github.com/Genymobile/scrcpy) para espelhar e controlar —
ele abre uma única janela nativa Wayland, sem esse bug.

```bash
# instalar (uma vez só)
omarchy pkg add scrcpy

# 1. ligar o emulador sem interface própria
emulator -avd Pixel_6_API_35 -no-snapshot -no-window &

# 2. esperar bootar
adb wait-for-device

# 3. abrir o scrcpy (janela única, teclado/mouse funcionando)
scrcpy -s emulator-5554

# 4. instalar/rodar o app (em outro terminal)
cd "tasksyncproflutter"
flutter run -d emulator-5554
```

### Navegação sem gestos (Home / Voltar / Apps recentes)

O scrcpy tem atalhos de teclado próprios (não precisam de foco especial, já
que ele controla o dispositivo diretamente via ADB):

| Atalho | Ação |
|---|---|
| `Alt` (ou `Super`) `+H` | Home |
| `Alt/Super +B` (ou botão direito do mouse) | Voltar |
| `Alt/Super +S` | Apps recentes (overview) |
| `Alt/Super +N` | Abrir notificações |

Se preferir botões visíveis na tela em vez de atalhos, dá pra trocar o
emulador para a barra de navegação clássica de 3 botões (▶ ⚪ ⬜) em vez da
navegação por gestos:

```bash
adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton
```

(reinicia a SystemUI do Android — é rápido, o app reabre normal em seguida)

## 6. Rodar como app nativo Linux Desktop (modo de teste sem Firebase)

`firebase_core`, `firebase_auth`, `firebase_database`, `google_sign_in` e
`sqflite` **não têm implementação nativa para Linux** (só Android, iOS,
macOS, Web e às vezes Windows). Builda normalmente, mas sem tratamento
travaria em runtime — `firebase_core` com
`PlatformException(channel-error, ...FirebaseCoreHostApi.initializeCore...)`
e o `sqflite` com um erro parecido ao tentar abrir o banco local.

Por isso o app tem um **modo de teste Linux**, ativado automaticamente
(`Platform.isLinux`, ver `lib/data/network/firebase/firebase_mode.dart`) —
não precisa de nenhuma flag ou variável de ambiente:

- Não chama `Firebase.initializeApp()`; usa `sqflite_common_ffi` no lugar do
  `sqflite` padrão para o banco local de tarefas (dados **reais**, persistem
  entre execuções, só não sincronizam com a nuvem).
- Login e cadastro **não validam nada de verdade**: qualquer clique já entra
  na Home com um usuário fake local (gravado via `SharedPreferences`,
  mesmo mecanismo que o app usa pra "lembrar" login entre execuções).
- O botão de login com Google mostra um aviso ("Google sign-in is disabled
  in Linux test mode") em vez de travar.
- Sem sincronização com Firebase Realtime Database — tudo fica só na
  máquina local.

Serve para testar UI, navegação e o fluxo de criar/editar/concluir tarefas
nativamente, sem precisar de emulador Android nem `google-services.json`.

### Comandos

```bash
cd "tasksyncproflutter"

# roda com hot reload (r = hot reload, R = hot restart, q = sair)
flutter run -d linux

# só builda, sem rodar
flutter build linux --debug      # ou --release

# executar o binário já buildado
./build/linux/x64/debug/bundle/to_do_app     # debug
./build/linux/x64/release/bundle/to_do_app   # release

# rodar os testes automatizados (não depende de nenhum device)
flutter test
```

Se `flutter devices` não listar `Linux (desktop)`, rode
`flutter config --enable-linux-desktop` uma vez e reabra o terminal.

## 7. Limitações conhecidas

- **Linux Desktop:** funciona apenas no modo de teste local descrito na
  seção 6 acima — sem Firebase real, sem sync na nuvem, sem login do Google.
  Para testar o fluxo completo com Firebase de verdade, use o emulador
  Android (seção 5).
- **Web:** precisa de uma configuração Firebase separada da do Android (um
  `appId` e `authDomain` próprios do app Web, registrados no Firebase Console
  em Configurações do projeto → Seus apps → Adicionar app Web). Sem isso o
  Firebase não inicializa no Chrome.
