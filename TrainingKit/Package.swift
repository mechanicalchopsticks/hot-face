// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrainingKit",
    defaultLocalization: "en",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(
            name: "TrainingKit",
            targets: [
                "TrainingDomain", "TrainingRepositories", "TrainingAdapters", "TrainingInterface",
            ])
    ],
    targets: [
        .target(name: "TrainingDomain"),
        .target(name: "TrainingRepositories", dependencies: ["TrainingDomain"]),
        .target(name: "TrainingAdapters", dependencies: ["TrainingDomain"]),
        .target(
            name: "TrainingInterface", dependencies: ["TrainingDomain"],
            resources: [.process("Localizable.xcstrings")]),
        .testTarget(name: "TrainingInterfaceTests", dependencies: ["TrainingInterface", "TrainingDomain"]),
        .testTarget(name: "TrainingDomainTests", dependencies: ["TrainingDomain"]),
        .testTarget(
            name: "TrainingRepositoryTests", dependencies: ["TrainingRepositories", "TrainingDomain"],
            resources: [.copy("Fixtures")]),
    ]
)
