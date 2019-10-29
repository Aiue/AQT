#!/bin/bash

if [ -f ".env" ]; then
    . ".env"
fi

# Import current localization data.
curl -s -H "X-API-Token: $CF_API_KEY" https://wow.curseforge.com/api/projects/67669/localization/export?true-if-values-equals-key=true\&escape-non-ascii-characters=true > LocaleCache

tempfile=$( mktemp )
trap 'rm -f $tempfile' EXIT

NEW_KEYS=$( lua LocaleParser.lua || exit 1 )

echo "Found ${NEW_KEYS} new localization key(s)."

if [ "$NEW_KEYS" != "0" ]; then
    result=$( curl -sS -0 -X POST -w "%{http_code}" -o "$tempfile" -H "X-Api-Token: $CF_API_KEY" \
	-F "metadata={ \"language\": \"enUS\", \"missing-phrase-handling\": \"DeletePhrase\", }" \
	-F "localizations=<L.lua" "https://wow.curseforge.com/api/projects/67669/localization/import") || exit 1

    case $result in
	200) echo "Localization updated." ;;
	*)
	    echo "$result"
	    [ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" | jq --raw-output '.errorMessage' "$tempfile"
	    exit 1
	    ;;
    esac

    if [ -n "$WEBHOOK" ]; then
	curl -s -H "Content-Type: application/json" -X POST -d "{\"username\": \"Localization-Updates\", \"content\": \"${NEW_KEYS} new localization keys added to CurseForge localization system.\"}" $WEBHOOK
    fi
fi
