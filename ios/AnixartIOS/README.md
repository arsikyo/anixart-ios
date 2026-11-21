# Anixart iOS (Swift 6 / SwiftUI)

Полноценный iOS-клиент на SwiftUI (iOS 17+), спроектированный по контрактам Android APK `com.swiftsoft.anixartd` (`10.5`, `versionCode 26101718`).

## Реализованные модули

- **Сеть и зеркала (`Core/`)**:
  - `APIClient` (`URLSession` + `async/await`, `convertFromSnakeCase` / `convertToSnakeCase`, form-encoding с корректным экранированием, токен в query, заголовки `API-Version` / `X-Long-Code`, коды ошибок Anixart API).
  - `MirrorDiscoveryService`: цепочка актуализации адресов (`api-s.anixsekai.com`, `config/urls`, `config/toggles`, `https://anixhelper.github.io/pages/urls.json`).
  - `KeychainStore`: безопасное хранение токена сессии и ID профиля.
- **Авторизация (`Services/OAuthService.swift`, `Features/Auth/`)**:
  - Вход, регистрация с подтверждением кода по email, восстановление пароля.
  - Web OAuth-потоки через `ASWebAuthenticationSession` (VK ID PKCE, Яндекс ID) и встроенный `WKWebView` (`TelegramOAuthSheet` с PKCE и перехватом `tg://`).
- **Видеоплеер и парсеры (`Services/VideoParserService.swift`, `Features/Player/`)**:
  - Нативный `AVPlayer` с передачей `Referer`, `Cookie` и `User-Agent` заголовков и выбором качества (`2160p`..`360p`).
  - Парсеры: Kodik (HLS 360p–1080p), VK Video (360p–2160p + HLS), StudioMir, AniLibria, RuTube (M3U8), Sibnet, Mail.ru, OK.ru, Myvi, Allvideo, SovetRomantica + встроенный `WKWebView` fallback.
- **Экраны (`Features/`)**:
  - Главная (Сейчас смотрят, Рекомендации, Обсуждаемое, Интересное, Случайный релиз).
  - Обзор: Расписание по дням недели, Коллекции, История просмотра.
  - Закладки: Смотрю / В планах / Просмотрено / Отложено / Брошено / Избранное.
  - Поиск с фильтром (`FilterRequest`: жанры, год, тип, статус, возраст, сортировка).
  - Детальная карточка релиза: озвучки -> источники -> серии -> отметка просмотра, оценка, закладки, связанные релизы и комментарии.
  - Профиль, друзья, внутриигровые уведомления (без APNs) и настройки зеркал API.

## Сборка `.ipa` без Mac (через GitHub Actions)

1. Залей репозиторий на GitHub (включая `.github/workflows/ios-build.yml` и `ios/AnixartIOS`).
2. Запусти workflow **Build AnixartIOS IPA** вручную во вкладке Actions (или при push).
3. Скачай готовый архив с `AnixartIOS.ipa` из Artifacts и установи на iPhone через **Sideloadly** или **AltStore**.
