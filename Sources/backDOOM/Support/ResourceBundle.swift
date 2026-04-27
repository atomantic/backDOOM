import Foundation

extension Bundle {
    static var backDOOMResources: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    func backDOOMAssetURL(forResource name: String, withExtension ext: String) -> URL? {
        url(forResource: name, withExtension: ext, subdirectory: "Assets")
            ?? url(forResource: name, withExtension: ext)
    }
}
