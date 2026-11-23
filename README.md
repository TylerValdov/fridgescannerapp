# Fridge Scanner

Our CS 3714 final project is an iPhone & iPad capable app for anyone who shares a fridge (or pantry) within a household. It allows users to add their own items, create a grocery list, put their dietary restrictions in, and get recipes based on those restrictions and their ingredients.

- Shared fridge list with expiration dates and reminders ( + notifications) of when items expire
- Barcode scanner to add groceries a lot easier (only works on a real phone since it needs the camera and permissions)
- Search recipes based on what's in your fridge currently, which warns you about restrictions and can find ones that are only a few ingredients off
- Admin sets the diet rules for the whole house and everyone can set their individual dietary restrictions on top of that
- Favorites and recently cooked recipes show up on the homepage to ensure easy access, additionally "mark as cooked" removes ingredients from fridge
- Shared shopping list, checked items can be moved directly to fridge
- Map of nearby grocery stores when items are needed
- Separate admin and member accounts to ensure following of dietary restrictions throughout the household

## How to run it

1. Download .zip, then unzip it and open `fridgescannerapp.xcodeproj` in Xcode
2. Make sure the scheme is `fridgescannerapp` and pick an iPhone or iPad simulator on iOS 17+
3. Hit the "Run" button
4. Sign in with one of the demo accounts at the bottom (all login information at the bottom)

`Secrets.swift` has our Spoonacular API key in it already, so nothing should need to be changed to get it working witho ur app

To run it on an actual phone, it must be signed separately with Signing & Capabilities, then actually put on a phone and disconnected from the Mac

## From a fresh clone

`Secrets.swift` isnt in the GitHub repo so you have to make it first

1. Copy `fridgescannerapp/Secrets.swift.example` to `fridgescannerapp/Secrets.swift`
2. Put a key from https://spoonacular.com/food-api/console in it, or just leave the placeholder and it'll use the demo recipes

## Demo data / offline

If there's no API key or the free daily limit runs out (or offline), the app switches to use the 24 demo recipes that we built into the project and the recipes screen will let you know when those are being used. Everything else is saved locally so it works offline.

## Demo accounts

Password for all of them is `Fridge123`

- Maple St Apartment (invite code `MAPLE1`): dana (admin), marcus, priya, leo
- Valdov Family (invite code `VALDOV`): tyler (admin), sam, jordan, ava
