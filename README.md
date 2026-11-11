# SIEGER fürs iPhone — Entwicklungsstand 0.1

Native SwiftUI-App für iOS 16 oder neuer; Zielgerät des Nutzers: iOS 27.0.1. Ein kostenloser Gerätebuild für persönliche Signierung ist vorbereitet. Der tatsächliche macOS-Build und Gerätetest müssen separat belegt werden; siehe `BUILD-STATUS.md`.

## Enthalten

- Watchlist mit Suche, Kurswährung, Tagesänderung, Kursquelle und tatsächlichem Kurszeitpunkt.
- Bis zu 260 abgeschlossene Tageskerzen, GD20/GD50/GD200 aus der ganzen vorhandenen Historie vor dem Ausschnitt.
- Unternehmensnamen in Schlagzeilen als direkte Treffer; unklare Feedtreffer getrennt. Keine Inhaltsverifikation.
- Nachrichtenfilter Heute/7 Tage/Alle nach Veröffentlichung, und sichtbare Abrufzeit/Fehler.
- JSON-Import aus Dateien; optional manueller Abruf eines bewusst freigegebenen HTTPS-Snapshots. Lokaler Offlinebestand.
- Öffentliche Kurse direkt per Watchlist-Aktualisierung; im einzelnen Wert öffnet „Aktualisieren“ Tageshistorie und News direkt über Yahoo/Google-RSS. Ein eigener Server oder ein laufender Windows-PC ist dafür nicht notwendig. Anbieterzugriff ist inoffiziell und kann scheitern; alte Daten bleiben mit Hinweis erhalten.
- Lokaler Bootstrap der persönlichen Watchlist wird erst NACH dem Cloud-Build eingebettet. GitHub erhält weder Watchlist noch Depot-/Anmeldedaten.

Die erste Version ist ein lesender Recherche-Client. Kein Trading-212-Login, Papierbuchungen, KI-Login oder Strategieausführung auf dem Telefon. Kein gehosteter Datendienst und keine Push-Benachrichtigungen eingerichtet. Die Desktop-Funktionen werden nicht als bereits vollständig portiert dargestellt.

## Daten vorbereiten

Aus dem SIEGER-Ordner:

```powershell
python -B mobile_export.py --private 'PFAD/ZUM/BESTEHENDEN/SIEGER/private' --out 'research.json'
```

Der Export liest nur öffentliche Recherchefelder aus Watchlist, Kurs-/Historien-/News-Caches. Er übernimmt keine Depotmengen, Einstandspreise, Budgetwerte oder Anmeldedaten. Die Watchlist ist dennoch persönlich: Datei nur bewusst weitergeben. `exported_at` ist der Exportzeitpunkt, keine Bestätigung eines neuen Datenabrufs. Fehlende Caches bleiben leer.

Alternativ zum eingebetteten Bootstrap `research.json` auf das iPhone übertragen (z. B. iCloud Drive) und in SIEGER über „Recherchedaten importieren“ öffnen. Danach lädt die App aktuelle öffentliche Daten selbst. Die Werte/Zuordnungen selbst werden durch einen neuen Import geändert. Keinen gesamten private-Ordner als Webverzeichnis freigeben.

## Auf einem Mac prüfen

1. Xcode 16 oder neuer installieren, `SIEGER.xcodeproj` öffnen.
2. Unter Signing & Capabilities das eigene Team wählen und eine eigene eindeutige Bundle-ID einstellen.
3. Zuerst im iPhone-Simulator bauen. Alternativ CLI: `xcodebuild -project SIEGER.xcodeproj -scheme SIEGER -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`.
4. JSON importieren, Suche, Kurszeit, GD-Linien, leere/unklare News, Heute-Filter und Offline-Neustart prüfen.
5. Auf dem eigenen iPhone testen; anschließend App-Icon, Accessibility-/Geräte-QA und die Datenversorgung fertigstellen, bevor eine Beta verteilt wird.

## Kostenloser Build und persönliche Installation

1. Nur diesen iOS-Quellordner in ein separates GitHub-Projekt übernehmen. `SIEGER/Bootstrap.json`, `.build`, `out` und IPA-Dateien sind ausgeschlossen.
2. GitHub-Kostenfreigabe vor einem privaten Runner-Lauf kontrollieren: ausschließlich enthaltenes Kontingent mit bestätigter Ausgabensperre, keine kostenpflichtige Überschreitung. Die manuelle Workflow-Datei garantiert allein keine Kontokostensperre. Ist der Kontostand nicht prüfbar, keinen privaten Mac-Runner starten. Ein öffentliches Projekt mit Standard-Runner ist laut GitHub kostenlos, benötigt aber vorher eine bewusste Freigabe des Quellcodes.
3. Workflow „SIEGER iPhone“ manuell starten. Er erzeugt das Icon aus dem bestehenden Vektorentwurf, kompiliert native Logikprüfungen, baut für ein echtes Gerät und verpackt `out/SIEGER-unsigned.ipa`. Artefakte werden einen Tag aufbewahrt. Keine Apple-Zertifikate, keine automatischen/periodischen Läufe und keine App-Store-Uploads.
4. Paket herunterladen. Hier auf Windows mit `python scripts/personalize_ipa.py --ipa SIEGER-unsigned.ipa --snapshot research.json --out SIEGER-iPhone.ipa` die eigene Watchlist einbetten. Es wird noch nicht signiert.
5. Mit dem offiziellen kostenlosen iloader für Windows und dem eigenen kostenlosen Apple-Konto persönlich signieren und auf dem verbundenen iPhone installieren. iTunes/Apple-Gerätetreiber und Bestätigung des Vertrauens/Entwicklermodus am iPhone sind erforderlich. Passwörter ausschließlich selbst im offiziellen Anmeldefenster eingeben.
6. Installation spätestens alle sieben Tage erneuern. Mit SideStore ist eine Erneuerung am Telefon möglich; für iOS 27.0.1 ist jedoch ein offener Startabsturz dokumentiert. Deshalb direkte iloader-Installation als Rückfallweg bereithalten. Gerätekompatibilität nicht ohne echten Test behaupten.

Kostenlose Installation ist ein persönlicher Testweg mit Einschränkungen, keine öffentliche App-Store-Veröffentlichung.

## Andere Verteilungswege

- Direkt über Xcode: persönlicher Gerätetest mit kostenlosem Apple-Konto möglich, mit zeitlich begrenzter Signierung und regelmäßiger Erneuerung.
- TestFlight: private Beta-Einladung statt öffentlichem App-Store-Angebot. Erfordert Apple Developer Program; Builds sind bis zu 90 Tage testbar. Apple kann eine Beta-Prüfung verlangen.
- App Store: optionale spätere öffentliche Verteilung nach Apples Prüfung.

Für diese Arbeit gilt die ausdrückliche Null-Euro-Vorgabe. Keine bezahlte Developer-Mitgliedschaft, keine kostenpflichtigen Cloud-Läufe oder Zertifikate einrichten. Bei der persönlichen Installation signiert iloader auf Windows; der Mac wird nur zum Kompilieren benötigt.

Quellen, geprüft 11.11.2026: https://developer.apple.com/programs/ und https://beta.itunes.apple.com/ sowie https://developer.apple.com/help/account/basics/about-your-developer-account/.

Weitere geprüfte Quellen: https://iloader.app/, https://docs.sidestore.io/docs/installation/prerequisites, https://github.com/SideStore/SideStore/issues/1630 und https://docs.github.com/en/billing/concepts/product-billing/github-actions.
