# Fridge Scanner

CS 3714 final project. Fridge Scanner helps a household that shares a fridge cook with what it already has. Members add what's in the fridge, and the app finds recipes they can make now or with only a few more ingredients, following the household's diet rules. Missing ingredients go on a shared shopping list, and cooking a recipe clears what it used out of the fridge.

Runs on **iPhone** (a tab bar: Home, Fridge, Recipes, Shopping, Household) and **iPad** (a sidebar with all six sections, including Preferences).

## Setup

1. Copy `fridgescannerapp/Secrets.swift.example` to `fridgescannerapp/Secrets.swift` and paste your key from the [Spoonacular console](https://spoonacular.com/food-api/console). `Secrets.swift` is gitignored, and the project doesn't compile without it.
2. Open `fridgescannerapp.xcodeproj` in Xcode 16 or later.
3. Pick an iPhone or iPad simulator running iOS 17 or later, then press Run.

While the key is still the placeholder, once the free tier's 50 daily points are used up, or when the device is offline, the app uses **demo data**: 24 real Spoonacular recipes bundled in `MockData/MockRecipes.json`, matched against the fridge on the device. The Recipes screen says when demo data is showing.

> Upgrading from an earlier build? Delete the app from the simulator or device first. The data model changed.

## Demo accounts

The app adds two households on first launch. Every demo account's password is **`Fridge123`**.

| Household | Invite code | Admin | Members | Diet rules |
| --- | --- | --- | --- | --- |
| Maple St Apartment | `MAPLE1` | `dana` | `marcus`, `priya`, `leo` | none |
| Valdov Family | `VALDOV` | `tyler` | `sam`, `jordan`, `ava` | dairy-free |

## Features

| Feature | Screen |
| --- | --- |
| Sign in, and create an account that starts or joins a household | Sign In |
| Two user types: the admin sets diet rules and can remove members; members view them | Household, Preferences |
| Shared fridge: add with autocomplete and an optional expiration date, swipe to remove, Undo | Fridge |
| Recipe search grouped by how many ingredients are missing | Recipes |
| Recipe details, favorites, and Mark as Cooked (removes the ingredients used, with Undo) | Recipe details, Home |
| Meal preferences: 11 diets, 12 intolerances, must-include and excluded ingredients, max missing | Preferences |
| Shared shopping list: add by hand or from a recipe's missing ingredients, check off, move to the fridge | Shopping |
| Offline mode: saved data works as usual, and recipes fall back to demo data | Everywhere |

Passwords are stored only as salted SHA-256 hashes (`Models/AuthModel.swift`), never as plain text.

## Project structure

```
fridgescannerapp/
├── fridgescannerappApp.swift   App entry and RootView (sign-in or the main app)
├── Models/
│   ├── DataModels.swift        The 6 SwiftData models and the Diet and Intolerance lists
│   ├── ModelLinks.swift        Helpers that connect models to each other
│   ├── Account.swift           Account, AdminAccount, MemberAccount (what each role can do)
│   ├── AuthModel.swift         Sign-in, sign-up, removing members, password hashing, sign-up rules
│   ├── RecipeSearchModel.swift The fridge, recipe search, recipe details, Undo
│   ├── ShoppingListModel.swift The shopping list
│   ├── SavedRecipeStore.swift  Favorites and cooking history
│   └── SampleData.swift        The demo households
├── Services/RecipeAPI.swift    Recipe types, RecipeProvider, and its Spoonacular and demo subclasses
├── Utilities/Helpers.swift     API key, ingredient matching, text formatting
├── Views/                      One file per screen, plus SharedViews.swift (Undo banner, toast)
└── MockData/                   Bundled demo recipes
```

**Data model:** a **Household** has many **User**s, **FridgeItem**s and **ShoppingListItem**s, and one **MealPreferences**; deleting it deletes all of them. Each **User** has a role and many **SavedRecipe**s (favorites and cooking history).

## Programming paradigms

Each spot is marked in the code with an `// OOP:`, `// Procedural:` or `// Functional:` comment.

| Paradigm | Where |
| --- | --- |
| Object-oriented | `Account` with `AdminAccount` and `MemberAccount` overriding what each role can do; `RecipeProvider` with `SpoonacularProvider` and `MockRecipeProvider` overriding the three requests; the SwiftData model classes. |
| Procedural | `Utilities/Helpers.swift`, and the password and sign-up rule functions in `AuthModel.swift`: plain functions with no shared state. |
| Functional | `MockRecipeProvider.searchRecipes` (filter, map, sort), `RecipeSearchModel.sections`, `SavedRecipeStore.likedRecipes`, `CreateAccountView.isValid` (`allSatisfy`), and others marked in the code. |

## The 8 golden rules of interface design

| Rule | How the app applies it |
| --- | --- |
| Strive for consistency | The same sections on iPhone and iPad, standard iOS lists, swipe actions and empty states, and one accent color. |
| Seek universal usability | Separate iPhone and iPad layouts, Dynamic Type through standard controls, and VoiceOver labels on icon-only items. |
| Offer informative feedback | Spinners while searching and loading a recipe; labels when demo or offline data is showing; error messages. |
| Design dialogs to yield closure | "Saved to Favorites", "Added 2 to your shopping list" and "Moved 3 items to the fridge" confirmations; creating an account goes straight into the app. |
| Prevent errors | Sign-up explains each problem as you type and disables the button until it's fixed; duplicate fridge and shopping items get a message; removing a member asks first; members can't edit the diet rules. |
| Permit easy reversal | Undo for 5 seconds after removing fridge items, including after cooking; shopping items can be unchecked; tapping the heart again removes a favorite. |
| Keep users in control | Searches run only when the user taps Find Recipes or pulls to refresh. |
| Reduce short-term memory load | The diet rules are summarized on Recipes; fridge items show who added them and when they expire; each recipe lists what's missing; the demo accounts are listed on the sign-in screen. |

## Known issues

- The app icon hasn't been designed yet.
- Demo-data matching approximates Spoonacular's diet and intolerance rules, and offline search only covers the 24 demo recipes.
