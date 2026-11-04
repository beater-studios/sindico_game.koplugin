#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
name=sindico_game.koplugin
for file in LICENSE LICENSE-CONTENT NOTICE; do
    if [ ! -f "$file" ]; then
        echo "$file não encontrado: o pacote não pode ser gerado sem ele." >&2
        exit 1
    fi
done
rm -rf dist
mkdir -p "dist/stage/$name"
cp -R _meta.lua main.lua LICENSE LICENSE-CONTENT NOTICE sindico_game data assets "dist/stage/$name/"
find dist/stage \( -name '._*' -o -name '.DS_Store' \) -delete
(cd dist/stage && zip -qrX "../$name.zip" "$name")
rm -rf dist/stage
(cd dist && shasum -a 256 "$name.zip" > "$name.zip.sha256")
echo "Pacote gerado: dist/$name.zip"
