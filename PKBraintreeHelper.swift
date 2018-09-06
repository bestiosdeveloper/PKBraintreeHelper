//
//  PKBraintreeHelper.swift
//
//  Created by Pramod Kumar on 23/08/18.
//  Copyright © 2018 Pramod Kumar. All rights reserved.
//

import UIKit
import BraintreeDropIn
import Braintree


/********************************************************************************************************************************************************
************************************************************ Setup BrainTree OneTouch Payment ***********************************************************
 
 STEP-1: Under URL Schemes, enter your app switch return URL scheme. This scheme must start with your app's Bundle ID and be dedicated to Braintree app switch returns. For example, if the app bundle ID is com.your-company.Your-App, then your URL scheme could be com.your-company.Your-App.payments
 
 
 STEP-2:
 
 //*****  Add the following method in your appdelegate ******//

 func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
    if let bundelId = Bundle.main.bundleIdentifier, url.scheme?.localizedCaseInsensitiveCompare("\(bundelId).payments") == .orderedSame {
        return BTAppSwitch.handleOpen(url, options: options)
    }
 
    return true
 }
 
 
 To know more visit: https://developers.braintreepayments.com/guides/paypal/client-side/ios/v4
 
 ********************************************************************************************************************************************************
 ********************************************************** For Testing Purpuse Use *********************************************************************

                                                        Card Number: 4111111111111111
                                                        Expiration: 08/2021
 
 ********************************************************************************************************************************************************
 ********************************************************************************************************************************************************/

enum PKBraintreeHelperError {
    case success
    case failed
    case cancelled
    case unknown
    
    var message: String{
        switch self {
        case .success: return "Payment has been done!"
        case .failed: return "Payment has been failed!"
        case .cancelled: return "Payment has been cancelled!"
        case .unknown: return "Something went wrong please try again!"
        }
    }
    
    var code: Int{
        switch self {
        case .success: return 100
        case .failed: return 101
        case .cancelled: return 102
        case .unknown: return 103
        }
    }
}

class PKBraintreeHelper: NSObject {
    
    //MARK:- Shared Object
    //MARK:-
    static let shared = PKBraintreeHelper()
    private override init() { }
    
    //MARK:- Properties
    //MARK:- Private
    fileprivate var paymentComplitionHandler: ((Bool, NSError)->Void)?
    
    //MARK:- Public
    var isLogEnabled: Bool = true
    
    //MARK:- Methods
    //MARK:- Public
    func makePayment(onViewController: UIViewController, toKinizationKey: String, forAmount amount: Double, forCurrencyCode currencyCode: String, serverPaymentUrl: String, complition: ((Bool, NSError)->Void)? = nil) {
        
        guard !serverPaymentUrl.isEmpty, let url = URL(string: serverPaymentUrl) else {
            fatalError("Please pass a valid server payment url")
        }
        
        if let bundelId = Bundle.main.bundleIdentifier {
            BTAppSwitch.setReturnURLScheme("\(bundelId).payments")
        }
        
        self.paymentComplitionHandler = complition
        
        let request =  BTDropInRequest()
        request.amount = "\(amount)"
        request.currencyCode = currencyCode
        let dropIn = BTDropInController(authorization: toKinizationKey, request: request) { [weak self] (controller, result, error) in
            
            if let err = error {
                if err.localizedDescription.lowercased() == "The operation couldn’t be completed. Application does not support One Touch callback URL scheme".lowercased() {
                    self?.log("The operation couldn’t be completed. Application does not support One Touch callback URL scheme \n To know more visit https://developers.braintreepayments.com/guides/paypal/client-side/ios/v4")
                }
                self?.executeComplition(code: PKBraintreeHelperError.unknown.code, message: err.localizedDescription)
            }
            else if (result?.isCancelled == true) {
                self?.executeComplition(code: PKBraintreeHelperError.cancelled.code, message: PKBraintreeHelperError.cancelled.message)
            }
            else if let nonce = result?.paymentMethod?.nonce {
                self?.sendPaymentRequestToServer(url: url, nonce: nonce, amount: amount)
            }
            controller.dismiss(animated: true, completion: nil)
        }
        
        onViewController.present(dropIn!, animated: true, completion: nil)
    }

    
    //MARK:- Private
    private func log <T> (_ object: T) {
        if isLogEnabled {
            NSLog("\(object)")
        }
    }
    
    private func sendPaymentRequestToServer(url: URL, nonce: String, amount: Double) {
        
        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.httpMethod = "POST" //set http method as POST
        request.allHTTPHeaderFields = ["Content-Type": "application/x-www-form-urlencoded"]
        
        request.httpBody = "nounce=\(nonce)&amount=\(amount)".data(using: String.Encoding.utf8)
        
        //create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request as URLRequest, completionHandler: { [weak self] (data, response, error) -> Void in
            guard let data = data else {
                self?.executeComplition(code: PKBraintreeHelperError.unknown.code, message: error?.localizedDescription ?? PKBraintreeHelperError.unknown.message)
                return
            }
            
            let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any] ?? [:]
            guard let result = json, let status = result["status"] , "\(status)" == "1" else {
                self?.executeComplition(code: PKBraintreeHelperError.failed.code, message: PKBraintreeHelperError.failed.message)
                return
            }
            
            //handle you response according to sent by your server
            
            self?.executeComplition(code: PKBraintreeHelperError.success.code, message: PKBraintreeHelperError.success.message)
        })
        task.resume()
    }
    
    private func executeComplition(code: Int, message: String) {
        log("Message from PKBraintreeHelper with code: \(code), and message: \(message)")
        
        if let handel = self.paymentComplitionHandler {
            let err = NSError(code: code, localizedDescription: message)
            handel(code == PKBraintreeHelperError.success.code, err)
        }
    }
}

