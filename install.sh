#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/dist/WebMediaDownloader.app"
DESTINATION="/Applications/WebMediaDownloader.app"
OLD_APP="/Applications/WebPicDownload.app"

if [ ! -d "$APP_SOURCE" ]; then
    echo "Fehler: $APP_SOURCE wurde nicht gefunden."
    exit 1
fi

echo "Installiere WebMediaDownloader nach /Applications..."
if [ -d "$OLD_APP" ]; then
    echo "Entferne frühere WebPicDownload.app aus /Applications..."
    rm -rf "$OLD_APP"
fi

if [ -d "$DESTINATION" ]; then
    echo "Vorherige Version in /Applications wird aktualisiert..."
    rm -rf "$DESTINATION"
fi

cp -R "$APP_SOURCE" /Applications/
echo "Erfolgreich installiert! WebMediaDownloader befindet sich jetzt in /Applications."
