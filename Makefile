# Make targets for the pinned Tuist workflow
.PHONY: bootstrap install clean

bootstrap:
	mise install

install: bootstrap
	mise exec -- tuist install
	mise exec -- tuist generate --no-open

clean:
	mise exec -- tuist clean
