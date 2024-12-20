// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "TalkerSDKLibrary",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "TalkerSDKLibrary",
            targets: ["TalkerSDKLibrary"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.1"),
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.3"),
        .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm", .upToNextMajor(from: "2.38.1")),
//        .package(url: "https://github.com/stasel/WebRTC-iOS.git", from: Version),
//        .package(url: "https://github.com/aws-amplify/aws-sdk-ios", from: "2.37.2"),
            .package(url: "https://github.com/stasel/WebRTC.git", .upToNextMajor(from: "130.0.0")),
//        .package(url: "https://github.com/aws-amplify/aws-sdk-ios/tree/main/AWSAuthSDK/Sources/AWSMobileClient", from: "2.37.2"),
    ],
    targets: [
        .target(
            name: "TalkerSDKLibrary",
            dependencies: [
                "Alamofire",
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "WebRTC", package: "WebRTC"),
                .product(name: "AWSCore", package: "aws-sdk-ios-spm"),
                .product(name: "AWSCognitoIdentityProvider", package: "aws-sdk-ios-spm"),
                .product(name: "AWSKinesisVideo", package: "aws-sdk-ios-spm"),
                .product(name: "AWSKinesisVideoSignaling", package: "aws-sdk-ios-spm"),
                .product(name: "AWSMobileClientXCF", package: "aws-sdk-ios-spm")
//                .product(name: "WebRTC", package: "WebRTC-iOS"),
//                .product(name: "AWSCognitoIdentityProvider", package: "aws-sdk-ios"),
//                .product(name: "AWSKinesisVideo", package: "aws-sdk-ios"),
//                .product(name: "AWSKinesisVideoSignaling", package: "aws-sdk-ios"),
//                .product(name: "AWSCognito", package: "aws-sdk-ios"),
//                .product(name: "AWSCore", package: "aws-sdk-ios"), // Added AWSCore
            ]
        ),
    ]
)
