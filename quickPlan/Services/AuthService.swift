//
//  AuthService.swift
//  quickPlan
//
//  Created by André Rosa on 28/03/2018.
//  Copyright © 2018 Andre Rosa. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

// MARK: Service to persist throught the app

class AuthService {
    
    static let instance = AuthService()
    
    let defaults = UserDefaults.standard
    
    var isLoggedIn: Bool{
        get{
            return defaults.bool(forKey: Constants.UserDefaults.LoggedInKey)
        }
        set{
            defaults.set(newValue, forKey: Constants.UserDefaults.LoggedInKey)
        }
    }
    
    var authToken: String{
        get{
            return defaults.value(forKey: Constants.UserDefaults.TokenKey) as! String
        }
        set{
            defaults.set(newValue, forKey: Constants.UserDefaults.TokenKey)
        }
    }

    var userEmail: String{
        get{
            return defaults.value(forKey: Constants.UserDefaults.UserEmail) as! String
        }
        set{
            defaults.set(newValue, forKey: Constants.UserDefaults.UserEmail)
        }
    }
    
    
    func registerUser(email: String, password: String, completion: @escaping CompletionHandler) {
        
        let lowerCaseEmail = email.lowercased()

        let body: [String: Any] = [
            "email": lowerCaseEmail,
            "password": password
        ]

        Alamofire.request(Constants.Urls.UrlRegister, method: .post, parameters: body, encoding: JSONEncoding.default, headers: Constants.Headers.AppJson).responseString { (response) in
            if response.result.error == nil {
                completion(true)
                
            } else {
                completion(false)
                debugPrint(response.result.error as Any)
            }
        }

        return
    }
    
    func loginUser(email: String, password: String, completion: @escaping CompletionHandler){
        let lowerCaseEmail = email.lowercased()
        
        let body: [String: Any] = [
            "email": lowerCaseEmail,
            "password": password
        ]
        
        Alamofire.request(Constants.Urls.UrlLogin, method: .post, parameters: body, encoding: JSONEncoding.default, headers: Constants.Headers.AppJson).responseJSON { (response) in
            if response.result.error == nil{
//                if let json = response.result.value as? Dictionary<String, Any> {
//                    if let email = json["user"] as? String{
//                        self.userEmail = email
//                    }
//                    if let token = json["token"] as? String {
//                        self.authToken = token
//                    }
//                }
                
                // MARK: With SwiftyJSON
                do{
                    guard let data = response.data else {return}
                    let json = try JSON(data: data)
                    
                    self.authToken = json["token"].stringValue
                    self.userEmail = json["user"].stringValue
                    
                    completion(true)
                    self.isLoggedIn = true
                } catch {
                    debugPrint("Problem Get data")
                }
               
                
            } else {
                completion(false)
                debugPrint(response.result.error as Any)
            }
        }
    }
    
    
    
    
    
    
}
