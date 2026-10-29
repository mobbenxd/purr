#!/bin/zsh
# Runs the test suite. With Xcode installed `swift test` works on its own;
# with only the Command Line Tools, Swift Testing needs its framework paths.
set -e
cd "${0:A:h}"

DEV=/Library/Developer/CommandLineTools/Library/Developer
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools* && -d $DEV/Frameworks/Testing.framework ]]; then
    exec swift test \
        -Xswiftc -F$DEV/Frameworks -Xlinker -F$DEV/Frameworks \
        -Xlinker -rpath -Xlinker $DEV/Frameworks -Xlinker -rpath -Xlinker $DEV/usr/lib "$@"
fi
exec swift test "$@"
