#!/bin/bash

if [ -f ".env" ]; then
    . ".env"
fi

tempfile=$( mktemp )
trap 'rm -f $tempfile' EXIT

lua LocaleParser.lua > L.lua || exit 1

result=$( curl -sS -0 -X POST -w "%{http_code}" -o "$tempfile" -H "X-Api-Token: $CF_API_KEY" -F "metadata={ language: \"enUS\", missing-phrase-handling\": \"DeletePhrase\" }" -F "localizations=<L.lua" "https://wow.curseforge.com/api/projects/67669/localization/import") || exit 1

case $result in
    200) echo "Localization updated." ;;
    *)
	echo "$result"
	[ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" | jq --raw-output '.errorMessage' "$tempfile"
	exit 1
	;;
esac
