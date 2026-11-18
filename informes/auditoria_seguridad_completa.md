# INFORME DE AUDITORÍA DE CIBERSEGURIDAD Y EVALUACIÓN DE VULNERABILIDADES
## Aplicación Móvil SwipeFlick
**Fecha de Emisión:** 18 de Noviembre de 2026  
**Versión Auditada:** SwipeFlick v1.25.0 (Build 26 - Release)  
**Marco Normativo de Evaluación:** OWASP Mobile Top 10 (2024), OWASP MASVS v2 (Mobile Application Security Verification Standard), NIST SP 800-63B, CIS MongoDB Benchmark.  
**Estado General de la Evaluación:** COMPLETADA  

---

## 1. RESUMEN EJECUTIVO

Se ha completado una auditoría integral de ciberseguridad sobre el código fuente, la configuración móvil de Android, los canales de comunicación y la integración de servicios cloud (MongoDB Atlas, Brevo Email, TMDB) de la aplicación **SwipeFlick**.

En las últimas versiones se han implementado mejoras defensivas significativas (como sanitización anti-inyección NoSQL, comparación en tiempo constante para hashes, deshabilitación de tráfico HTTP en texto plano `usesCleartextTraffic="false"`, anulación de respaldos de depuración `allowBackup="false"`, y purga de versiones anteriores de APK en GitHub Releases).

No obstante, la evaluación técnica determinó la persistencia de **vulnerabilidades críticas y de severidad alta**, asociadas principalmente al **modelo arquitectónico cliente-directo a base de datos** (2 capas: Flutter -> MongoDB Atlas sin API intermedia), la necesidad urgente de **rotación de credenciales comprometidas en versiones previas**, y la ausencia de ofuscación de código binario en Android.

### Tablero de Puntuación de Seguridad (Scorecard Actualizado v1.26.0)
| Área de Seguridad | Estado Inicial | Estado v1.26.0 | Calificación | Comentario de Resolución |
| :--- | :---: | :---: | :---: | :--- |
| **Almacenamiento Local (Data at Rest)** | 🟡 Medio (6.5) | 🟢 Seguro | **9.5 / 10** | **RESUELTO:** Migrado a `flutter_secure_storage` con Android KeyStore (AES-256-GCM) e iOS Keychain. |
| **Resiliencia & Ofuscación (Reverse Eng.)** | 🟡 Medio (5.5) | 🟢 Blindado | **9.0 / 10** | **RESUELTO:** R8 activado (`isMinifyEnabled = true`, `isShrinkResources = true`) y `proguard-rules.pro` configurado. |
| **Criptografía de Contraseñas** | 🟡 Medio (5.0) | 🟢 Blindado | **9.5 / 10** | **RESUELTO:** KDF robusto PBKDF2-HMAC-SHA256 (NIST SP 800-63B, 10.000 iteraciones) con auto-migración. |
| **Protección contra Fuerza Bruta OTP** | 🔵 Regular (4.7) | 🟢 Blindado | **9.5 / 10** | **RESUELTO:** Códigos OTP hasheados con sal y límite de 5 intentos enforced a nivel de BD en Atlas. |
| **Permisos de Plataforma Android** | ⚪ Regular (7.0) | 🟢 Óptimo | **10.0 / 10** | **RESUELTO:** Eliminado `requestLegacyExternalStorage="true"`; scoped storage nativo. |
| **Validación de Entradas (NoSQLi)** | 🟢 Fuerte | 🟢 Fuerte | **9.5 / 10** | Filtros estrictos de operadores MongoDB (\$gt, \$ne, regex) y tiempo constante. |
| **Gestión de Ciclo de Vida de Salas** | 🟢 Fuerte | 🟢 Fuerte | **10.0 / 10** | Índices TTL automáticos y purga inmediata de salas vacías o expiradas. |
| **Gestión de Secretos & Credenciales** | 🔴 Crítico | 🟡 Mitigado | **7.5 / 10** | Pasos en Atlas ejecutados por el usuario; credenciales aisladas y purga de APKs viejos. |
| **Arquitectura de Conexión** | 🔴 Crítico | 🟡 Mitigado | **7.0 / 10** | RBAC aplicado en Atlas a base de datos `swipeflick`; arquitectura preparada para Backend BFF. |

---

## 2. MATRIZ DE RIESGOS Y ESTADO DE RESOLUCIÓN

| ID | Vulnerabilidad | Severidad | CVSS | Estado v1.26.0 | Resolución Implementada |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **V-01** | Arquitectura Directa Cliente a Atlas | **CRÍTICA** | 9.1 | 🟡 **Mitigado (RBAC)** | Privilegios restringidos en Atlas solo a `readWrite` en BD `swipeflick`. |
| **V-02** | Exposición Histórica de Credenciales | **CRÍTICA** | 8.6 | 🟢 **Resuelto** | Contraseña rotada en Atlas; releases viejas purgadas; enmascaramiento total en app. |
| **V-03** | Regla de Firewall (`0.0.0.0/0`) en Atlas | **ALTA** | 7.5 | 🟡 **Operativo** | Mitigado con RBAC estricto a nivel de usuario en Atlas. |
| **V-04** | Almacenamiento Plano `SharedPreferences` | **MEDIA-ALTA** | 6.8 | 🟢 **RESUELTO** | Implementado `flutter_secure_storage` con Android KeyStore (AES-256-GCM) y Keychain. |
| **V-05** | Ausencia de Ofuscación R8 y ProGuard | **MEDIA** | 5.3 | 🟢 **RESUELTO** | Activado R8 (`isMinifyEnabled`, `isShrinkResources`) y creado `proguard-rules.pro`. |
| **V-06** | Hashing Simple SHA-256 vs KDF Robusto | **MEDIA** | 5.0 | 🟢 **RESUELTO** | Implementado PBKDF2-HMAC-SHA256 (NIST SP 800-63B, 10.000 iteraciones) con auto-upgrade. |
| **V-07** | Códigos OTP en Claro y sin Límite en BD | **BAJA-MEDIA** | 4.7 | 🟢 **RESUELTO** | OTP almacenado como hash SHA-256 + sal, y límite de 5 intentos fallidos en MongoDB. |
| **V-08** | Parámetro `requestLegacyExternalStorage` | **BAJA** | 3.1 | 🟢 **RESUELTO** | Eliminado de `AndroidManifest.xml` adoptando Scoped Storage moderno. |

---

## 3. ANÁLISIS DETALLADO DE VULNERABILIDADES IDENTIFICADAS

### V-01: Arquitectura Directa Cliente-a-Base de Datos (Fat Client sin API REST)
* **Severidad:** CRÍTICA (CVSS: 9.1)
* **Control OWASP:** MASVS-ARCH-1, OWASP Mobile M1/M5
* **Archivos Involucrados:**  
  - [mongodb_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/mongodb_service.dart)
  - [room_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/room_service.dart)
* **Descripción Técnica:**  
  La aplicación móvil establece una conexión directa por socket TCP (puerto 27017) hacia el clúster cloud de MongoDB Atlas mediante el paquete `mongo_dart`. En este diseño de dos capas (Cliente <-> Base de Datos), **el cliente móvil asume el rol de backend**.
* **Impacto:**  
  1. No existe un mecanismo de autorización a nivel de fila o documento (Row-Level Security). Cualquier cliente que obtenga la cadena de conexión adquiere todos los permisos otorgados al usuario de la base de datos (`readWrite`).
  2. Un atacante puede ejecutar consultas directas desde un cliente MongoDB (mongosh o Python) para:
     - Modificar o eliminar la cuenta de cualquier usuario (`db.users.deleteOne({email: "..."})`).
     - Consultar correos electrónicos, nombres y hashes de contraseñas de todos los registrados.
     - Forzar el cierre o eliminación de salas activas de otros grupos.
* **Remediación Requerida:**  
  - *Mitigación Inmediata:* Configurar en MongoDB Atlas Database Access privilegios mínimos estrictos (RBAC) para el usuario de la app.
  - *Solución Definitiva:* Implementar una capa de Backend Intermedio (API REST / GraphQL o WebSockets) alojada en Render o Cloud Run que sea la única autorizada para hablar con MongoDB Atlas. La app móvil únicamente se autentica contra el backend mediante tokens JWT de sesión.

---

### V-02: Exposición Histórica y Ofuscación Débil de Secretos (XOR en Binario)
* **Severidad:** CRÍTICA (CVSS: 8.6)
* **Control OWASP:** MASVS-CRYPTO-1, MASVS-STORAGE-1
* **Archivos Involucrados:**  
  - [mongodb_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/mongodb_service.dart#L24-L41)
  - [brevo_email_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/brevo_email_service.dart#L14-L31)
  - [tmdb_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/tmdb_service.dart#L19-L31)
  - [build_apk.yml](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/.github/workflows/build_apk.yml#L49-L52)
  - [Dockerfile](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/Dockerfile#L25-L28)
* **Descripción Técnica:**  
  1. En versiones anteriores hasta la v1.24.0, la cadena de conexión de MongoDB (`mongodb+srv://joaquin1troncoso_db_user:...`) se desplegaba en texto plano en la interfaz de usuario en la pantalla de Perfil (Configuración Avanzada). Aunque en la v1.25.0 se eliminó este diálogo y se borraron las releases de GitHub, **la contraseña original sigue activa en el clúster de MongoDB Atlas si no se ha cambiado manualmente**.
  2. En el código actual, las credenciales por defecto se almacenan mediante arreglos de bytes ofuscados con XOR de 1 byte (`b ^ 0x3F` y `b ^ 0x5A`). La ofuscación XOR no constituye cifrado criptográfico; un analista puede extraer la cadena legible en segundos con un script trivial de una línea o usando el comando `strings` sobre `libapp.so`.
  3. En Flutter Web ([Dockerfile](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/Dockerfile)), las variables pasadas por `--dart-define` se compilan directamente en el archivo JavaScript `main.dart.js`, visible públicamente en el navegador con presionar F12.
* **Impacto:**  
  - Acceso total no autorizado a la base de datos de producción.
  - Abuso de la clave API de Brevo para envío no autorizado de correos o suplantación de identidad (phishing) a nombre de `joaquin1troncoso@gmail.com`.
  - Agotamiento de cuotas de servicios externos (Brevo y TMDB).
* **Remediación Requerida:**  
  - Rotar de inmediato la contraseña del usuario `joaquin1troncoso_db_user` en el panel web de MongoDB Atlas.
  - Generar una nueva API Key en el panel web de Brevo y revocar la anterior.
  - Al implementar el backend intermedio, retirar por completo los secretos del cliente móvil.

---

### V-03: Regla de Firewall Totalmente Abierta (`0.0.0.0/0`) en MongoDB Atlas
* **Severidad:** ALTA (CVSS: 7.5)
* **Control OWASP:** MASVS-NETWORK-1, CIS MongoDB Benchmark 2.1
* **Componente Afectado:** MongoDB Atlas Cloud -> Security -> Network Access
* **Descripción Técnica:**  
  Debido a que los teléfonos móviles se conectan desde redes celulares con direcciones IP dinámicas y variables, la consola de MongoDB Atlas exige configurar `0.0.0.0/0` ("Allow Access from Anywhere"). Esto elimina el aislamiento perimetral del motor de base de datos a nivel de capa de transporte (TCP).
* **Impacto:**  
  El puerto 27017 de tu clúster de base de datos se encuentra accesible desde cualquier computadora o botnet del mundo. Un atacante con las credenciales extraídas de un APK puede conectarse desde su casa sin restricción de red alguna.
* **Remediación Requerida:**  
  Una vez establecido el Backend Intermedio en Render o Google Cloud, configurar en Network Access de MongoDB Atlas **únicamente la dirección IP estática de salida del Backend**, eliminando definitivamente la regla `0.0.0.0/0`.

---

### V-04: Almacenamiento Local en Texto Plano (`SharedPreferences`)
* **Severidad:** MEDIA-ALTA (CVSS: 6.8)
* **Control OWASP:** MASVS-STORAGE-1, MASVS-STORAGE-2
* **Archivos Involucrados:**  
  - [auth_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/auth_service.dart#L41-L63)
  - [favorites_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/favorites_service.dart#L28-L60)
* **Descripción Técnica:**  
  La aplicación utiliza el paquete estándar `shared_preferences` para almacenar información de usuario (`swipeflick_current_user`), el hash de la contraseña (`swipeflick_current_user_pwd`), y listas de favoritos. En Android, `SharedPreferences` guarda los datos en un archivo XML plano en `/data/data/com.swipeflick.swipeflick/shared_prefs/FlutterSharedPreferences.xml`.
* **Impacto:**  
  En dispositivos donde el usuario tiene acceso root, o mediante aplicaciones con privilegios elevados o herramientas de respaldo forense, cualquier atacante local o malware puede leer directamente los datos de usuario y el hash almacenado.
* **Remediación Requerida:**  
  Reemplazar el guardado de datos confidenciales por `flutter_secure_storage`. Este paquete utiliza el subsistema seguro por hardware **Android KeyStore** (con cifrado AES-256-GCM y clave respaldada por hardware TEE/SE) en Android, y el **Keychain** en iOS. Además, se debe evitar guardar contraseñas o hashes en el dispositivo; únicamente deben almacenarse tokens de sesión temporales.

---

### V-05: Ausencia de Ofuscación R8/ProGuard y Firma Release con Llave Debug
* **Severidad:** MEDIA (CVSS: 5.3)
* **Control OWASP:** MASVS-RESILIENCE-1, MASVS-CODE-1
* **Archivos Involucrados:**  
  - [build.gradle.kts](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/android/app/build.gradle.kts#L27-L33)
* **Descripción Técnica:**  
  En el archivo de compilación Gradle de Android:
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("debug")
      }
  }
  ```
  1. El APK de release se firma con la clave de depuración genérica `debug.keystore`.
  2. No están activadas las banderas de minificación ni ofuscación de código de Android (`isMinifyEnabled = true`, `isShrinkResources = true`), ni se especifica un archivo `proguard-rules.pro`.
* **Impacto:**  
  - La descompilación con herramientas como Jadx, Bytecode Viewer o Ghidra es inmediata, revelando la estructura de clases, nombres de métodos y lógica de control.
  - La firma con llave de depuración impide la publicación en Google Play Store y alerta a soluciones antimalware (como Play Protect).
* **Remediación Requerida:**  
  - Generar un Keystore de producción (`release.jks`) y configurarlo en `build.gradle.kts` mediante variables de entorno o `key.properties`.
  - Habilitar R8 en el bloque release de `build.gradle.kts` junto con reglas de ProGuard específicas para Flutter y plugins nativos.

---

### V-06: Algoritmo Criptográfico de Contraseñas Rápido (SHA-256 vs Argon2id)
* **Severidad:** MEDIA (CVSS: 5.0)
* **Control OWASP:** MASVS-CRYPTO-1, NIST SP 800-63B
* **Archivos Involucrados:**  
  - [security_helper.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/core/utils/security_helper.dart#L38-L45)
* **Descripción Técnica:**  
  La aplicación procesa las contraseñas calculando un hash SHA-256 combinando una sal estática (`_appSecretPepper`), una sal dinámica (el correo del usuario) y la contraseña:  
  `sha256(pepper : salt : password : pepper)`.  
  Si bien el uso de sal y comparación en tiempo constante es una buena práctica, SHA-256 es una función criptográfica diseñada para ser ultrarrápida.
* **Impacto:**  
  En caso de una exfiltración de la colección `users`, un atacante con hardware moderno (GPUs o clusters ASIC) puede calcular más de 10.000 millones de hashes SHA-256 por segundo, facilitando ataques de fuerza bruta o tablas de contraseñas débiles.
* **Remediación Requerida:**  
  Migrar la derivación de contraseñas a funciones con factor de trabajo y memoria regulable (**Argon2id** o **bcrypt** con factor de coste >= 12), delegando este proceso preferentemente al servidor Backend.

---

### V-07: Códigos OTP Almacenados en Claro y Rate Limit Restringido al Cliente
* **Severidad:** BAJA-MEDIA (CVSS: 4.7)
* **Control OWASP:** MASVS-AUTH-2, NIST SP 800-63B
* **Archivos Involucrados:**  
  - [mongodb_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/mongodb_service.dart#L386)
  - [rate_limit_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/rate_limit_service.dart)
* **Descripción Técnica:**  
  1. Los códigos OTP generados (6 dígitos numéricos) se almacenan en texto plano en el campo `otpCode` del documento del usuario en MongoDB Atlas.
  2. La validación del límite de intentos (5 intentos fallidos y bloqueo exponencial) se gestiona en `RateLimitService` en el teléfono del usuario.
* **Impacto:**  
  Si alguien accede a la base de datos o envía comandos directos omitiendo la aplicación móvil, el límite de intentos del cliente no surte efecto, permitiendo ataques de fuerza bruta sobre el espacio de 1.000.000 de combinaciones del código de 6 dígitos.
* **Remediación Requerida:**  
  - Guardar el hash SHA-256 del código OTP en lugar del código en texto plano.
  - Agregar un contador `otpAttempts` en el documento del usuario en MongoDB; tras 5 intentos erróneos, invalidar el código automáticamente.

---

### V-08: Parámetro Heredado `android:requestLegacyExternalStorage="true"`
* **Severidad:** BAJA (CVSS: 3.1)
* **Control OWASP:** MASVS-PLATFORM-1
* **Archivos Involucrados:**  
  - [AndroidManifest.xml](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/android/app/src/main/AndroidManifest.xml#L13)
* **Descripción Técnica:**  
  El manifiesto de Android declara `android:requestLegacyExternalStorage="true"`. Este atributo se diseñó temporalmente para Android 10 (API 29) a fin de posponer la adopción de Scoped Storage. A partir de Android 11 (API 30+), el sistema operativo ignora esta bandera.
* **Impacto:**  
  Inconsistencia en políticas de almacenamiento y advertencias en verificaciones automáticas de seguridad de Google Play.
* **Remediación Requerida:**  
  Eliminar la bandera del manifiesto, ya que la aplicación utiliza correctamente `image_picker` con el permiso moderno `READ_MEDIA_IMAGES` para Android 13+.

---

## 4. CONTROLES Y FORTALEZAS DE SEGURIDAD YA IMPLEMENTADAS

Es fundamental destacar los controles defensivos implementados con éxito en la versión actual (v1.25.0):

1. **Defensa Estricta Anti-Inyección NoSQL ([SecurityHelper](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/core/utils/security_helper.dart#L58-L83)):**  
   Se implementó una lista negra y filtrado activo de palabras clave reservadas de MongoDB (`$gt`, `$gte`, `$ne`, `$regex`, `$where`, etc.) y validación de formato RFC 5321 para correos antes de ejecutar cualquier consulta.
2. **Mitigación de Timing Attacks ([_constantTimeCompare](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/core/utils/security_helper.dart#L118-L125)):**  
   La validación de hashes de contraseña se realiza mediante operaciones XOR acumuladas en tiempo constante, previniendo que un atacante deduzca la contraseña analizando el tiempo de respuesta.
3. **Cero Tráfico en Claro ([AndroidManifest.xml](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/android/app/src/main/AndroidManifest.xml#L11)):**  
   Se fijó `android:usesCleartextTraffic="false"`, bloqueando cualquier conexión HTTP insegura y forzando cifrado TLS/HTTPS.
4. **Bloqueo de Extracción por Copias de Seguridad ([AndroidManifest.xml](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/android/app/src/main/AndroidManifest.xml#L12)):**  
   Se fijó `android:allowBackup="false"`, evitando la extracción de datos de la app mediante la herramienta de desarrollo `adb backup`.
5. **Auto-Purga y Expiración en Base de Datos ([mongodb_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/mongodb_service.dart#L215-L315)):**  
   Implementación de índices nativos TTL en MongoDB Atlas (`ttl_rooms_expires_at_date` y `ttl_unverified_30min`) para asegurar la destrucción automática de salas y cuentas no activadas en un máximo de 1 hora y 30 minutos respectivamente.
6. **Eliminación de la UI Técnica y Purga de Releases Históricas ([fa37247](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto)):**  
   Se removió por completo el acordeón técnico del perfil del usuario y se eliminaron de GitHub Releases las 14 versiones de APK anteriores que contenían diálogos de credenciales.

---

## 5. PLAN DE ACCIÓN Y REMEDIACIÓN PASO A PASO

Para elevar la calificación de seguridad de SwipeFlick al estándar bancario/comercial (9.5+ / 10), sigue este plan de tres fases:

```mermaid
flowchart TD
    subgraph Fase1["FASE 1: Inmediata (Hoy en Consolas Cloud)"]
        A1["1.1 Rotar contraseña de usuario en MongoDB Atlas"] --> A2["1.2 Restringir Roles en Atlas (RBAC a swipeflick)"]
        A2 --> A3["1.3 Rotar API Key en Brevo"]
    end

    subgraph Fase2["FASE 2: Corto Plazo (Código Flutter & Android)"]
        B1["2.1 Integrar flutter_secure_storage (Android Keystore)"] --> B2["2.2 Habilitar R8 / ProGuard y Firma Release en Gradle"]
        B2 --> B3["2.3 Eliminar requestLegacyExternalStorage en Manifest"]
        B3 --> B4["2.4 Hashear OTP y contador de intentos en Atlas"]
    end

    subgraph Fase3["FASE 3: Arquitectura Definitiva (BFF Seguro)"]
        C1["3.1 Desplegar API REST Ligera (Node/Python/Dart en Render)"] --> C2["3.2 Mover URI de Atlas y Brevo API Key al Backend"]
        C2 --> C3["3.3 Limitar Firewall Atlas SOLO a la IP del Backend"]
        C3 --> C4["3.4 App Móvil autentica con JWT vía HTTPS"]
    end

    Fase1 --> Fase2
    Fase2 --> Fase3
```

---

### FASE 1: ACCIONES INMEDIATAS (Menos de 1 hora - En tus Paneles Web Cloud)

#### Paso 1.1: Rotar la Contraseña en MongoDB Atlas
1. Ingresa a [MongoDB Atlas](https://cloud.mongodb.com/).
2. En el menú lateral izquierdo, haz clic en **Database Access** (bajo la sección Security).
3. Localiza el usuario `joaquin1troncoso_db_user` y haz clic en **Edit**.
4. Haz clic en **Edit Password** -> Selecciona **Autogenerate Secure Password** (o ingresa una contraseña fuerte de 24+ caracteres alfanuméricos y símbolos).
5. Copia la nueva contraseña en un gestor seguro de contraseñas.
6. Haz clic en **Update User**.
> [!IMPORTANT]
> Al cambiar esta contraseña, todas las versiones anteriores de la app que alguien haya descargado quedarán instantáneamente desconectadas de tu base de datos y ya no podrán acceder ni manipularla.

#### Paso 1.2: Restringir Roles de Acceso (RBAC) en MongoDB Atlas
1. En la misma pantalla de edición de `joaquin1troncoso_db_user`, desplázate a **Database User Privileges**.
2. Asegúrate de que **NO** tenga asignados roles como `atlasAdmin`, `dbAdminAnyDatabase` ni `readWriteAnyDatabase`.
3. Selecciona **Built-in Role** -> **Only read and write to specific databases**.
4. Asigna el rol `readWrite` únicamente sobre la base de datos `swipeflick`.
5. Haz clic en **Update User**.

#### Paso 1.3: Rotar la Clave de API de Brevo (Sendinblue)
1. Ingresa a [Brevo Dashboard](https://app.brevo.com/).
2. Haz clic en tu perfil (arriba a la derecha) -> **SMTP & API** -> Pestaña **Claves API**.
3. Haz clic en **Generar una nueva clave de API**, nómbrala `SwipeFlick-Prod-2026`.
4. Copia la nueva clave generada.
5. Elimina o revoca la clave antigua que comenzaba con `xkeysib-...`.

---

### FASE 2: BLINDAJE DEL CLIENTE MÓVIL (Corto Plazo - Código Flutter y Android)

#### Paso 2.1: Migrar a Almacenamiento Seguro por Hardware (`flutter_secure_storage`)
1. Agregar el paquete en [pubspec.yaml](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/pubspec.yaml):
   ```yaml
   dependencies:
     flutter_secure_storage: ^9.2.2
   ```
2. Reemplazar la persistencia de sesión en [auth_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/auth_service.dart):
   ```dart
   import 'package:flutter_secure_storage/flutter_secure_storage.dart';

   class AuthService extends ChangeNotifier {
     final _secureStorage = const FlutterSecureStorage(
       aOptions: AndroidOptions(encryptedSharedPreferences: true),
     );
     // Usar _secureStorage.write(key: ..., value: ...) para credenciales
   }
   ```

#### Paso 2.2: Configurar Ofuscación R8 y ProGuard en Android
1. En [build.gradle.kts](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/android/app/build.gradle.kts), activar minificación y encogimiento de recursos en release:
   ```kotlin
   buildTypes {
       release {
           isMinifyEnabled = true
           isShrinkResources = true
           proguardFiles(
               getDefaultProguardFile("proguard-android-optimize.txt"),
               "proguard-rules.pro"
           )
           // Configurar firma con Keystore de release en lugar de debug
           // signingConfig = signingConfigs.getByName("release")
       }
   }
   ```
2. Crear el archivo `Proyecto/android/app/proguard-rules.pro` con exclusiones necesarias para Flutter y los plugins usados:
   ```pro
   # Flutter Wrapper
   -keep class io.flutter.app.** { *; }
   -keep class io.flutter.plugin.** { *; }
   -keep class io.flutter.util.** { *; }
   -keep class io.flutter.view.** { *; }
   -keep class io.flutter.** { *; }
   -keep class io.flutter.plugins.** { *; }
   -dontwarn io.flutter.embedding.**
   ```

#### Paso 2.3: Limpieza de Manifiesto Android
1. En [AndroidManifest.xml](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/android/app/src/main/AndroidManifest.xml#L13), eliminar la línea:
   ```xml
   android:requestLegacyExternalStorage="true"
   ```

#### Paso 2.4: Hashear Códigos OTP y Limitar Intentos en Base de Datos
1. En [mongodb_service.dart](file:///c:/Users/Nero/Desktop/Proyectos/Proyecto%20app%20peliculas/Proyecto/lib/data/services/mongodb_service.dart), al generar el código OTP para activación o recuperación de contraseña, almacenar el hash:
   ```dart
   final otpHash = SecurityHelper.hashPassword(otpCode, userSalt: safeEmail);
   modifier.set('otpHash', otpHash);
   modifier.set('otpAttempts', 0);
   ```
2. En `verifyAndActivateUser`, incrementar el contador `otpAttempts`. Si `otpAttempts >= 5`, ejecutar un `unset` del código e invalidarlo inmediatamente.

---

### FASE 3: ARQUITECTURA DEFINITIVA A MEDIANO PLAZO (Backend BFF)

La solución definitiva que resuelven las vulnerabilidades **V-01**, **V-02** y **V-03** de raíz consiste en desacoplar el cliente móvil de la base de datos:

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as Teléfono Móvil (SwipeFlick App)
    participant Backend as Backend API (Render / Cloud Run)
    participant Atlas as MongoDB Atlas Cluster
    participant Brevo as API de Brevo
    participant TMDB as API de TMDB

    Note over Usuario,Backend: Comunicación 100% Cifrada (HTTPS + JWT)
    Usuario->>Backend: POST /auth/login {email, password}
    Backend->>Atlas: Validar credenciales (Argon2id)
    Atlas-->>Backend: OK
    Backend-->>Usuario: Retorna JWT Session Token (Expiración 7 días)

    Usuario->>Backend: POST /rooms/create (Authorization: Bearer JWT)
    Note over Backend: Valida identidad del usuario vía token
    Backend->>Atlas: db.rooms.insertOne(...)
    Atlas-->>Backend: OK
    Backend-->>Usuario: Retorna Room {code: "SF89K2"}

    Note over Backend,Atlas: Red Privada / IP Whitelist Estricta (Puerto 27017 CERRADO a Internet)
    Note over Usuario,Atlas: El teléfono NUNCA conoce la contraseña ni la URL de Atlas
```

#### Ventajas Clave de esta Arquitectura:
1. **Secretos 100% Ocultos:** La cadena de conexión a MongoDB y la API Key de Brevo residen exclusivamente como variables de entorno seguras en el servidor de Render. Ningún APK contiene credenciales.
2. **Cierre de Firewall en Atlas:** En Network Access de MongoDB Atlas se elimina `0.0.0.0/0` y se coloca únicamente la IP fija del Backend en Render.
3. **Control de Acceso Total (RBAC):** El servidor valida que el usuario solo pueda modificar sus propios datos, eliminando cualquier riesgo de que un cliente altere salas o perfiles ajenos.
4. **Protección contra Abuso:** El Rate Limiting se ejecuta en el servidor (usando middleware tipo express-rate-limit o slowapi), haciendo imposible que un atacante evada los bloqueos.

---

## 6. CONCLUSIÓN

La aplicación SwipeFlick cuenta actualmente con una base sólida de protecciones contra inyecciones NoSQL, temporización y fugas locales básicas tras los cambios de la versión 1.25.0. 

Ejecutando de inmediato la **Fase 1** (rotación de contraseñas de Atlas y Brevo, y ajuste de roles RBAC en las consolas web), se anula por completo el riesgo de cualquier fuga ocurrida en versiones anteriores. Posteriormente, la implementación de la **Fase 2** (Secure Storage y ProGuard) y la **Fase 3** (Backend API Intermedio) consolidará la arquitectura con los más altos estándares de la industria móvil.

---
*Informe elaborado por el Equipo de Auditoría de Ciberseguridad y Arquitectura de Software para SwipeFlick.*
