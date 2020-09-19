//
//  SignInViewController.swift
//  Push Up Or Not?
//
//  Created by Kenny Yu on 9/10/20.
//  Copyright © 2020 Kenny Yu. All rights reserved.
//

import UIKit
import FirebaseAuth
import Firebase
import SwiftSpinner

class SignInViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    // MARK: Alert Controllers
    // var errorAlert: UIAlertController
    // var errorAction: UIAlertAction


    // MARK: IBOutlets
    @IBOutlet weak var userSignInEmail: UITextField!
    @IBOutlet weak var userSignInPassword: UITextField!
    
    @IBAction func userSignIn(_ sender: UIButton) {
        // Show the spinner when the user signs in
        SwiftSpinner.show("Signing In...")
        
        // Attempt sign in
        Auth.auth().signIn(withEmail: userSignInEmail.text!, password: userSignInPassword.text!) { (user, error) in
            
            // if no errors
            if error == nil {
                print("Successfully Signed In")
                
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let secondVC = storyboard.instantiateViewController(identifier: "NavigationViewController")
                secondVC.modalPresentationStyle = .fullScreen
                secondVC.modalTransitionStyle = .crossDissolve
                SwiftSpinner.hide() {
                    self.present(secondVC, animated: true, completion: nil)
                }
            } else {
                // Create the alert to notify the user there was an error
                let errorAlert = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
                let errorAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                
                // Add the action to the alert
                errorAlert.addAction(errorAction)
                                
                // Show to the user
                SwiftSpinner.hide(){
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Establish a correct window hierarchy
        

    }
    
    
}

