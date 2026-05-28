default:
    just --list

fmt:
    swift-format format -i -r ./Sources

release:
    swift build -c release
    mkdir -p dist/dose.app/Contents/MacOS
    mkdir -p dist/dose.app/Contents/Resources
    mv .build/release/dose dist/dose.app/Contents/MacOS/dose
    cp ./Info.plist dist/dose.app/Contents/Info.plist
    cp ./assets/Calm.mp3 dist/dose.app/Contents/Resources/Calm.mp3

run:
    swift run
