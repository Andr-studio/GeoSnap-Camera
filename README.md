# GeoSnap Cam 📸📍

**GeoSnap Cam** es una aplicación de cámara avanzada para Flutter diseñada para profesionales que requieren precisión geográfica y una experiencia de usuario de primer nivel. Inspirada en la estética **Samsung One UI 8.5**, combina potencia técnica con un diseño minimalista y ergonómico.

## ✨ Características Principales

- **Estética One UI 8.5:** Interfaz premium con desenfoques en tiempo real (glassmorphism), tipografía Roboto optimizada y controles ergonómicos diseñados para uso con una sola mano.
- **Gestión Pro de Permisos:** Flujo inteligente compatible con **Android 14 (API 34+)**, manejando permisos granulares de fotos, videos, ubicación precisa y sensores de hardware sin bloqueos.
- **Rendimiento de Cámara:**
  - Detección automática de todos los sensores físicos (Ultra Wide, Wide, Telephoto).
  - Cambio fluido entre cámaras frontal y trasera.
  - Control de zoom optimizado (.5x a 3x).
- **Experiencia Sensorial:** Respuesta hática (vibración) integrada en el cambio de modos y controles de zoom para una sensación física y táctil de alta gama.
- **Geolocalización Inteligente:** Preparada para la integración de marcas de agua con datos de latitud, longitud, dirección y clima (Próximamente).

## 🛠️ Stack Tecnológico

- **Framework:** [Flutter](https://flutter.dev)
- **Cámara:** [Camerawesome](https://pub.dev/packages/camerawesome) (Control de hardware de bajo nivel)
- **Permisos:** [Permission Handler](https://pub.dev/packages/permission_handler)
- **Persistencia:** [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **Diseño:** Custom UI con Material 3 y componentes inspirados en One UI.

## 🚀 Comenzando

### Requisitos Previos

- Flutter SDK `>=3.10.0`
- Android SDK (API 34+ recomendado para pruebas de permisos granulares)
- Un dispositivo físico (recomendado para probar sensores de cámara y GPS)

### Instalación

1. Clona el repositorio:
   ```bash
   git clone https://github.com/tu-usuario/geosnap_cam.git
   ```
2. Instala las dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

## 📸 Screenshots

*(Espacio reservado para capturas de pantalla de la interfaz One UI 8.5)*

---
Desarrollado para capturar el mundo con precisión.
