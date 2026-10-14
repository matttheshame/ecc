// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BruskKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BruskCore", targets: ["BruskCore"]),
        .library(name: "BruskBackend", targets: ["BruskBackend"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.55.0"),
    ],
    targets: [
        // Pure domain logic. No dependencies, no Apple-only frameworks: testable anywhere.
        .target(name: "BruskCore"),
        // Network layer. The only target that knows about Supabase.
        .target(
            name: "BruskBackend",
            dependencies: [
                "BruskCore",
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .testTarget(name: "BruskCoreTests", dependencies: ["BruskCore"]),
        .testTarget(name: "BruskBackendTests", dependencies: ["BruskBackend"]),
    ],
    swiftLanguageModes: [.v6]
)
