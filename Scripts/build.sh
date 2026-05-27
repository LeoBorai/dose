#/bin/sh

swift build -c release
mkdir -p dist/dose.app/Contents/MacOS
mkdir -p dist/dose.app/Contents/Resources
mv .build/release/dose dist/dose.app/Contents/MacOS/dose
chmod +x dist/dose.app/Contents/MacOS/dose
cp ./Info.plist dist/dose.app/Contents/Info.plist
