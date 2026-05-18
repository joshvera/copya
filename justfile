app_dir := ".build/app/COPYA.app"

build:
    ./scripts/build-app.sh

install: build
    rm -rf /Applications/COPYA.app
    cp -R {{app_dir}} /Applications/COPYA.app
