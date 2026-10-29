#!/bin/zsh
# Cuts a release: bumps VERSION, commits, builds, zips, tags, and (with
# --publish) pushes and creates the GitHub release that running copies of
# Purr check for updates.
#
#   scripts/release.sh 1.2.0             # prepare everything locally
#   scripts/release.sh 1.2.0 --publish   # ...and push + create the GitHub release
#
# Optional:
#   PURR_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"  sign for distribution
#   NOTARY_PROFILE=purr   notarize with a profile saved by `xcrun notarytool store-credentials`
set -e
cd "${0:A:h}/.."

NEW=$1
PUBLISH=$2
[[ "$NEW" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "usage: scripts/release.sh X.Y.Z [--publish]"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Working tree is not clean; commit or stash first."; exit 1; }
[[ "$(git branch --show-current)" == main ]] || { echo "Release from main (currently on $(git branch --show-current))."; exit 1; }
git fetch -q origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "Local main differs from origin/main; pull or push first."; exit 1; }
CURRENT=$(tr -d ' \n' < VERSION)
if [[ "$NEW" != "$CURRENT" && "$(printf '%s\n%s\n' "$CURRENT" "$NEW" | sort -V | tail -1)" != "$NEW" ]]; then
    echo "$NEW is lower than the current version $CURRENT."; exit 1
fi
git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null && { echo "Tag v$NEW already exists. If only the GitHub release is missing, run the gh command below by hand."; exit 1; }
grep -q "^## \[$NEW\]" CHANGELOG.md || { echo "Add a '## [$NEW] - $(date +%F)' section to CHANGELOG.md first."; exit 1; }
if [[ -n "$NOTARY_PROFILE" && -z "$PURR_SIGN_IDENTITY" ]]; then
    echo "Notarizing needs PURR_SIGN_IDENTITY (a Developer ID certificate)."; exit 1
fi

./test.sh
scripts/check-strings.sh

echo "$NEW" > VERSION
git diff --quiet VERSION || git commit -qm "Release v$NEW" VERSION
./build.sh

mkdir -p dist
ZIP=dist/Purr-$NEW.zip
rm -f $ZIP
ditto -c -k --keepParent Purr.app $ZIP

if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit $ZIP --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple Purr.app
    rm -f $ZIP && ditto -c -k --keepParent Purr.app $ZIP
fi

SHA=$(shasum -a 256 $ZIP | cut -d' ' -f1)
REPO=$(/usr/libexec/PlistBuddy -c "Print :PurrRepository" Purr.app/Contents/Info.plist)
sed -e "s/{{VERSION}}/$NEW/g" -e "s/{{SHA256}}/$SHA/g" -e "s#{{REPO}}#$REPO#g" packaging/purr.rb.template > dist/purr.rb
# Release notes = this version's CHANGELOG section.
awk -v v="$NEW" '/^## \[/{p = index($0, "[" v "]") > 0; next} p' CHANGELOG.md > dist/notes.md

git tag -a "v$NEW" -m "Purr v$NEW"
echo
echo "Built $ZIP (sha256 $SHA)"
echo "Homebrew cask: dist/purr.rb"

if [[ "$PUBLISH" == --publish ]]; then
    git push --atomic origin main "v$NEW"
    gh release create "v$NEW" $ZIP --title "Purr v$NEW" --notes-file dist/notes.md
    echo "Published. Running copies of Purr will notify within a day."
else
    echo "Not published. When ready:"
    echo "  git push --atomic origin main v$NEW"
    echo "  gh release create v$NEW $ZIP --title \"Purr v$NEW\" --notes-file dist/notes.md"
fi
