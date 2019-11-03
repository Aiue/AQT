#!/bin/bash

curl -s -H "Content-Type: application/json" -X POST -d "{\"username\": \"Release\", \"content\": \"New release: [AQT-${TRAVIS_TAG}](<https://github.com/Aiue/AQT/releases/tag/${TRAVIS_TAG}>). Get it on [CurseForge](<https://www.curseforge.com/wow/addons/aqt>) or [WoWInterface](<https://www.wowinterface.com/downloads/fileinfo.php?id=25280>)\\\!\n\n$(<.release/CHANGELOG.md)\"}" $WEBHOOK

