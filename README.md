# Fridge Scanner

CS 3714 final project. Fridge Scanner helps a household that shares a fridge cook with what it already has. Members add what's in the fridge, and the app finds recipes they can make now or with only a few more ingredients. Recipe matching respects the household's diet rules.

Runs on **iPhone** (tab bar) and **iPad** (sidebar, with the recipe list and the selected recipe side by side).

## Setup

1. Open `fridgescannerapp.xcodeproj` in Xcode 16 or later.
2. Pick an iPhone or iPad simulator running iOS 17 or later, then press Run. No Team or Bundle Identifier changes are needed for the simulator.
3. Optional, for live recipe data: copy `fridgescannerapp/Secrets.plist.example` to `fridgescannerapp/Secrets.plist` and paste your key from the [Spoonacular console](https://spoonacular.com/food-api/console). `Secrets.plist` is gitignored.

Without a key, or once the free tier's 50 daily points are used up, the app switches to **demo data**: 24 real Spoonacular recipes bundled in `MockData/MockRecipes.json`, matched against the fridge on the device. The Recipes screen says when demo data is showing.

> Upgrading from an earlier build? Delete the app from the simulator or device first. The data model changed, and the old ingredient list can't be migrated.

## Demo accounts

The app adds two households on first launch. Every demo account's password is **`Fridge123`**.

| Household | Invite code | Admin | Members | Diet rules |
| --- | --- | --- | --- | --- |
| Maple St Apartment | `MAPLE1` | `dana` | `marcus`, `priya`, `leo` | none |
| Valdov Family | `VALDOV` | `tyler` | `sam`, `jordan`, `ava` | dairy-free |

## User types

| Admin | Member |
| --- | --- |
| Creates the household and gets its invite code | Joins with an invite code |
| Sets the household's diet, intolerances, and must-include and excluded ingredients | Sees the diet rules, read-only |
| Renames the household and removes members | Sees who else is in the household |
| Everything a member can do | Adds and removes fridge items, finds recipes, favorites them, marks them cooked |

## Security

- Passwords must be at least 8 characters, with a letter and a number. Usernames are 3 to 20 letters or numbers.
- Passwords are stored only as PBKDF2-SHA256 hashes (100,000 rounds, a random 16-byte salt per user), using CommonCrypto. See `Auth/PasswordHasher.swift`.
- After 5 wrong passwords, sign-in is blocked for 30 seconds.
- Face ID or Touch ID sign-in can be turned on from the Household screen. The device's biometric check protects it; only the username is stored.

## Project structure

```
fridgescannerapp/
├── fridgescannerappApp.swift   App entry; SwiftData container for all 5 models
├── Models/                     SwiftData models, Account roles, app state, sample data
├── Services/                   RecipeProvider and its Spoonacular and demo-data subclasses
├── Auth/                       AuthModel (sign-in, sign-up, Face ID) and password hashing
├── Utilities/                  Formatting, validation, Secrets.plist loading
├── Views/                      Screens; Views/Auth for sign-in, Views/Components for shared pieces
└── MockData/                   Bundled demo recipes
```

### Data model (SwiftData)

- **Household** has many **User**s, many **FridgeItem**s and one **MealPreferences**. Deleting a household deletes all of them.
- **User** has a role (admin or member) and many **SavedRecipe**s (favorites and cooking history), deleted with the user.
- **FridgeItem** records which **User** added it, and an optional expiration date.

## Programming paradigms

Each spot is marked in the code with an `// OOP:`, `// Procedural:` or `// Functional:` comment.

| Paradigm | Where |
| --- | --- |
| Object-oriented | `Models/Account.swift`: `Account`, with `AdminAccount` and `MemberAccount` overriding what each role can do. `Services/RecipeProvider.swift`: `RecipeProvider`, with `SpoonacularProvider` and `MockRecipeProvider` overriding the three requests. The SwiftData model classes in `Models/`. |
| Procedural | `Utilities/Formatting.swift`, `Utilities/Validation.swift` and `Auth/PasswordHasher.swift`: plain functions with no shared state. |
| Functional | `MockRecipeProvider.searchRecipes` (filter, map, sort), `RecipeSearchModel.sections`, `SavedRecipeStore.likedRecipes` and `recentRecipes`, `CreateAccountView.isValid` (`allSatisfy`), and the byte comparison in `PasswordHasher.swift` (`zip` and `reduce`). |

## The 8 golden rules of interface design

| Rule | How the app applies it |
| --- | --- |
| Strive for consistency | The same five sections on iPhone and iPad, shared components (`EmptyStateView`, recipe rows, the heart button), and the same wording for the same action everywhere. |
| Seek universal usability | Tailored iPhone and iPad layouts, Dynamic Type (`AdaptiveStack`, scaled icons), VoiceOver labels, and Face ID as a shortcut for frequent users. |
| Offer informative feedback | Spinners while signing in, setting up sample data, searching and loading a recipe; the remaining API points; a label when demo data is showing; a note when results are out of date. |
| Design dialogs to yield closure | "Saved to Favorites" after favoriting, "Added to Recently Used" after cooking, and creating an account goes straight into the app. |
| Prevent errors | Sign-up explains each field's problem as you type and keeps the button disabled until everything is valid; duplicate ingredients get a message; confirmations before removing a member, resetting preferences or signing out; members can't edit the household's rules. |
| Permit easy reversal | An Undo banner for 5 seconds after removing a fridge item; tapping the heart again removes a favorite. |
| Keep users in control | Searches run only when the user taps Find Recipes or pulls to refresh, so nothing changes, and no quota is spent, without them asking. |
| Reduce short-term memory load | The active diet rules are summarized on the Recipes screen; each fridge item shows who added it and when it expires; each recipe lists what's missing; the demo accounts are listed on the sign-in screen. |

## Known issues

- The app icon hasn't been designed yet.
- Live search results aren't saved for offline use yet. Without a connection, recipe searches fail unless the app is using demo data.
- No automated tests yet.
- Demo-data matching approximates Spoonacular's diet and intolerance rules using the flags in its data.
