import CommonCrypto
import Foundation

private extension Data {
    func toHexString() -> String {
        let hexString = map { String(format: "%02x", $0) }.joined()
        return hexString
    }

    func bytes() -> [UInt8] {
        let array = [UInt8](self)
        return array
    }
}

extension String {
    func sha256() -> String {
        if let stringData = self.data(using: String.Encoding.utf8) {
            return hexStringFromData(input: digest(input: stringData as NSData))
        }
        return ""
    }

    private func digest(input: NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }

    private func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)

        var hexString = ""
        for byte in bytes {
            hexString += String(format: "%02x", UInt8(byte))
        }

        return hexString
    }

    func hmac(keyString: String) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyString, keyString.count, self, count, &digest)
        return Data.init(bytes: digest)
    }

    func hmac(keyData: Data) -> Data {
        let keyBytes = keyData.bytes()
        let data = cString(using: String.Encoding.utf8)
        let dataLen = Int(lengthOfBytes(using: String.Encoding.utf8))
        var result = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes, keyData.count, data, dataLen, &result)

        return Data.init(bytes: result)
    }
}


class KVSSigner {
    
    static func iso8601() -> (fullDateTimestamp: String, shortDate: String) {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = utcDateFormatter
        dateFormatter.timeZone = TimeZone(abbreviation: utcTimezone)
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        let index = dateString.index(dateString.startIndex, offsetBy: 8)
        let shortDate = dateString.substring(to: index)
        return (fullDateTimestamp: dateString, shortDate: shortDate)
    }
    
    /*
     DateKey              = HMAC-SHA256("AWS4"+"<SecretAccessKey>", "<YYYYMMDD>")
     DateRegionKey        = HMAC-SHA256(<DateKey>, "<aws-region>")
     DateRegionServiceKey = HMAC-SHA256(<DateRegionKey>, "<aws-service>")
     SigningKey           = HMAC-SHA256(<DateRegionServiceKey>, "aws4_request")
     */
    static func signatureWith(stringToSign: String, secretAccessKey: String, shortDateString: String, awsRegion: String, serviceType: String) -> String? {

        let firstKey = "AWS4" + secretAccessKey
        let dateKey = shortDateString.hmac(keyString: firstKey)
        let dateRegionKey = awsRegion.hmac(keyData: dateKey)
        let dateRegionServiceKey = serviceType.hmac(keyData: dateRegionKey)
        let signingKey = awsRequestTypeKey.hmac(keyData: dateRegionServiceKey)

        let signature = stringToSign.hmac(keyData: signingKey)
        return signature.toHexString()
    }

    static func getCredentialScope(shortDate: String, region: String, serviceName: String, requestType: String) -> String {
        let credentialArray = [shortDate, region, serviceName, requestType]
        return credentialArray.joined(separator: slashDelimiter)
    }
    
    static func getQueryParams(accessKey: String, sessionToken: String, credentialScope: String, date:(fullDateTimestamp: String, shortDate: String)) -> (queryParamBuilder: [URLQueryItem], queryParamBuilderDict: [String: String]) {
        var queryParamsBuilderArray = [URLQueryItem]()
        queryParamsBuilderArray.append(URLQueryItem(name: xAmzAlgorithm, value: signerAlgorithm))
        queryParamsBuilderArray.append(URLQueryItem(name: xAmzCredential, value: (accessKey + slashDelimiter + credentialScope).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!))
        queryParamsBuilderArray.append(URLQueryItem(name: xAmzDate, value: date.fullDateTimestamp))
        queryParamsBuilderArray.append(URLQueryItem(name: xAmzExpiresKey, value: xAmzExpiresValue))
        queryParamsBuilderArray.append(URLQueryItem(name: xAmzSignedHeaders, value: hostKey))
        
        var queryParamsBuilderDictionary: [String: String] = [
            xAmzAlgorithm: signerAlgorithm,
            xAmzCredential: (accessKey + slashDelimiter + credentialScope).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!,
            xAmzDate: date.fullDateTimestamp,
            xAmzExpiresKey: xAmzExpiresValue,
            xAmzSignedHeaders: hostKey
        ]
        
        if !sessionToken.isEmpty {
            queryParamsBuilderArray
                .append(URLQueryItem(
                    name: xAmzSecurityToken,
                    value: sessionToken.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!.replacingOccurrences(of: plusDelimiter, with: plusEncoding).replacingOccurrences(of: equalsDelimiter, with: equalsEncoding)))
            queryParamsBuilderDictionary
                .updateValue(sessionToken.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!.replacingOccurrences(of: plusDelimiter, with: plusEncoding).replacingOccurrences(of: equalsDelimiter, with: equalsEncoding),
                             forKey: xAmzSecurityToken)
        }
        
        return (queryParamsBuilderArray, queryParamsBuilderDictionary)
    }
    
    static func getStringToSign(fullDateTimeStamp: String, credentialScope: String, canonicalRequest: String) -> String {
        return signerAlgorithm + newlineDelimiter +
        fullDateTimeStamp + newlineDelimiter +
        credentialScope + newlineDelimiter +
        canonicalRequest.sha256()
    }
    
    static func getSignedUrl(wssRequest: URL, queryParamsBuilder:[URLQueryItem], canonicalUri: String, signature: String) -> URL? {
        
        var components = URLComponents()
        components.scheme = wssKey
        components.host = wssRequest.host
        components.path = canonicalUri
        var queryParamsBuilderArray = queryParamsBuilder
        queryParamsBuilderArray.sort {
            $0.name < $1.name
        }
        queryParamsBuilderArray.append(URLQueryItem(name: xAmzSignature, value: signature))

        if #available(iOS 11.0, *) {
            components.percentEncodedQueryItems = queryParamsBuilderArray
        } else {
            
        }
        print("Signed url", components.url!)
        return components.url
    }
    
    static func getCanonicalHeaders(signRequest:URL) -> String? {
        guard let host = signRequest.host
            else { return .none }
        return hostKey + colonDelimiter + host + newlineDelimiter
    }
    
    static func getCanonicalUri (signRequest:URL) -> String? {
        if (signRequest.path.isEmpty) {
            return slashDelimiter
        }
        return signRequest.path
    }
    
    static func getCanonicalRequest(canonicalQuerystring: String, signRequest: URL) -> String? {
        let cleanedcanonicalQuerystring = String(canonicalQuerystring.dropLast())
        let emptyString = ""
        let payloadHash = emptyString.sha256()
        return
            restMethod + newlineDelimiter +
                getCanonicalUri(signRequest: signRequest)! + newlineDelimiter +
                cleanedcanonicalQuerystring + newlineDelimiter +
                getCanonicalHeaders(signRequest: signRequest)! + newlineDelimiter +
                hostKey + newlineDelimiter + payloadHash
    }
    
    static func getCanonicalQueryString(queryParamBuilderDict: [String: String]) -> String? {
        let sortedKeys = queryParamBuilderDict.keys.sorted()
        var canonicalQueryString: String = ""

        for key in sortedKeys {
            canonicalQueryString += key + equalsDelimiter + queryParamBuilderDict[key]! + ampersandDelimiter
        }
        return canonicalQueryString
    }
    
    static func sign(signRequest: URL, secretKey: String, accessKey: String, sessionToken: String,
                     wssRequest: URL, region: String) -> URL? {
        let date = iso8601()
        return signWithDate(signRequest: signRequest, secretKey: secretKey, accessKey: accessKey, sessionToken: sessionToken, wssRequest: wssRequest, region: region, date: date)
    }
    
    static func signWithDate(signRequest: URL, secretKey: String, accessKey: String, sessionToken: String,
                             wssRequest: URL, region: String, date:(fullDateTimestamp: String, shortDate: String)) -> URL? {
        var canonicalUri = signRequest.path
        if (canonicalUri.isEmpty) {
            canonicalUri = slashDelimiter
        }
        let credentialScope = getCredentialScope(shortDate: date.shortDate, region: region, serviceName: awsKinesisVideoKey, requestType: awsRequestTypeKey)

        let queryParams = getQueryParams(accessKey: accessKey, sessionToken: sessionToken, credentialScope: credentialScope, date: date)
        var queryParamsBuilder :[URLQueryItem] = queryParams.queryParamBuilder
        var queryParamsBuilderDict: [String: String] = queryParams.queryParamBuilderDict

        //Adding queryParams from the signRequest's query.
        if signRequest.query != nil {
            let queryParams = signRequest.query!
            let queryParamArray = queryParams.components(separatedBy: ampersandDelimiter)

            for param in queryParamArray {
                if let index = param.firstIndex(of: "=") {
                    let nextIndex = param.index(after: index)
                    queryParamsBuilderDict.updateValue(String(param[nextIndex...]).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!, forKey: String(param[..<index]))
                    queryParamsBuilder.append(URLQueryItem(name: String(param[..<index].addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!), value: String(param[nextIndex...]).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!))
                }
            }
        } else {
            print("Error: Missing channel ARN.")
        }

        let canonicalQuerystring = getCanonicalQueryString(queryParamBuilderDict: queryParamsBuilderDict)
        let canonicalRequest = getCanonicalRequest(canonicalQuerystring: canonicalQuerystring!, signRequest: signRequest)
        let stringToSign = getStringToSign(fullDateTimeStamp: date.fullDateTimestamp, credentialScope: credentialScope, canonicalRequest: canonicalRequest!)
        let signature = signatureWith(stringToSign: stringToSign, secretAccessKey: secretKey, shortDateString: date.shortDate, awsRegion: region, serviceType: awsKinesisVideoKey)
        return getSignedUrl(wssRequest: wssRequest, queryParamsBuilder: queryParamsBuilder, canonicalUri: canonicalUri, signature: signature!)
        
    }
}







//{
//    "AccessToken": "eyJraWQiOiJaVkw4bzJWYXJcL0UrSjhIQ1grcFdHakZSY2xwTlNYWktVTGQ4N2hJdXdcL0E9IiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiI0MWJiNTUyMC03MGExLTcwNWQtYzUyYy01NzAwOWM3MGQzNTQiLCJpc3MiOiJodHRwczpcL1wvY29nbml0by1pZHAudXMtZWFzdC0yLmFtYXpvbmF3cy5jb21cL3VzLWVhc3QtMl9QQ2ZIQjNMY2UiLCJjbGllbnRfaWQiOiI0bzJrMG5yaG5zN2pqcWZvc2k2NGRkaDlwcSIsIm9yaWdpbl9qdGkiOiI2OTJhZmJkYS0wNDI2LTRjNTctYmFmZi01ODQ5Zjc4YTk4MWYiLCJldmVudF9pZCI6ImVmZmFhMTI1LTk1OTYtNDZjMy05MmFlLWU4YThlYzY4NTdjZSIsInRva2VuX3VzZSI6ImFjY2VzcyIsInNjb3BlIjoiYXdzLmNvZ25pdG8uc2lnbmluLnVzZXIuYWRtaW4iLCJhdXRoX3RpbWUiOjE3MTY5Nzc0NTYsImV4cCI6MTcxNjk4MTA1NiwiaWF0IjoxNzE2OTc3NDU2LCJqdGkiOiJkODQ0MDBhZS1kOTQ1LTRmNTctOThiMC02ZDI4YWI3NjY5NGUiLCJ1c2VybmFtZSI6IjJmM2JmYzVkLWUwYTktNDM1Mi05MWVkLWMzZGQ1Y2JiNGY0ZCJ9.t4nHVOo-CeUP66_Ah6AoRoSWIoIMzWgm_j-6H1VAShLFNctkqSRB2dS6KxHBfxftC6fypO6RmVVJXLNHogq3uFQrcV6nDSkYP9qS2BxOOw0xP4SJ6pGhxWpyk5yzT-1w1ja7hqfRkwNo949eDX6aOeYUy17sq0P2S-2iLpkDEl73mT9Amb_5TXfpoHhjsficlfAA4HExHTX6OMGlWeywBeylYl8JqsgIbJSoy86cIAN2p0Ym_xP1QY_UpGUXwHbV0EFgZGDFn0dHcUFSUB_FhR74mXsuQJso49Z23kGjCaRhZ3HmlGGa1gWfhgpWJXD-GkfGUHBfwoDzLCGS2xAJ7A",
//    "ExpiresIn": 3600,
//    "TokenType": "Bearer",
//    "RefreshToken": "eyJjdHkiOiJKV1QiLCJlbmMiOiJBMjU2R0NNIiwiYWxnIjoiUlNBLU9BRVAifQ.VWnSaTvL61jXfSl5hEG-DSbImKE8xVM0Nb1rr1a0jjb5xtEYAunsTB09T4CV5GgPZw4P3J_277zz_6zzCgZm426Z1jPErSGmWtlKPj3l4QXnseDw_1qcGDgmFlaRUkGOHfHKJKnvtJMB2imxx-VqTyPgntecqU_F565R7ntnB-L_cxD3p0ED3PT9xcBlxMhZUBvxzyKMa81svnSu_wSbXV1sJaHxyIhrS_vzYEZsqUASOLgbgogONLd9qgshvXlSVn2goCJ7hsjx9KY5j0Hj7jxC9LnWVzDiy1ZelnTF3NL0Cs_zJTXRrhjFiIB8RnkhQJXxWccPK7SbgSb-79hdGA.2jUw7mpaFbFflBP2.TGucxJLCJRVYT8uo5HITnv9reWHP9_8sJ5MAXNqk6IPWLoh4CJFUy2uxhKXJ3NUivS8osc-llaB4xLZxEJIMFEmJFKyHMBPCrEoFGMVLmVb1DeMs0WsP7a3Ej_VZICiKMb3emMVeLnoLMLncfesGB6j2e5WMK9dqdT27tLMEKYqfIYRo6u0AUH83ZXht1e4KVlbkzkEzkum7mvjlc0vg93jGu4QNkRmUfosW1oiLZyDEEvfy5cmAmLnitqlSxRME4lppef7kQdgwgQwWwxvf-tdoWj3TZOAsOcrSszncPEm1VJ-TFnkGosxuTtSYpzrLit_WU_3GaRVZd8WCu4VuucbKOhOk3f6VLH9irITU5P2AYB-8S1H40jRc-94MVtoJ2Vup_EaI0U4gdGsiLHDMmQC-755DZILDLtnZVqqPRU1dgcJu8D4uPjf4yR9hQ0SPtd1u1gQXrCYId9MGqhR9t9qo4Ij90ueuqC_Efd7AuAFzZdFqhkSVzJFbfySCLD1YVOo0H9O5dYUSV38k1OEYWk-KnvevPOS_Nu6e03AeCQUfwAzZPOYqfD-1zZDDmIzMOOyQlb-kLnbCAMoKDRSBOvy-tnagdPJE_d93vTZ-QLBH6vuMU0EbMofTCfThunBOjj9J11_s8DRfR1jTuArN6rqoWRdjOnBsmnLc_Y25KuWkTTcVVhHzi8M0peVsV9vxWKk5z3-hXxbXyoyeDez6alrgEvwfPYkZ_1AghTBj7-9axTPnfONz0hVieNkhy2Sk_ghIv6d0HmH1QLofQFD535KpYBSIXAG_qyiLDY-CWu0Jy4EN_JpUcEuqp-pgxMt29dyUxyOAbO9YmTpTfhbCDLz09YykzaSNbw-2UvvkH3NpvF48FfyfBb5ZD6YmfId3i6_Rq-AJNnU1LnVeQwK-g8MqnlJvwINhx9hnQpIoakgyJ1iDZA00drNVWNArHs4cjDsc_kTNbNJXeSFj8-Lq1nfcLrYBhh-HYMFonG1_88gi4NuVex-Je_xB6u2kDtpEO2I_QMbsBdyPW1M3tBR5EDoRxtH_m6ZAi2Nz4Uq6tlqfQpnFjN44nniGEFYEmBc-RkkxtOPrZwwmLipe_-s-u7bzXgdQHZSO-M7UrgULV3EgnY9l8Ohj57PBIyGlTCb8RxLNiuTbjuSLJWLUjuaRTnuk1xcX_rSr6onLtF_HnN50mlkQCL4mrBXezKDjPE9sDEII8KzFqrAmrnSjc_USlm3cDlxXEh3pKYu1Tu9q0W6fFnhbvLBxTx6wPLCEp7M2HBrkT_TerGaU--J8WqcUnA-aAj3zaoo_kJryKQ2PEG8POYpo22pEFkgXaIc.NCqOPG15bhrFkl1izb38tA",
//    "IdToken": "eyJraWQiOiJpdGVzdEhTQkMzenY5VU1wTWVqREtFSVFvUjNwZ2ZHbHhicW5ieHFkWTNnPSIsImFsZyI6IlJTMjU2In0.eyJvcmlnaW5fanRpIjoiNjkyYWZiZGEtMDQyNi00YzU3LWJhZmYtNTg0OWY3OGE5ODFmIiwic3ViIjoiNDFiYjU1MjAtNzBhMS03MDVkLWM1MmMtNTcwMDljNzBkMzU0IiwiYXVkIjoiNG8yazBucmhuczdqanFmb3NpNjRkZGg5cHEiLCJldmVudF9pZCI6ImVmZmFhMTI1LTk1OTYtNDZjMy05MmFlLWU4YThlYzY4NTdjZSIsInRva2VuX3VzZSI6ImlkIiwiYXV0aF90aW1lIjoxNzE2OTc3NDU2LCJpc3MiOiJodHRwczpcL1wvY29nbml0by1pZHAudXMtZWFzdC0yLmFtYXpvbmF3cy5jb21cL3VzLWVhc3QtMl9QQ2ZIQjNMY2UiLCJjb2duaXRvOnVzZXJuYW1lIjoiMmYzYmZjNWQtZTBhOS00MzUyLTkxZWQtYzNkZDVjYmI0ZjRkIiwiZXhwIjoxNzE2OTgxMDU2LCJpYXQiOjE3MTY5Nzc0NTYsImp0aSI6ImVlMWZhNDJmLTI5YjYtNGNjMy1iOTRmLTM1YmIzOWM0NTBlZCJ9.8PDQtkeJjJ8Q21BDA7SwFUa2JrjUmXdR7TJtztr0Netlz6mL6H79nCiGuKyjIiuAEmkPuTX11-WpM3m3Lvf6cfd9a7D9hB_d2Z-nuQcl--i-v_jiTWm5lGk764TAUbTg9hVuboPCTDx2cAYBrOCb3po5XVTMIVQhGRMkTlUS_Vo-CxomWlFMWQB-0QYZPOuq5lqPbwvdmD8HaEi1Fjx11KJNPCZWOmMMbpcQikqt62HC6XTdyvPnozn88DGjlOMXCapnZ7zWtAHf2lYPBqXxIO-n7haa0vGkhKPA9bE3JpXTks6k9oYkHG5Lz8A1HjbXKmzgOlx84yOxOxIa0nz4cw"
//}
