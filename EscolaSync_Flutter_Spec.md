# EscolaSync — Especificação para Reescrita em Flutter

## Contexto
App Android publicado na Play Store que **move fotos do álbum "Escola"
para uma pasta "Escola" no Google Drive** e, após upload confirmado,
**deleta as fotos do dispositivo**.

O app atual (.NET 10 MAUI) apresenta crash no Samsung S24 (Android 14,
ARM64) por problemas de empacotamento de assemblies no AAB.
A solução é reescrever em Flutter com build 100% em container Docker.

---

## Objetivo do Novo App

1. Usuário abre o app
2. Autentica com Google (OAuth2) — abre browser externo
3. App lista fotos do álbum "Escola" no dispositivo
4. Usuário toca "Enviar Agora"
5. App faz upload de cada foto para a pasta "Escola" no Google Drive
6. Após confirmar upload, deleta a foto do dispositivo
7. Exibe log visual de cada etapa na tela

---

## Requisitos Funcionais

### Autenticação
- OAuth2 Google via browser externo (`google_sign_in` ou `flutter_appauth`)
- Scopes necessários: `https://www.googleapis.com/auth/drive.file`
- Token persistido localmente (shared_preferences ou flutter_secure_storage)
- Botão "Autenticar Drive" na tela principal
- A aplicação não deve pegar uma conta já cadastrada no celular android para login
- O acesso deve ser feito sem a necessidade de cadastro da conta google no android
- Utiliza uma conta google totalmente a parte de tudo que tem no celular

### Listagem de Fotos
- Ler fotos do álbum/bucket chamado **"Escola"** via MediaStore Android
- Usar `photo_manager` package (acesso nativo à MediaStore)
- Exibir contagem de fotos encontradas no log

### Upload para Drive
- Criar pasta "Escola" no Drive se não existir (ou reutilizar existente)
- Upload multipart via Google Drive REST API v3
- Skip de arquivos já existentes com mesmo nome (verificar antes de subir)
- Progresso visual por arquivo

### Deleção Local
- Após upload confirmado (ID do arquivo no Drive recebido), deletar foto local
- Android 11+: usar `createDeleteRequest` (MediaStore)
- Android 14: solicitar permissão de deleção via dialog do sistema
- Usar `photo_manager` para deleção

### Log Visual na Tela
- Cada passo exibido em tempo real na tela (não só no console)
- Cores: verde = OK, vermelho = erro, amarelo = em andamento, azul = info
- ScrollView que acompanha automaticamente o último log
- Timestamp em cada linha

---

## Credenciais Google (manter do app atual)

### Client ID Android (SHA-1 já cadastrado no Google Cloud Console)
- SHA-1: `62:C6:83:E5:14:EE:3E:13:98:A4:1A:15:E5:77:BD:35:00:2A:38:B8`
- Package: `com.escolasync.app`
- O google-services.json deve ser configurado com essas credenciais

### Keystore de Assinatura
- Arquivo: `escolasync-release.keystore`
- Alias: `escolasync`
- Senha keystore: `Escola@Sync@2026`
- Senha key: `Escola@Sync@2026`
- Já publicado na Play Store — deve usar o mesmo keystore

---

## Package Name
```
com.escolasync.app
```
(manter igual ao publicado na Play Store)

---

## Estrutura Flutter Esperada

```
escolasync/
├── Dockerfile                  ← build do AAB sem instalar nada local
├── docker-build.sh             ← script: docker run → gera AAB assinado
├── pubspec.yaml
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   ├── google-services.json   ← credenciais Google
│   │   └── src/main/
│   │       └── AndroidManifest.xml
│   └── key.properties          ← referência ao keystore
├── lib/
│   ├── main.dart
│   ├── pages/
│   │   └── home_page.dart      ← tela principal com log
│   ├── services/
│   │   ├── auth_service.dart   ← OAuth2 Google
│   │   ├── drive_service.dart  ← upload + criar pasta
│   │   └── media_service.dart  ← ler + deletar fotos
│   └── models/
│       ├── photo_item.dart
│       └── log_entry.dart
└── assets/                     ← ícones se necessário
```

---

## Dockerfile (base)

```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build appbundle --release \
    --dart-define=FLUTTER_BUILD_NUMBER=1

# O AAB gerado estará em:
# build/app/outputs/bundle/release/app-release.aab
```

---

## Script docker-build.sh (base)

```bash
#!/bin/bash
# Gera AAB assinado dentro do container e copia para ./output/

docker build -t escolasync-builder .

docker run --rm \
  -v "$(pwd)/output:/app/build/app/outputs/bundle/release" \
  -v "$(pwd)/escolasync-release.keystore:/keystore/escolasync-release.keystore" \
  escolasync-builder \
  flutter build appbundle --release \
    --dart-define=KEY_ALIAS=escolasync \
    --dart-define=KEY_PASSWORD=Escola@Sync@2026 \
    --dart-define=STORE_PASSWORD=Escola@Sync@2026

echo "AAB gerado em ./output/app-release.aab"
```

---

## Packages Flutter Necessários

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Auth Google
  google_sign_in: ^6.2.1
  
  # Drive API
  googleapis: ^13.2.0
  googleapis_auth: ^1.6.0
  
  # Acesso a fotos / MediaStore
  photo_manager: ^3.3.0
  
  # Armazenamento seguro do token
  flutter_secure_storage: ^9.2.2
  
  # HTTP
  http: ^1.2.1
  
  # UI
  cupertino_icons: ^1.0.8
```

---

## Permissões Android (AndroidManifest.xml)

```xml
<!-- Fotos -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<!-- Android < 13 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET"/>
<!-- Drive redirect URI -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

---

## Paleta Visual (manter identidade)

| Elemento | Cor |
|----------|-----|
| Fundo | `#0F172A` |
| Card/frame | `#1E293B` |
| Azul principal | `#1E40AF` |
| Azul claro | `#60A5FA` |
| Verde OK | `#34D399` |
| Vermelho erro | `#EF4444` |
| Amarelo passo | `#FDE68A` |

---

## Tela Principal — Layout

```
┌─────────────────────────────────┐
│  📁 EscolaSync                  │
├─────────────────────────────────┤
│  ● Autenticado no Google Drive  │  ← status card (verde/vermelho)
├─────────────────────────────────┤
│  [🔐 Autenticar Drive] [📤 Enviar] │
├─────────────────────────────────┤
│  📋 Log de execução             │
│  ✅ [10:23:01] App iniciado     │
│  ▶️  [10:23:02] Buscando fotos...│
│  ✅ [10:23:02] 5 foto(s)        │
│  ▶️  [10:23:03] Upload foto1.jpg │
│  ✅ [10:23:04] foto1.jpg → Drive │
│  ...                            │
├─────────────────────────────────┤
│  ████████░░  Enviando 3/5...    │  ← progress bar
└─────────────────────────────────┘
```

---

## Comportamento Esperado no S24 (Android 14)

- Ao deletar fotos: Android 14 exige confirmação do usuário via dialog do sistema
- `photo_manager` lida com isso automaticamente via `deleteWithId`
- Testar especificamente no Samsung S24 (ARM64, Android 14)

---

## Publicação Play Store

- Usar o **mesmo keystore** `escolasync-release.keystore`
- Package `com.escolasync.app` já está publicado — subir como atualização
- Versão inicial Flutter: `1.0.8` (continuando numeração atual)
- Formato: AAB (obrigatório para Play Store)

---

## O que NÃO precisa fazer

- Não precisa de backend/servidor
- Não precisa de banco de dados
- Não precisa de notificações push
- Não precisa de sincronização automática (só manual por botão)
- Não precisa de múltiplas contas Google

---

## Resumo para o Claude no próximo chat

"Preciso criar um app Flutter Android chamado EscolaSync
(com.escolasync.app) que move fotos do álbum 'Escola' do dispositivo
para uma pasta 'Escola' no Google Drive e deleta localmente após upload.
Build deve ser feito via Docker (sem instalar Flutter localmente).
Siga a especificação completa no arquivo EscolaSync_Flutter_Spec.md
que vou anexar."
