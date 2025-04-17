# Signavio SVG-file Cleaner including SVG Optimizer (SVGO)
When using SVGs exported from Signavio arrowheads are often not displayed properly. The Powershell Script fixes the SVG file and passes the file to the SVGO tool afterwards. Tested on Windows only. Could possibly run on Mac and Linux, if you have Powershell installed.

## Usage

- Download the Powershell script.
- Download the svgo-win.exe binary from the [latest release](https://github.com/g-wenzel/signavio-svg-cleaner-incl-svgo/releases/latest) and place it in the same folder as the Powershell script.
- Right-click on the powershell script and choose "Run with Powershell"

Please refer also to [usage of SVGO](https://github.com/svg/svgo).

## svgo-executable

`svgo-executable` is standalone binary executable which wraps `svgo` (Scalable Vector Graphics Optimizer) using `pkg` (Node.js binary compiler). The binary is called by the Powershell Script.
It is adapted from [this repo](https://github.com/Antonytm/svgo-executable):

## Build Process

In order to make build and release process as transparent as it possible, everything is done using [GitHub actions](https://github.com/g-wenzel/signavio-svg-cleaner-incl-svgo/actions). 

To make a new build with the current version of SVGO
- Run the action `Update Dependencies` manually
- Clone the repo on your local machine
- cd into the repo folder
- create a tag (ideally the current SVGO version e.g. 3.3.2) by `git tag v3.3.2`
- push the tag to Github by `git push origin v3.3.2`
- pushing the tag triggers the build and release action

## Links

- [SVGO](https://github.com/svg/svgo)
- [PKG](https://github.com/vercel/pkg)
