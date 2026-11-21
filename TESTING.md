# Testing

How Fridge Scanner is tested: automated unit and UI tests, plus manual misuse cases. Requirement numbers refer to the 9 functional requirements in the README.

## How to run

1. Open `fridgescannerapp.xcodeproj` and pick an **iPhone simulator** (the UI test assumes the iPhone tab bar).
2. Press **⌘U**. Results appear in the Test navigator (⌘6) and the Report navigator (⌘9).

The unit tests use an in-memory copy of the demo data and the bundled demo recipes, so they don't touch the app's saved data or spend API quota. The UI test signs in as `dana`, then deletes the item it adds, so the demo fridge is unchanged after each run.

## Automated tests

Unit tests: `fridgescannerappTests/fridgescannerappTests.swift` (Swift Testing). UI test: `fridgescannerappUITests/fridgescannerappUITests.swift` (XCTest).

| Test | Requirement | Steps | Expected result | Actual result | Pass/Fail |
|---|---|---|---|---|---|
| `ingredientNameHelpers` | 2, 3 | Normalize, match and pluralize sample names | "  Eggs " → "eggs"; "egg" matches "Eggs"; "garlic" matches "garlic cloves"; "1 item", "3 items" | As expected | Pass |
| `usernameRules` | 1 | Check valid and invalid usernames | "dana" is fine; too short, too long and symbols are rejected | As expected | Pass |
| `passwordRules` | 1, Security | Check valid and invalid passwords | "Fridge123" is fine; short, no number and no letter are rejected | As expected | Pass |
| `passwordHashing` | Security | Hash a password, verify right and wrong passwords | Right password verifies, wrong one doesn't; same password hashes differently (salt) | As expected | Pass |
| `shoppingListRejectsDuplicatesAndMovesToFridge` | 9 | Add "Zucchini", add it again, check it, move checked to fridge | Duplicate shows a message; item moves to the fridge and leaves the list | As expected | Pass |
| `removingAFridgeItemCanBeUndone` | 2, 5 | Remove the first fridge item, then Undo | Item is removed, then restored | As expected | Pass |
| `recipesAreGroupedByMissingCount` | 3 | Search the demo recipes with the demo fridge | Every recipe is in the right section; none exceed "max missing" | As expected | Pass |
| `testSignInAddAndRemoveFridgeItem` (UI) | 1, 2 | Sign in as `dana`, open Fridge, add a uniquely named item, swipe to delete it | Sign-in succeeds; item appears; item is gone after deleting | As expected | Pass |

Last full run: Nov 20, 2026, iPhone 17 simulator (iOS 27.2), 8 of 8 passed. **Sprint:** _fill in_. Add a screenshot of the passing run in the Test navigator here.

## Manual misuse cases

Run these by hand in the simulator and fill in the last two columns.

| Case | Requirement | Steps | Expected result | Actual result | Pass/Fail |
|---|---|---|---|---|---|
| Wrong password | 1 | Sign in as `dana` with password `wrong123` | "That username and password don't match."; password field clears | | |
| Short password on sign-up | 1 | Create an account with password `abc1` | "Use at least 8 characters." while typing; can't create | | |
| Taken username | 1 | Create an account with username `dana` | "That username is taken. Try another." | | |
| Wrong invite code | 1, 7 | Join a household with code `ZZZZZZ` | "No household has that invite code…" | | |
| Empty ingredient | 2 | On Fridge, leave the field blank | Add is disabled | | |
| Duplicate ingredient | 2 | Add "eggs" as `dana` (already in the fridge) | "Eggs is already in the fridge." | | |
| Duplicate shopping item | 9 | Add "potato" on Shopping as `dana` | "Potato is already on the list." | | |
| Member views Preferences | 6 | Sign in as `marcus`, open Preferences | Everything is read-only | | |
| Member manages household | 7, 8 | As `marcus`, open Household | No invite code, rename or remove options | | |
| Offline search | Reliability | Turn off the Mac's Wi-Fi, then Find Recipes | Demo recipes with "You're offline. Showing demo recipes." | | |
| No API key | Reliability | Put the placeholder key back in `Secrets.swift`, run, search | Demo recipes with the demo label | | |
| Scanner: unknown barcode | 2 | _After the scanner is added:_ scan a barcode Open Food Facts doesn't know | A message; the name can be typed instead | | |
| Scanner: no camera | 2 | _After the scanner is added:_ run on the simulator | No Scan button | | |
