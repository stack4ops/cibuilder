# debian-build

Blueprint Repository für das automatiserte Bauen, Testen und Speichern Debian-basierter Images in der zentralen Container-Registry des HRZ.

Nach Anpassung der Image Quell- und Zielangaben, der Credentials als CI-Variablen sowie der Bauanleitung im Containerfile, können automatische Aktualisierungen der Images eingerichtet werden.

**main** Branch:

- Bei aktuellerem Basis-Image (z.B. :latest) wird das Image neu gebaut, getestet und gespeichert

- hat man einen regulären Ausdruck für ein entprechendes Minor-Tag Muster angegeben, wird bei jedem Bauvorgang der passende Minortag aus der registry gelesen und beim Speichern bekommt das Image den zusätzlichen Minortag. Verschiebt sich z.B. der "latest" Tag im Basis-Image und das eigene Image wird dadurch neu gebaut und ebenfalls mit "latest" getagged, bleibt das ältere Image über den Minortag erhalten.

**upgrade** Branch:

- Der upgrade Branch überprüft, ob Debian Paketaktualisierungen zur Verfügung stehen und führt die Aktualisierungen aus, testet das Image und speichert dieses in einem lösgelösten Tag-Stream "upgrade"

## 

This Containers build process is fueled by [autobuilderx](https://gitlab.com/eqsoft-appstack/autobuilderx)
