.PHONY: all build ide lazarus

all: build

# CLI app build only — does not install LCA Design into the Lazarus IDE or run --build-ide.
# For a readable Form Designer (light palette on dark .lfm), close Lazarus and run: make ide
build:
	./scripts/install-lazarus-sqlite.sh
	lazbuild --widgetset=qt5 packages/LcaDesignSystem/LcaDesignSystem.lpk
	lazbuild --widgetset=qt5 lazycodingagent.lpi
	./scripts/post-build.sh

ide:
	./scripts/install-lca-lazarus.sh --widgetset=qt5

lazarus:
	./scripts/run-lazarus-linux.sh
