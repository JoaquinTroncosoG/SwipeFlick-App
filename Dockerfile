# ==========================================
# STAGE 1: Compilación de Flutter Web
# ==========================================
FROM ghcr.io/cirruslabs/flutter:3.24.5 AS build-env

WORKDIR /app

# Cachear dependencias de Flutter
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar el código fuente del proyecto
COPY . .

# Argumentos de compilación opcionales para inyección segura de variables
ARG MONGODB_URI=""
ARG BREVO_API_KEY=""
ARG BREVO_SENDER_EMAIL="noreply@swipeflick.app"

# Compilar la aplicación web optimizada para producción
RUN flutter build web --release \
    --dart-define=MONGODB_URI=${MONGODB_URI} \
    --dart-define=BREVO_API_KEY=${BREVO_API_KEY} \
    --dart-define=BREVO_SENDER_EMAIL=${BREVO_SENDER_EMAIL}

# ==========================================
# STAGE 2: Servidor Web NGINX de Alto Rendimiento
# ==========================================
FROM nginx:alpine

# Copiar el build compilado
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Plantilla NGINX que resuelve ${PORT} dinámicamente con envsubst
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

ENV PORT=80
EXPOSE ${PORT}

CMD ["nginx", "-g", "daemon off;"]
