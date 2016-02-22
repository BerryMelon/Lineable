//
//  LineableHTTP.swift
//  LineableExample
//
//  Created by Berrymelon on 2/17/16.
//  Copyright © 2016 Lineable. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import CoreBluetooth

#if DEBUG
let kBASEURL = "https://dev.lineable.net"
let kACCOUNTURL = "http://dev.lineable.net:9090"
let kDETECTURL = "http://dev.lineable.net:8099"
let kAWSTOKEN = "https://dev.lineable.net/log/getToken"
#else
let kBASEURL = "https://apiv2.lineable.net"
let kACCOUNTURL = "https://account.lineable.net"
let kDETECTURL = "https://detect.lineable.net"
let kAWSTOKEN = "https://apiv2.lineable.net/log/getToken"
#endif

protocol LineableManagementHTTP:LineableHTTP {}

extension LineableManagementHTTP where Self:LineableProtocol {
    
    func getLastLocation(completion:(result:Int,info:[String:AnyObject]?)->()) {
        let url = "\(kBASEURL)/child/location"
        self.sendData("GET", url: url, encoding:.URL, params: ["child_seq":self.seq,"v":"1"], completion: {(result,dataArray) in
            if let dataArray = dataArray as? [[String:AnyObject]] {
                if dataArray.isEmpty {
                    completion(result: result, info: nil)
                }
                else {
                    let data = dataArray.first
                    completion(result: result, info: data)
                }
            }
            else {
                completion(result: result, info: nil)
            }
        })
    }
    
    func sendLastLocation(completion:(result:Int)->()) {
        var beaconsDicArray = [Dictionary<String,String>]()
        
        let serial = self.device.serial
        let rssi = "\(self.device.signal.rssi)"
        
        let beaconDic = ["serial":serial, "rssi":rssi]
        beaconsDicArray.append(beaconDic)
        
        guard let lastLocation = LineableDetector.sharedDetector.lastLocation else { return }
        
        let geoInfo = ["latitude":lastLocation.coordinate.latitude, "longitude":lastLocation.coordinate.longitude, "accuracy":lastLocation.horizontalAccuracy]
        
        var param:Dictionary<String,AnyObject> = ["phone_type":"1", "beacons":beaconsDicArray, "geo_info":geoInfo]
        if User.me != nil {
            param["user_seq"] = "\(User.me!.seq)"
        }
        
        self.sendData("POST", url: "\(kDETECTURL)/app", encoding:.JSON, params: param, completion: {(result,infoarray) in
            
            let info = infoarray as? [[String:AnyObject]]
            if info != nil {
                completion(result: result)
            }
            else {
                completion(result: result)
            }
            
        })
    }
}

protocol LineableDetectHTTP:LineableHTTP {}

extension LineableDetectHTTP {
    func sendDetectedBeaconsAsGateway(gateway:Gateway,beacons:[CLBeacon],location:CLLocation?, completion:(result:Int)->()) {
        
        var beaconsDicArray = [Dictionary<String,String>]()
        for beacon in beacons {
            
            let major = String(format: "%05d", beacon.major.integerValue);
            let minor = String(format: "%05d", beacon.minor.integerValue);
            
            let serial = "\(beacon.proximityUUID.UUIDString)-\(major)-\(minor)"
            let rssi = "\(beacon.rssi)"
            
            let beaconDic = ["serial":serial, "rssi":rssi]
            beaconsDicArray.append(beaconDic)
        }
        
        var accu = 0.0
        var loc = CLLocation(latitude: 0, longitude: 0)
        if location != nil {
            loc = location!
        }
        
        let accuracy = location?.horizontalAccuracy
        if accuracy != nil {
            accu = accuracy!
        }
        
        let geoInfo = ["latitude":loc.coordinate.latitude, "longitude":loc.coordinate.longitude, "accuracy":accu]
        
        let param:Dictionary<String,AnyObject> = ["id":gateway.id,"name":gateway.name,"description":"","type":"3", "beacons":beaconsDicArray, "geo_info":geoInfo]
        
        self.sendData("POST", url: "\(kDETECTURL)/gw_app", encoding:.JSON, params: param, completion: {(result,info) in
            completion(result: result)
        })
    }
    
    func sendDetectedBeacons(beacons:[CLBeacon],connectedLineables:[Lineable],location:CLLocation?, completion:(result:Int,missingLineable:Lineable?)->()) {
        
        var beaconsDicArray = [Dictionary<String,String>]()
        for beacon in beacons {
            
            let major = String(format: "%05d", beacon.major.integerValue);
            let minor = String(format: "%05d", beacon.minor.integerValue);
            
            let serial = "\(beacon.proximityUUID.UUIDString)-\(major)-\(minor)"
            let rssi = "\(beacon.rssi)"
            
            let beaconDic = ["serial":serial, "rssi":rssi]
            beaconsDicArray.append(beaconDic)
        }
        
        for lineable in connectedLineables {
            
            if lineable.device.devicePeripheral?.peripheral?.state != CBPeripheralState.Connected { continue }
            
            let serial = lineable.device.serial
            let rssi = "\(lineable.device.signal.rssi)"
            
            let beaconDic = ["serial":serial, "rssi":rssi]
            beaconsDicArray.append(beaconDic)
        }
        
        var accu = 0.0
        var loc = CLLocation(latitude: 0, longitude: 0)
        if location != nil {
            loc = location!
        }
        
        let accuracy = location?.horizontalAccuracy
        if accuracy != nil {
            accu = accuracy!
        }
        
        let geoInfo = ["latitude":loc.coordinate.latitude, "longitude":loc.coordinate.longitude, "accuracy":accu]
        
        var param:Dictionary<String,AnyObject> = ["phone_type":"1", "beacons":beaconsDicArray, "geo_info":geoInfo]
        if User.me != nil {
            param["user_seq"] = "\(User.me!.seq)"
        }
        
        self.sendData("POST", url: "\(kDETECTURL)/app", encoding:.JSON, params: param, completion: {(result,infoarray) in
            
            let info = infoarray as? [[String:AnyObject]]
            if info != nil {
                let missingLineable:[String:AnyObject]? = info?.count == 0 ? nil : info?[0]
                
                if let lineableDic = missingLineable {
                    let lineable = Lineable(withDic: lineableDic)
                    completion(result: result, missingLineable: lineable)
                }
                else {
                    completion(result: result, missingLineable: nil)
                }
            }
            else {
                completion(result: result, missingLineable: nil)
            }
            
        })
    }
    
    func sendHeartbeat(location:CLLocation?) {
        
        guard let deviceUUID = UIDevice.currentDevice().identifierForVendor?.UUIDString else {
            return
        }
        var accu = 0.0
        var loc = CLLocation(latitude: 0, longitude: 0)
        if location != nil {
            loc = location!
        }
        let accuracy = location?.horizontalAccuracy
        if accuracy != nil {
            accu = accuracy!
        }
        
        let geoInfo = ["latitude":loc.coordinate.latitude, "longitude":loc.coordinate.longitude, "accuracy":accu]
        
        let param:Dictionary<String,AnyObject> = ["type":"1", "id":deviceUUID, "geo_info":geoInfo]
        
        self.sendData("POST", url: "\(kDETECTURL)/heartbeat",encoding:.JSON, params: param, completion: {(result,info) in
            
        })
    }

}

protocol LineableHTTP {}

enum LineableHTTPEncodingType {
    case JSON
    case URL
}

private extension NSMutableURLRequest {
    func setBodyContent(contentMap: Dictionary<String, AnyObject>) {
        var firstOneAdded = false
        var contentBodyAsString = String()
        let contentKeys:Array<String> = Array(contentMap.keys)
        for contentKey in contentKeys {
            let value = "\(contentMap[contentKey]!)"
            
            if(!firstOneAdded) {
                contentBodyAsString = contentBodyAsString + contentKey + "=" + value
                firstOneAdded = true
            }
            else {
                contentBodyAsString = contentBodyAsString + "&" + contentKey + "=" + value
            }
        }
        contentBodyAsString = contentBodyAsString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        self.HTTPBody = contentBodyAsString.dataUsingEncoding(NSUTF8StringEncoding)
    }
}

private extension LineableHTTP {
    
    private func escape(string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        let allowedCharacterSet = NSCharacterSet.URLQueryAllowedCharacterSet().mutableCopy() as! NSMutableCharacterSet
        allowedCharacterSet.removeCharactersInString(generalDelimitersToEncode + subDelimitersToEncode)
        
        let escaped = string.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacterSet) ?? string

        return escaped
    }
    
    private func queryComponents(key: String, _ value: AnyObject) -> [(String, String)] {
        var components: [(String, String)] = []
        
        if let dictionary = value as? [String: AnyObject] {
            for (nestedKey, value) in dictionary {
                components += queryComponents("\(key)[\(nestedKey)]", value)
            }
        } else if let array = value as? [AnyObject] {
            for value in array {
                components += queryComponents("\(key)[]", value)
            }
        } else {
            components.append((escape(key), escape("\(value)")))
        }
        
        return components
    }
    
    private func encodedRequest(encoding:LineableHTTPEncodingType,request:NSMutableURLRequest,parameters:[String:AnyObject]?) -> NSMutableURLRequest {

        guard let parameters = parameters else { return request }
        
        var mutableURLRequest = request
        var encodingError: NSError? = nil
        
        switch encoding {
        case .URL:
            func query(parameters: [String: AnyObject]) -> String {
                var components: [(String, String)] = []
                
                for key in parameters.keys.sort(<) {
                    let value = parameters[key]!
                    components += queryComponents(key, value)
                }
                
                return (components.map { "\($0)=\($1)" } as [String]).joinWithSeparator("&")
            }
            
            if let
                URLComponents = NSURLComponents(URL: mutableURLRequest.URL!, resolvingAgainstBaseURL: false)
                where !parameters.isEmpty
            {
                let percentEncodedQuery = (URLComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + query(parameters)
                URLComponents.percentEncodedQuery = percentEncodedQuery
                mutableURLRequest.URL = URLComponents.URL
            }
        case .JSON:
            do {
                let options = NSJSONWritingOptions()
                let data = try NSJSONSerialization.dataWithJSONObject(parameters, options: options)
                
                mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                mutableURLRequest.HTTPBody = data
            } catch {
                encodingError = error as NSError
            }
        }
        
        return mutableURLRequest
    }
    
    private func sendData(type:String,url:String,encoding:LineableHTTPEncodingType,params:[String:AnyObject]?,completion:(result:Int,info:AnyObject?)->()) {
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        sessionConfig.timeoutIntervalForResource = 45
        
        let session = NSURLSession(configuration: sessionConfig)
        
        let postsEndpoint: String = url
        var postsUrlRequest = NSMutableURLRequest(URL: NSURL(string: postsEndpoint)!)
        postsUrlRequest.HTTPMethod = type
        
        if User.me != nil {
            var defaultHeaders = [String:String]()
            
            let bundleVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as! String
            defaultHeaders["User-Agent"] = "Lineable for iOS\(UIDevice.currentDevice().systemVersion) \(bundleVersion)"
            defaultHeaders["version_code"] = bundleVersion
            defaultHeaders["phone_type"] = "1"
            defaultHeaders["push_type"] = "APNS"
            defaultHeaders["phone_model"] = UIDevice.currentDevice().modelName
            if let token = User.fetchToken() {
                defaultHeaders["x-token"] = token
            }
            defaultHeaders["app_push_id"] = User.fetchDeviceKey()
            
            for (headerField, headerValue) in defaultHeaders {
                //let encodedField = headerValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
                //let encodedName = headerValue.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
                postsUrlRequest.addValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
        
        postsUrlRequest = self.encodedRequest(encoding, request: postsUrlRequest, parameters: params)
        
        let task = session.dataTaskWithRequest(postsUrlRequest, completionHandler: {
            (data, response, error) -> Void in
            
            guard let data = data else { return }
            do {
                let result = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                    as! NSDictionary
                
                guard let resultCode = result["result"]!.integerValue else {
                    completion(result: 1009, info: nil)
                    return
                }
                
                completion(result: resultCode, info: result["info"])
                
            } catch _ {
                completion(result: 1009, info: nil)
            }
        })
        
        task.resume()
        
    }
    
}
