//
//  AssetPaletteViewController.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/24/26.
//

import AppKit

// MARK: - Model

struct PaletteAsset: Hashable {
    let id: UUID = UUID()
    let title: String
    let color: NSColor
}

private extension NSPasteboard.PasteboardType {
    static let assetID = NSPasteboard.PasteboardType("com.yourapp.asset-id")
}

// MARK: - Collection Item (manual drag source)

final class PaletteItem: NSCollectionViewItem, NSDraggingSource {

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("PaletteItem")

    private let swatch = NSView()
    private let titleLabel = NSTextField(labelWithString: "")

    // Set by the data source
    var assetIDString: String = ""
    var dragPreviewImageName: String = "Room" // or set per item if you want

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.separatorColor.cgColor
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.35).cgColor

        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = 8

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail

        swatch.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(swatch)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            swatch.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            swatch.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 16),
            swatch.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            view.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    func apply(_ asset: PaletteAsset, isSelected: Bool) {
        titleLabel.stringValue = asset.title
        swatch.layer?.backgroundColor = asset.color.cgColor
        view.layer?.borderColor = (isSelected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }

    // Keep selection visuals working
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }

    // Start a drag session manually from the item view.
    override func mouseDragged(with event: NSEvent) {
        guard !assetIDString.isEmpty else { return }

        let pbItem = NSPasteboardItem()
        pbItem.setString(assetIDString, forType: .assetID)

        let draggingItem = NSDraggingItem(pasteboardWriter: pbItem)

        let dragImage = NSImage(named: dragPreviewImageName) ?? snapshotImage(of: view)
        let size = dragImage.size

        // Place image under cursor (local coords)
        let local = view.convert(event.locationInWindow, from: nil)
        let frame = NSRect(
            x: local.x - size.width * 0.5,
            y: local.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
        draggingItem.setDraggingFrame(frame, contents: dragImage)

        view.beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    // Snapshot helper
    private func snapshotImage(of view: NSView) -> NSImage {
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: rep)
        let img = NSImage(size: view.bounds.size)
        img.addRepresentation(rep)
        return img
    }
}

// MARK: - Palette VC

final class AssetPaletteViewController: NSViewController {

    private var assets: [PaletteAsset] = [
        .init(title: "Half Room", color: .systemBlue),
        .init(title: "Truss 10m", color: .systemGray),
        .init(title: "Batten", color: .systemOrange),
        .init(title: "Spotlight", color: .systemYellow),
        .init(title: "Wash Light", color: .systemPink),
        .init(title: "LED Panel", color: .systemGreen),
    ]

    private let scrollView = NSScrollView()
    private let collectionView = NSCollectionView()

    override func loadView() {
        view = NSView()

        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configureCollectionView()
    }

    private func configureCollectionView() {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 6
        layout.minimumInteritemSpacing = 6
        layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.itemSize = NSSize(width: 220, height: 36) // resized in viewDidLayout

        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]

        collectionView.register(PaletteItem.self, forItemWithIdentifier: PaletteItem.reuseIdentifier)

        collectionView.dataSource = self
        collectionView.delegate = self
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else { return }
        let insets = layout.sectionInset.left + layout.sectionInset.right
        let available = max(80, view.bounds.width - insets)
        layout.itemSize = NSSize(width: available, height: 36)
    }
}

// MARK: - Data Source

extension AssetPaletteViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

    func collectionView(_ collectionView: NSCollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: PaletteItem.reuseIdentifier, for: indexPath)
        guard let paletteItem = item as? PaletteItem else { return item }

        let asset = assets[indexPath.item]
        paletteItem.assetIDString = asset.id.uuidString
        paletteItem.dragPreviewImageName = "Room" // or pick per asset
        paletteItem.apply(asset, isSelected: item.isSelected)
        return paletteItem
    }
}

// MARK: - Delegate (selection only)

extension AssetPaletteViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView,
                        didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let idx = indexPaths.first?.item else { return }
        print("Selected:", assets[idx].title)
    }
}
