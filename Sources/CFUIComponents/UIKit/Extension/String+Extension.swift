//
//  String.swift
//  SocialRepost
//
//  Created by Le Quang Tuan Cuong(CuongLQT) on 20/10/2023.
//

import Foundation

public extension String {
    var localized: String {
        localized(using: nil, in: .main)
    }
    
    func localizedFormat(_ arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
    
    func localizedPlural(_ argument: CVarArg?) -> String {
        NSString.localizedStringWithFormat(localized as NSString, argument ?? 0) as String
    }

   private func localized(using tableName: String?, in bundle: Bundle?) -> String {
        let bundle: Bundle = bundle ?? .main
        if let path = bundle.path(forResource: CFLocalize.shared.currentLocale, ofType: "lproj"),
            let bundle = Bundle(path: path) {
           
            return bundle.localizedString(forKey: self, value: nil, table: tableName)
        } else if let path = bundle.path(forResource: "Base", ofType: "lproj"),
            let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: self, value: nil, table: tableName)
        }
        return self
    }
    
    func decodeBrokenJSON() -> String? {

         var bytes = Data()
         var position = startIndex

         while let range = range(of: "\\u", range: position..<endIndex) {
             bytes.append(contentsOf:self[position ..< range.lowerBound].utf8)
             position = range.upperBound
             let hexCode = self[position...].prefix(4)
             guard hexCode.count == 4, let byte = UInt8(hexCode, radix: 16) else {
                 return nil // Invalid hex code
             }
             bytes.append(byte)
             position = index(position, offsetBy: hexCode.count)
         }
         bytes.append(contentsOf: self[position ..< endIndex].utf8)
         return String(data: bytes, encoding: .utf8)
     }
}

public class CFLocalize {
    public static var shared = CFLocalize()
    private var locale: String?
    
    private init() { }
    
    public func setLocale(locale: String) {
        self.locale = locale
    }
    
    public var currentLocale: String? { self.locale }
}

public extension Locale {
    static let currency: [String: (code: String?, symbol: String?, name: String?)] = isoRegionCodes.reduce(into: [:]) {
        let locale = Locale(identifier: identifier(fromComponents: [NSLocale.Key.countryCode.rawValue: $1]))
        $0[$1] = (locale.currencyCode, locale.currencySymbol, locale.localizedString(forCurrencyCode: locale.currencyCode ?? ""))
    }
    
    static func countryName(countryCode: String) -> String? {
        let current = Locale(identifier: "en_US")
        return current.localizedString(forRegionCode: countryCode)
    }
}
