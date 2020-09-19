# Push-Up-Or-Not
This iOS application tracks a person's body using a live camera feed to determine whether they are doing a push up with the correct form. Depending on which parts of the body are out of line, the app will put up suggestions to aid them in correcting their push up. In addition, the applicaiton will also track how many good push ups they've done. 

## Installation/Requirements
Since this application uses a live camera feed, you are going to need a physical iOS device in order to run it. In addition, I unfortunately do not have an Apple Developer account, so you will also need a Mac with the latest version of Xcode in order to install and test this application using your device. 

**Requirements:**
- an iOS device running iOS 13 (preferably with an A11 or newer)
- a Mac with Xcode 12+
- Firebase

**Installation:**
1. Install the pods needed for the application
```bash
# Assuming you're in the repo folder
cd Push\ Up\ Or\ Not?/
pod init
pod install
```
2. Open the .xcworkspace in Xcode
3. Click on the project name at the top level in the leftmost pane in Xcode
4. Navigate to "Signing & Capabilities" and set your own bundle ID and Development Team
5. Add Firebase to your project: https://firebase.google.com/docs/ios/setup
6. Find your device in the drop down menu near the top left corner of Xcode window
7. Run the application to install

## Some Implementation Details
The person detection and mapping of the points was done using Google MLKit's Vision Pose Estimation API. Verification of whether the person was doing a correct push up was done by taking the points outputted by each pose and checking the angles of the hips and knees. A similar method was used to verify whether person was going up or down, which was used to count repetitions. For practicality and future expansion of the application, I added a sign-up/sign-in flow for user sign in and future features such as interuser competitions and maybe even a leaderboard. As those features haven't been implemented yet, when a user first opens the app, they have a temporary account and if they like the application, there is a Sign Up/Sign In button to take them into the workflow to either sign up or sign back into their existing account. Once they're signed up or signed in, the button on the main screen turns into a Sign Out button.  

## API/Frameworks Used
- Google MLKit for Pose Estimation
- SwiftSpinner for transitions
- Firebase for login and data hosting

## Development Details
Initial bulk of development: Late August 2020 - Late September 2020

## Work in Progress
- Overhaul UI Elements
- Redo sign-in flow for better user experience
- Expand to integrate online features
- Create a model for movement detection to abate errors in detection
- Orientation Detection
- Some sort of leaderboard
