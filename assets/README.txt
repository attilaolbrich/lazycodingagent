Splash artwork for startup.

- splash.png — default splash image (also loaded in the Lazarus form designer via frmSplash FormCreate when assets/ is reachable from the project directory)
- splash.jpg — optional alternate source
- owl_icon.bmp / owl_icon.png — title bar and app icon (copied from packages/LcaDesignSystem/res on post-build; required on Linux/Qt5 instead of embedded OWL_ICON resources)

Replace splash.png to change artwork. In the IDE you can also assign imgSplash.Picture directly on frmSplash and save the form to embed the preview in the .lfm.

Deploy: copy this folder next to the executable (see scripts/copy-assets.sh).
