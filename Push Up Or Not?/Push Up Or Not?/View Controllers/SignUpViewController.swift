//
//  SignUpViewController.swift
//  Push Up Or Not?
//
//  Created by Kenny Yu on 9/15/20.
//  Copyright © 2020 Kenny Yu. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import SwiftSpinner

class SignUpViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    // MARK: IBOutlets
    @IBOutlet weak var nameOfUser: UITextField!
    @IBOutlet weak var userSignUpEmail: UITextField!
    @IBOutlet weak var userSignUpPassword: UITextField!
    @IBOutlet weak var userSignUpPasswordConfirm: UITextField!
    
    @IBAction func userSignUp(_ sender: UIButton) {
        // Show the spinner
        SwiftSpinner.show("Signing Up...")
        
        // Check if the password and the confirmation match
        if userSignUpPassword.text != userSignUpPasswordConfirm.text {
            // let the user know something is wrong
            let noMatchAlert = UIAlertController(title: "Password doesn't match", message: "Please re-enter password", preferredStyle: .alert)
            let responseAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            noMatchAlert.addAction(responseAction)
            
            // Hide spinner and show alert
            SwiftSpinner.hide(){
                self.present(noMatchAlert, animated: true, completion: nil)
            }
        } else {
            // Since no issues, sign the user up
            let credential = EmailAuthProvider.credential(withEmail: userSignUpEmail.text!, password: userSignUpPassword.text!)
            
            // Linkes the credential to currently signed in user
            Auth.auth().currentUser?.link(with: credential, completion: { (authResult, error) in
                if error != nil {
                    
                    // Creates alert in case something fails with authentication
                    let noMatchAlert = UIAlertController(title: "Error Signing Up", message: error?.localizedDescription, preferredStyle: .alert)
                    let responseAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                    noMatchAlert.addAction(responseAction)
                    
                    // Hide spinner, tell user the error
                    SwiftSpinner.hide() {
                        self.present(noMatchAlert, animated: true, completion: nil)
                    }
                } else {
                    print(credential.provider)
                    
                    // Sign the user in
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let secondVC = storyboard.instantiateViewController(identifier: "NavigationViewController")
                    secondVC.modalPresentationStyle = .fullScreen
                    secondVC.modalTransitionStyle = .crossDissolve
                    
                    // Hide spinner and launch main page
                    SwiftSpinner.hide() {
                    self.present(secondVC, animated: true, completion: nil)
                    }
                    
                }
            })
        }
    }
    @IBAction func signInRedirect(_ sender: UIButton) {
        
    }
    
    

}
