//
//  AssetPaletteViewController.swift
//  vivarium-studio
//
//  Created by Roy Li on 1/24/26.
//

import Cocoa
import AppKit

struct PaletteAsset: Hashable {
    let id: UUID = UUID()
    let title: String
    let color: NSColor
}

final class PaletteItem: NSCollectionViewItem {

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("PaletteItem")

    private let swatch = NSView()
    private let titleLabel = NSTextField(labelWithString: "")

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = 1

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

    override func viewDidLoad() {
        super.viewDidLoad()
        // background colors set in apply(...)
    }
    
    func apply(_ asset: PaletteAsset, isSelected: Bool) {
        titleLabel.stringValue = asset.title
        swatch.layer?.backgroundColor = asset.color.cgColor

        view.layer?.borderColor = (isSelected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.35).cgColor
    }

    override var isSelected: Bool {
        didSet {
            // you can update styling here if you store the asset, or just rely on reload
        }
    }
}

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

        // CollectionView inside a ScrollView
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

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
        // Layout
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 6
        layout.minimumInteritemSpacing = 6
        layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.itemSize = NSSize(width: 220, height: 36) // will be resized on viewDidLayout

        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]

        // Register
        collectionView.register(PaletteItem.self,
                                forItemWithIdentifier: PaletteItem.reuseIdentifier)

        // Data source & delegate
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // Make cells fill the available width (sidebar-friendly)
        guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else { return }
        let insets = layout.sectionInset.left + layout.sectionInset.right
        let available = view.bounds.width - insets - layout.minimumInteritemSpacing
        layout.itemSize = NSSize(width: available, height: 36)
    }
}

// MARK: - Data Source
extension AssetPaletteViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: PaletteItem.reuseIdentifier, for: indexPath)
        guard let paletteItem = item as? PaletteItem else { return item }

        let asset = assets[indexPath.item]
        paletteItem.apply(asset, isSelected: item.isSelected)
        return paletteItem
    }
}

// MARK: - Delegate
extension AssetPaletteViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let idx = indexPaths.first?.item else { return }
        let asset = assets[idx]
        print("Selected:", asset.title)
        // Hook this up to your placement tool: start "drag-to-place" or show inspector.
    }
}
