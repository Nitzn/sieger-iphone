# iPhone-Buildstatus

Stand: 11.11.2026. Zielgerät laut Nutzer: iOS 27.0.1. Verbindliche Vorgabe: keine zusätzlichen Kosten.

## Belegt

- 127 Python-Tests erfolgreich, einschließlich News-Zuordnung, veralteter Mobilexporte und Geräte-/Simulatorpaket-Unterscheidung.
- Kostenloser manueller GitHub-Mac-Build vorbereitet; Action-Referenzen anhand der offiziellen GitHub-API geprüft und auf vollständige Commit-Hashes fixiert.
- Native Prüfungen für JSON-Roundtrip, Newszuordnung, Stale-Kennzeichnung, RSS und Importlimit vorbereitet.
- Persönliche Watchlist wird nur lokal nach dem Build eingebettet; Cloudquellen enthalten keinen Bootstrap/keine Depot- oder Anmeldedaten.
- GitHub CLI 2.103.3 anhand offizieller SHA256-Prüfsumme geprüft, lokal bereitgestellt. Anmeldung wurde gestartet und muss vom Nutzer bestätigt werden.
- iloader 2.4.1 aus dem offiziellen Repository geladen; MSI-SHA256 8bfe528197db1b82f51fbcdb74652f355e7ae025e616e07a10a819d60f7d2691 mit GitHub-Assetdigest verglichen; administrativ in den Arbeitsordner extrahiert. MSI hat keine Authenticode-Signatur; keine Umgehung von Sicherheitsdialogen oder Änderung der Ausführungsrichtlinie.
- Unabhängiger Prüfer: begrenzte Datei-/Netzwerkreads und Stale-Warnungen nachgeprüft; weiterer Kurs-Stale-Befund korrigiert und native Regression ergänzt.

## Noch nicht belegt / erforderlich

- GitHub-Anmeldung, privates Repository und bestätigte Null-Euro-Kostensperre.
- Erfolgreiche native Kompilierung/Swift-Prüfungen und tatsächliches IPA-Artefakt. Ein Xcode-Projekt oder ZIP ist noch keine gebaute App.
- Persönliche Signierung und Installation auf dem verbundenen iPhone; Apple-Anmeldung, Gerätevertrauen und Entwicklermodus muss der Nutzer selbst bestätigen.
- Direkte Kurse/News auf dem iPhone und Offline-/Gerätetest.
- SideStore ist für dieses Gerät ungeprüft. Offener Fehlerbericht #1630 enthält Startabstürze unter iOS 27.0.1. Deshalb kein Erfolg versprochen und iloader-Direktinstallation als Alternative vorgesehen.

## Quellen

- https://github.com/SideStore/SideStore/issues/1630
- https://iloader.app/
- https://github.com/nab138/iloader/releases/tag/v2.4.1
- https://docs.github.com/en/billing/concepts/product-billing/github-actions
- https://docs.github.com/en/billing/how-tos/set-up-budgets

Status nach echtem Build/Gerätetest aktualisieren; keine technische Vorbereitung als Installation ausgeben.
