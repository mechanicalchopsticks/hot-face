// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrainingKit",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "TrainingKit", targets: [
            "TrainingDomain", "TrainingRepositories", "TrainingAdapters", "TrainingInterface",
        ]),
    ],
    targets: [
        .target(name: "TrainingDomain"),
        .target(name: "TrainingRepositories"),
        .target(name: "TrainingAdapters", dependencies: ["TrainingDomain"]),
        .target(name: "TrainingInterface", dependencies: ["TrainingDomain"]),
        .testTarget(name: "TrainingDomainTests", dependencies: ["TrainingDomain"]),
    ]
)
