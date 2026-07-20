import ProjectDescription

let marketingVersion = "1.1.0"
let buildNumber = "2026.07.20.1"

let project = Project(
    name: "SharedResources",
    organizationName: "bbdyno",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "MARKETING_VERSION": .string(marketingVersion),
            "CURRENT_PROJECT_VERSION": .string(buildNumber)
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "SharedResources",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.bbdyno.app.flashFlow.sharedresources",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": .string(marketingVersion),
                "CFBundleVersion": .string(buildNumber)
            ]),
            sources: [
                "Sources/**"
            ],
            resources: [
                "Resources/**"
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": .string("complete"),
                    "MARKETING_VERSION": .string(marketingVersion),
                    "CURRENT_PROJECT_VERSION": .string(buildNumber),
                    "APPLICATION_EXTENSION_API_ONLY": .string("YES")
                ]
            )
        )
    ]
)
