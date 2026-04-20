// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Makam",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "MakamDataLayer",
            targets: ["MakamDataLayer"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MakamDataLayer",
            path: "Makam",
            sources: [
                "Models",
                "Services",
                "Localization",
                "ContentView.swift"
            ]
        ),
        .target(
            name: "MakamWidgetExtension",
            dependencies: ["MakamDataLayer"],
            path: "MakamWidget",
            sources: [
                "MakamWidget.swift",
                "MakamWidgetBundle.swift",
                "MakamWidgetViews.swift"
            ]
        )
    ]
)
