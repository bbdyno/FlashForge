import ProjectDescription

let appName = "FlashForge"
let bundleId = "com.bbdyno.app.flashFlow"
let widgetBundleId = "com.bbdyno.app.flashFlow.widget"
let testBundleId = "com.bbdyno.app.flashFlowTests"
let uiTestBundleId = "com.bbdyno.app.flashFlowUITests"
let developmentTeamId = "M79H9K226Y"
let provisioningProfileName = "FlashForge iOS Distribution Provisioning"
let provisioningProfileUUID = "b8ee75c0-3572-4788-ad21-a75a79de7904"
let widgetProvisioningProfileName = "FlashForge Widget Distribution Provisioning"
let widgetProvisioningProfileUUID = "24312bb1-92d0-419e-bb25-064eb8dd7643"
let marketingVersion = "1.1.0"
let buildNumber = "2026.07.20.1"

let project = Project(
    name: appName,
    organizationName: "bbdyno",
    packages: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.1"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0")
    ],
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
            name: appName,
            destinations: .iOS,
            product: .app,
            bundleId: bundleId,
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": .string(marketingVersion),
                "CFBundleVersion": .string(buildNumber),
                "CFBundleDisplayName": .string("FlashForge"),
                "CFBundleDevelopmentRegion": .string("en"),
                "FIREBASE_ANALYTICS_COLLECTION_ENABLED": .boolean(false),
                "FirebaseCrashlyticsCollectionEnabled": .boolean(false),
                "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS": .boolean(false),
                "GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED": .boolean(false),
                "UIAppFonts": .array([
                    .string("Manrope-Variable.ttf")
                ]),
                "UILaunchScreen": .dictionary([:]),
                "NSSupportsLiveActivities": .boolean(true),
                "UIApplicationSceneManifest": .dictionary([
                    "UIApplicationSupportsMultipleScenes": .boolean(false),
                    "UISceneConfigurations": .dictionary([
                        "UIWindowSceneSessionRoleApplication": .array([
                            .dictionary([
                                "UISceneConfigurationName": .string("Default Configuration"),
                                "UISceneDelegateClassName": .string("$(PRODUCT_MODULE_NAME).SceneDelegate")
                            ])
                        ])
                    ])
                ])
            ]),
            sources: [
                "App/**",
                "Models/**",
                "Services/**",
                "Shared/**",
                "ViewModels/**",
                "Views/**",
                "ViewControllers/**"
            ],
            resources: [
                "Resources/AppAssets.xcassets",
                "Resources/Fonts/**",
                "GoogleService-Info.plist"
            ],
            scripts: [
                .pre(
                    script: """
                    if test -d "/opt/homebrew/bin"; then
                      export PATH="/opt/homebrew/bin:$PATH"
                    fi

                    if test -d "/usr/local/bin"; then
                      export PATH="/usr/local/bin:$PATH"
                    fi

                    if which swiftlint >/dev/null; then
                      swiftlint lint --config "${SRCROOT}/.swiftlint.yml" --no-cache
                    else
                      echo "warning: SwiftLint not installed. Install with: brew install swiftlint"
                    fi
                    """,
                    name: "SwiftLint"
                ),
                .post(
                    script: """
                    if [ "${CONFIGURATION}" != "Release" ]; then
                      exit 0
                    fi

                    GOOGLE_SERVICE_INFO="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
                    if [ ! -f "${GOOGLE_SERVICE_INFO}" ]; then
                      echo "warning: GoogleService-Info.plist not found. Skipping Crashlytics dSYM upload."
                      exit 0
                    fi

                    CRASHLYTICS_RUN_SCRIPT="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
                    if [ ! -f "${CRASHLYTICS_RUN_SCRIPT}" ]; then
                      echo "warning: Crashlytics run script not found at ${CRASHLYTICS_RUN_SCRIPT}. Skipping dSYM upload."
                      exit 0
                    fi

                    "${CRASHLYTICS_RUN_SCRIPT}"
                    """,
                    name: "Firebase Crashlytics Upload dSYMs",
                    inputPaths: [
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist",
                        "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist",
                        "${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
                    ],
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .target(name: "\(appName)Widgets"),
                .project(target: "SharedResources", path: "SharedResources"),
                .package(product: "SnapKit"),
                .package(product: "FirebaseCore"),
                .package(product: "FirebaseAnalytics"),
                .package(product: "FirebaseCrashlytics")
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": .string("complete"),
                    "MARKETING_VERSION": .string(marketingVersion),
                    "CURRENT_PROJECT_VERSION": .string(buildNumber),
                    "CODE_SIGN_ENTITLEMENTS": .string("Config/FlashForge.entitlements"),
                    "DEVELOPMENT_TEAM": .string(developmentTeamId),
                    "OTHER_LDFLAGS": .string("$(inherited) -ObjC")
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        settings: [
                            "CODE_SIGN_STYLE": .string("Automatic")
                        ]
                    ),
                    .release(
                        name: "Release",
                        settings: [
                            "CODE_SIGN_STYLE": .string("Manual"),
                            "CODE_SIGN_IDENTITY[sdk=iphoneos*]": .string("iPhone Distribution"),
                            "PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]": .string(provisioningProfileName),
                            "PROVISIONING_PROFILE[sdk=iphoneos*]": .string(provisioningProfileUUID)
                        ]
                    )
                ]
            )
        ),
        .target(
            name: "\(appName)Widgets",
            destinations: .iOS,
            product: .appExtension,
            bundleId: widgetBundleId,
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": .string(marketingVersion),
                "CFBundleVersion": .string(buildNumber),
                "CFBundleDevelopmentRegion": .string("en"),
                "CFBundleDisplayName": .string("FlashForge Widgets"),
                "UIAppFonts": .array([
                    .string("Manrope-Variable.ttf")
                ]),
                "NSExtension": .dictionary([
                    "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
                ])
            ]),
            sources: [
                "WidgetExtension/**/*.swift",
                "Shared/**/*.swift"
            ],
            resources: [
                "Resources/Fonts/**"
            ],
            dependencies: [
                .project(target: "SharedResources", path: "SharedResources")
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": .string("complete"),
                    "MARKETING_VERSION": .string(marketingVersion),
                    "CURRENT_PROJECT_VERSION": .string(buildNumber),
                    "CODE_SIGN_ENTITLEMENTS": .string("Config/FlashForgeWidgets.entitlements"),
                    "DEVELOPMENT_TEAM": .string(developmentTeamId)
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        settings: [
                            "CODE_SIGN_STYLE": .string("Automatic")
                        ]
                    ),
                    .release(
                        name: "Release",
                        settings: [
                            "CODE_SIGN_STYLE": .string("Manual"),
                            "CODE_SIGN_IDENTITY[sdk=iphoneos*]": .string("iPhone Distribution"),
                            "PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]": .string(widgetProvisioningProfileName),
                            "PROVISIONING_PROFILE[sdk=iphoneos*]": .string(widgetProvisioningProfileUUID)
                        ]
                    )
                ]
            )
        ),
        .target(
            name: "\(appName)Tests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: testBundleId,
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": .string(marketingVersion),
                "CFBundleVersion": .string(buildNumber)
            ]),
            sources: [
                "Tests/**"
            ],
            dependencies: [
                .target(name: appName)
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "MARKETING_VERSION": .string(marketingVersion),
                    "CURRENT_PROJECT_VERSION": .string(buildNumber)
                ]
            )
        ),
        .target(
            name: "\(appName)UITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: uiTestBundleId,
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": .string(marketingVersion),
                "CFBundleVersion": .string(buildNumber)
            ]),
            sources: [
                "UITests/**"
            ],
            dependencies: [
                .target(name: appName)
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "MARKETING_VERSION": .string(marketingVersion),
                    "CURRENT_PROJECT_VERSION": .string(buildNumber)
                ]
            )
        )
    ]
)
