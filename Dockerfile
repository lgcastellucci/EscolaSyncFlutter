FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app
COPY . .

# Keystore é montado via volume em /keystore no docker-build.sh,
# então aqui apenas garantimos as dependências e o build.
RUN flutter pub get

# As credenciais do keystore são passadas via --dart-define pelo
# docker-build.sh e lidas em android/key.properties (via env),
# então o comando de build real acontece no docker run (docker-build.sh),
# não aqui, para permitir reuso da mesma imagem com senhas diferentes
# sem rebuild. Este RUN abaixo serve como smoke test do build.
RUN flutter build appbundle --release || true

# O AAB final (gerado pelo docker-build.sh) estará em:
# build/app/outputs/bundle/release/app-release.aab
