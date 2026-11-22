# Fridge Scanner: Project Notes

Working notes for the team and for any coding assistant (for example, the agent in Xcode). Read this before changing the project. Last updated Nov 20, 2026.

- **What it is:** a CS 3714 final team project. It's an iPhone and iPad app for a household that shares a fridge: members add what's in it, find recipes they can make (Spoonacular API), favorite and cook them, and keep a shared shopping list. An admin sets the household's diet rules.
- **Team:** Tyler Valdov (TylerValdov), gabrian2025, VedanthShivYellai, jwmyers05. Each person builds one advanced feature.
- **Repo:** GitHub `TylerValdov/fridgescannerapp`, branch `main`.
- **Rubric checklist:** the [audit doc](https://claude.ai/artifact/5Z1mG1znadgPXdMw8ZsC8d). It was last updated Nov 17 and is partly out of date. Where they differ, this file wins.

---

## 1. Setup on a Mac

1. `git pull`.
2. Copy `fridgescannerapp/Secrets.swift.example` to `fridgescannerapp/Secrets.swift`, and put the Spoonacular key in it.
   - `Secrets.swift` is gitignored. **Never commit it**, and never paste the key into chats, logs or docs.
   - The project doesn't compile without the file.
   - With the placeholder key, the app runs on demo data.
3. Open `fridgescannerapp.xcodeproj` (Xcode 16 or later). Pick an iPhone or iPad simulator on iOS 17 or later, then press Run.
4. After any change to the data model, delete the app from the simulator first. There are no SwiftData migrations.

**Project settings to keep:**
- iOS deployment target **17.0**.
- Swift 5 language mode.
- **Default actor isolation: MainActor.** App code is main-actor by default.
- Upcoming features on: `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `MemberImportVisibility`. Because of `MemberImportVisibility`, each file imports what it uses, e.g. `UIKit` for `UIPasteboard`.
- The project uses **folder-synced groups**. A new `.swift` file added to `fridgescannerapp/` joins the target automatically; there's no need to edit `project.pbxproj` by hand.

Demo accounts (password **`Fridge123`**):
- **Maple St Apartment** (code `MAPLE1`): `dana` (admin), `marcus`, `priya`, `leo`.
- **Valdov Family** (code `VALDOV`, dairy-free): `tyler` (admin), `sam`, `jordan`, `ava`.

The Spoonacular free tier is **50 points a day**, and a search costs about 1.7. When the quota runs out, the app switches to demo data on its own.

---

## 2. Code structure (21 Swift files, about 3,100 lines)

```
fridgescannerapp/
├── fridgescannerappApp.swift   App entry + RootView (seeds demo data, shows sign-in or ContentView)
├── Models/
│   ├── DataModels.swift        All 6 SwiftData @Model classes + UserRole, Diet (11), Intolerance (12)
│   ├── ModelLinks.swift        The ONLY place relationships are connected (insert first, then link)
│   ├── Account.swift           OOP: Account → AdminAccount / MemberAccount (role permissions, polymorphism)
│   ├── AuthModel.swift         Sign in/out, sign up, rename household, remove members,
│   │                           salted SHA-256 password hashing, sign-up rules (procedural)
│   ├── RecipeSearchModel.swift Fridge items, autocomplete, search, details, demo/offline fallback, Undo
│   ├── ShoppingListModel.swift Shared shopping list, move checked items to the fridge
│   ├── SavedRecipeStore.swift  Favorites and cooking history per user
│   └── SampleData.swift        2 households, 8 users, fridges, shopping lists; preview session
├── Services/RecipeAPI.swift    Recipe types + OOP: RecipeProvider → SpoonacularProvider / MockRecipeProvider
├── Utilities/Helpers.swift     Procedural helpers: API key, ingredient matching, text formatting
├── Views/
│   ├── ContentView.swift       AppSection; TabView on iPhone, NavigationSplitView sidebar on iPad
│   ├── HomeView.swift          (jwmyers05) greeting, Find Recipes, favorites, recently cooked
│   ├── IngredientEntryView.swift  Fridge tab
│   ├── RecipesView.swift       Recipe search results in sections
│   ├── RecipeDetailView.swift  (gabrian2025) details, favorite, Add Missing to Shopping List, Mark as Cooked
│   ├── ShoppingListView.swift  Shopping tab
│   ├── HouseholdView.swift     Name, invite code, members, Meal Preferences link, Sign Out
│   ├── PreferencesView.swift   Diet rules (admin edits, member read-only)
│   ├── SignInView.swift        SignInView + CreateAccountView
│   └── SharedViews.swift       Undo banner, confirmation toast, previewEnvironment()
└── MockData/MockRecipes.json   24 real Spoonacular recipes (demo and offline data)
```

**Data model:**
- A **Household** has many **User**s, **FridgeItem**s and **ShoppingListItem**s, and one **MealPreferences**. All are deleted with it.
- Each **User** has a role and many **SavedRecipe**s.
- **FridgeItem** records `addedBy`.

**Navigation:**
- **iPhone tabs:** Home, Fridge, Recipes, Shopping, Household. Preferences opens from a row in Household, or as a sheet from Recipes.
- **iPad sidebar:** all six sections.

**How state flows:**
- `ContentView` creates `RecipeSearchModel`, `SavedRecipeStore` and `ShoppingListModel` once per sign-in and puts them in the environment. Screens read them with `@Environment(Type.self)`.
- `AuthModel` comes from `RootView`.

---

## 3. Coding rules for this project

This is an **intro Swift class**. Keep the code at a level the team can explain line by line in the video.

- **Keep it simple:**
  - Prefer built-in SwiftUI (`List`, `Form`, `ContentUnavailableView`, `.swipeActions`, `.confirmationDialog`) over custom components.
  - No new packages or dependencies.
  - New features should usually be one file of about 100–150 lines.
  - Don't add caching layers, abstractions, or options nobody asked for.
- **Keep files compact, but not crammed:**
  - Put closely related types together (as in `DataModels.swift` and `RecipeAPI.swift`).
  - Keep one screen per view file. Aim for roughly 300 lines per file at most.
- **Every file starts with a header comment:** the filename, `fridgescannerapp`, then 1–3 plain sentences saying what the file is for. For example:
  ```swift
  //
  //  ShoppingListView.swift
  //  fridgescannerapp
  //
  //  The Shopping tab: the household's shared list. ...
  //
  ```
- **Comments:**
  - Explain *why* and any non-obvious logic, in plain words.
  - Add `///` doc comments on public functions where the name doesn't say enough.
  - Don't comment the obvious.
- **Programming paradigms (a rubric item):** mark examples with these exact prefixes. The README lists where they are.
  - `// OOP:` for classes, inheritance and overriding.
  - `// Procedural:` for plain functions with no shared state.
  - `// Functional:` for `map`, `filter`, `reduce`, `compactMap`, `allSatisfy` and similar.
  - `// Polymorphism:` where `Account` subclasses answer differently.
- **Golden rules / HIG:** mark spots with comments such as `// Error prevention: ...` or `Golden rule "permit easy reversal"`. Give icon-only buttons an `accessibilityLabel`, and hide decorative images with `.accessibilityHidden(true)`.
- **SwiftData conventions:**
  - Connect relationships only through the helpers in `ModelLinks.swift`, which insert the object, then set the to-one side.
  - Fetch with `FetchDescriptor<T>()` and filter in memory. Avoid `#Predicate` on optional relationships, which is unreliable on iOS 17.
  - Call `try? context.save()` after changes.
- **Permissions:** add a computed property to `Account` (default `false`) and override it in `AdminAccount`. Don't check role strings in views.
- **Previews:** every screen has a `#Preview` using `.previewEnvironment(SampleData.makePreviewSession())` (or `role: .member`).
  - The `ContentView` preview can't sign out, because it has no `RootView`. Use the simulator for that.
- **Recipe data:** all Spoonacular calls go through `RecipeProvider` subclasses. Anything new must also work with `MockRecipeProvider`, so the app works with no key and offline.
- **Git:**
  - Tyler does the commits and pushes. An assistant should suggest commit commands, not run them.
  - Keep `Secrets.swift` out of commits.
  - Only one person edits the Xcode project settings at a time, to avoid `project.pbxproj` conflicts.

---

## 4. Rubric status

### Requirements already met in code

| Rubric item | Where |
|---|---|
| Two platforms | iPhone (tabs) and iPad (sidebar), `ContentView.swift` |
| Authentication (modeled login is allowed) | `AuthModel.swift`, `SignInView.swift`; salted SHA-256 hashes; sign-up rules checked as you type |
| Two user types, each with distinct tasks | Admin and Member via the `Account` subclasses |
| SwiftData with 3–4+ related entities | 6 entities, `DataModels.swift` |
| 8+ sample users across 2 types | `SampleData.swift` (2 admins, 6 members) |
| Networking with dynamic data | Spoonacular search, autocomplete and details (`RecipeAPI.swift`) |
| Offline mode | Saved data works offline. Recipe requests that fail for lack of a connection fall back to demo recipes, with a label |
| OOP, procedural and functional code, labeled | See the comments; table in the README |
| File descriptions and function comments | Every file has a header description |
| Navigation stacks, data binding, custom views | NavigationStack per section, `@Bindable`, `RecipeRow`, `ShoppingItemRow`, Undo banner, toast |
| Loading states | Spinners for search and recipe details; demo/offline labels; error messages |
| 8 golden rules and HIG | Mapped in the README |
| README | Setup, demo accounts, features, structure, paradigms, golden rules, known issues |
| Accent color | Green `#2E8B57`, with a dark-mode variant |

### The 9 functional requirements (use this wording everywhere)

| # | Requirement | User type | Status |
|---|---|---|---|
| 1 | A user signs in, or creates an account by starting a household or joining one with an invite code | Both | Done |
| 2 | A member adds and removes fridge items, with an optional expiration date | Member | Done (scanning comes with Tyler's feature) |
| 3 | A member finds recipes grouped by how many ingredients are missing | Member | Done |
| 4 | A member favorites recipes and sees them on Home | Member | Done |
| 5 | A member marks a recipe cooked, which removes the ingredients it used from the fridge | Member | Done (with Undo) |
| 6 | An admin sets the household's diet, intolerances, and must-include and excluded ingredients | Admin | Done |
| 7 | An admin invites members with a code and removes members | Admin | Done |
| 8 | An admin renames the household and sees every member's role | Admin | Done |
| 9 | A member adds a recipe's missing ingredients to a shared shopping list and checks items off, then moves them into the fridge | Both | Done |

### The 5 non-functional requirements

| Requirement | Target | How it's met now |
|---|---|---|
| Security | Passwords are never stored | Salted SHA-256 hash per user; password rule of 8+ characters with a letter and a number |
| Performance | Reopening a recipe is instant | Recipe details and autocomplete are cached in memory; autocomplete waits 300 ms after typing stops |
| Reliability | Usable without a connection or API quota | Falls back to the 24 demo recipes automatically, with a label |
| Usability | Every control is labeled for VoiceOver; Dynamic Type works | Standard controls, accessibility labels, golden rules |
| Portability | Tailored layouts on iPhone and iPad | Tabs on iPhone, sidebar on iPad |

**The audit doc is out of date on these points:**
- PBKDF2, the sign-in lockout and Face ID were **removed**.
- Search results are no longer cached, only details and autocomplete.
- There's no offline disk cache or cook-confirmation sheet; offline uses demo data.
- The iPad side-by-side recipe view was removed.

Update the audit doc and any write-ups to match.

### Still needed

| # | Item | Owner | Notes |
|---|---|---|---|
| 1 | **Push and tell the team** | Tyler | Committed in `0539baa`, plus the household-rename fix and these notes. Files were merged, so teammates should pull before editing |
| 2 | **Check it in Xcode** | Tyler (Mac) | Delete the old app first. Check the walkthrough in section 7 |
| 3 | **Test targets + tests** | Tyler | Section 5 |
| 4 | **Grocery scanner** (Tyler's advanced feature) | Tyler | Section 6 |
| 5 | **3 more advanced features**, one per teammate | gabrian2025, VedanthShivYellai, jwmyers05 | Ideas, roughly one file each: expiration reminders (local notifications), Swift Charts of cooking history, nearby grocery stores (MapKit), first-launch onboarding, sign-in with Face ID (removed from core, so it could come back as someone's feature). Core features don't count as advanced |
| 6 | **iPad "platform integration"** | Team decision | The rubric asks for a tailored UI per platform ("3 views and 2 activities"). iPad currently differs only by the sidebar. A lean option is an iPad Home that shows favorites, items expiring soon and the shopping list side by side (`horizontalSizeClass == .regular`). Charts could fill this too |
| 7 | **App icon** | Team | Add to `Assets.xcassets/AppIcon`. Listed as a known issue in the README until then |
| 8 | **Non-code deliverables** | Whole team | Section 8 |
| 9 | **Submission zip** | Tyler | Section 9 |

---

## 5. Testing (rubric: testing, including a UI test run during a sprint)

### Target setup (one person on the Mac, then push)
1. Commit and push everything, and ask the team not to touch the Xcode project until this is pushed.
2. **File > New > Target… > iOS > Unit Testing Bundle.**
   - Name: `fridgescannerappTests`.
   - Testing System: **Swift Testing**.
   - Target to be Tested: `fridgescannerapp`.
   - Cancel the "activate scheme" prompt.
3. **File > New > Target… > iOS > UI Testing Bundle.**
   - Name: `fridgescannerappUITests`.
   - Testing System: **XCTest**.
   - Target to be Tested: `fridgescannerapp`.
4. For **both** new targets, set **General > Minimum Deployments** to **iOS 17.0**.
5. **Product > Scheme > Manage Schemes…** and tick **Shared** for `fridgescannerapp`. This creates `fridgescannerapp.xcodeproj/xcshareddata/`. Commit it, so everyone, including the grader, gets the same scheme.
6. Press **⌘U**. The template tests should pass, and both targets should appear in the Test navigator (⌘6).
   - If they're missing, open **Edit Scheme > Test** and add them.
7. Run `git status` and check that `Secrets.swift` isn't listed. Then commit as "Add unit and UI test targets" and push.

Test targets build only on ⌘U. Run (⌘R) still builds just the app, so the one-click zip is unaffected.

### Tests to write (keep it small)
- **Unit tests** (`fridgescannerappTests`, Swift Testing, `@testable import fridgescannerapp`):
  - Mark test structs `@MainActor`, because app code is main-actor by default.
  - Build models from `SampleData.makePreviewSession()`, which uses an in-memory store.
  - About 6 tests:
    1. `normalizedIngredientName`, `ingredientNamesMatch` and `pluralize` in `Helpers.swift`.
    2. `usernameProblem` and `passwordProblem` (valid and invalid cases).
    3. `makeCredential` and `verifyPassword` (right and wrong password).
    4. `ShoppingListModel`: a duplicate shows a message; `moveCheckedToFridge` adds to the fridge and clears the list.
    5. `RecipeSearchModel`: removing then `undoRemoval` restores the item.
    6. `RecipeSearchModel.sections` groups recipes by missing count (use `MockRecipeProvider` data).
- **One UI test** (`fridgescannerappUITests`, XCTest):
  1. Launch, sign in as `dana` / `Fridge123`.
  2. Go to the Fridge tab and add a unique item.
  3. Assert that it appears, then swipe-delete it so repeated runs stay clean.
- **`TESTING.md`** at the repo root, with a table: test name, requirement covered, steps, expected result, actual result, pass/fail. Include manual misuse cases:
  - Wrong password; sign-up with a short password, a taken username or a wrong invite code.
  - An empty or duplicate ingredient or shopping item.
  - A member viewing Preferences (read-only).
  - Offline: turn off the Mac's Wi-Fi, then search (demo recipes and the offline label).
  - No API key (demo data).
  - The scanner: an unknown barcode, or no camera.
- Record which sprint the UI test ran in, with a screenshot of the passing run.

---

## 6. Grocery scanner (Tyler's advanced feature), lean plan

- A new file, `Views/ScannerView.swift`, of about 100–150 lines.
- A **Scan** button on the Fridge screen opens VisionKit's `DataScannerViewController`, wrapped in `UIViewControllerRepresentable`, for barcodes (EAN-13, EAN-8, UPC-E, Code 128).
- On a scan:
  1. Look the code up on Open Food Facts (`https://world.openfoodfacts.org/api/v2/product/<code>.json`; free, no key).
  2. Turn the product name into a simple ingredient name.
  3. Fill `model.newIngredientText`. The user then taps Add as usual.
- Hide the button when `DataScannerViewController.isSupported && isAvailable` is false (simulator, no camera).
- If the product is unknown, show a message and let the user type the name.
- Add the camera permission text: target **Info** tab, `NSCameraUsageDescription` (Privacy – Camera Usage Description), e.g. "Fridge Scanner uses the camera to scan grocery barcodes."
- Must be tested on a real iPhone. Mention in the README that the scanner needs a device with a camera.
- **Not in scope:** reading expiration dates from text, and a confirmation sheet.

---

## 7. Walkthrough check after changes

1. Sign in as `dana`. Home shows the greeting. Fridge shows 12 items. Shopping shows 3 items.
2. Recipes: tap **Find Recipes**, and results appear in sections. Open one, favorite it, and it appears on Home.
3. In a recipe, tap **Add N Missing to Shopping List**. Then in Shopping, check the items, **Move N Checked to Fridge**, and they're now in Fridge.
4. In a recipe, tap **Mark as Cooked**. The used items leave the fridge, and **Undo** brings them back.
5. Household: rename the household; swipe to remove a member, which asks first.
6. Sign out, sign in as `marcus`. Preferences are read-only. There's no invite code or remove option.
7. Create an account, joining with code `MAPLE1`.
8. Run on an iPad simulator, and check that the sidebar shows all six sections.
9. Turn off the Mac's Wi-Fi and search. You should see "You're offline. Showing demo recipes."

---

## 8. Non-code deliverables (from the rubric)

- **Proposal (1–2 pages):**
  - The problem: households waste food and don't know what they can cook with what they share.
  - What's interesting: matching a changing fridge against a live recipe catalog under one household's diet rules, across people with different roles.
  - The platforms: iPhone (adding groceries and scanning them, checking off the shopping list in the store) and iPad (planning from the kitchen).
  - Note that login is stored on the device, which is allowed.
- **Personas:** one per role, each with a name, situation, goals and 2–3 pain points.
  - Admin "Dana", who buys for the household and wants less spoiled food and meals within diet rules.
  - Member "Marcus", a roommate who wants a quick recipe from what's there.
  - These match the demo accounts, so prototypes and the video can follow them.
- **Requirements:** the 9 functional and 5 non-functional tables in section 4, using that exact wording.
- **Backlog and sprints:** GitHub Issues or Projects, with user stories ("As a member, I want to…") labeled by requirement number. For each sprint, record the goal, what was done, what moved, and a screenshot. Link the commit history.
- **Prototypes (by Sprint 2):** every screen for both roles and both platforms (Figma or Lucidchart). Include empty, loading, demo and offline states. Screenshots of the current build are a fast start.
- **Testing documentation:** `TESTING.md` (section 5).
- **Videos:**
  - **Walkthrough (10–15 minutes):** sign in as `dana`, then `marcus`. Cover the 9 requirements in order, show iPad, have each person explain their advanced feature's code, and show the misuse cases. Everyone appears.
  - **Highlights (3–5 minutes):** about a minute per person, from a user's view, with no code.
  - Record the scanner on a real iPhone.
  - Use the placeholder key while recording, so the quota can't run out mid-take.
- **Reflection:** team lessons learned (merge problems, API quota limits, simplifying the scope, what you'd change), with a part from each person.
- **README:** keep it in sync. Still to add as features land: the scanner and its camera requirement, how to run the tests, each member's advanced feature with its files, and the iPad activities.

---

## 9. Submission zip

1. Name it `Final_Team<number>.zip`.
2. Include only `fridgescannerapp.xcodeproj` and the `fridgescannerapp/` source folder, plus the test folders once they exist.
3. **Include `Secrets.swift` in the zip** (it's needed to compile). Never commit it to GitHub. The placeholder key is fine: the app then runs on demo data.
4. Leave Team blank and keep automatic signing, so a grader can open the project and press Run on a simulator.
5. Before submitting, unzip it on a different Mac and run it with no changes.

---

## 10. Gotchas

- **Sign Out in the ContentView preview** does nothing; that's expected. It works in the simulator.
- **The simulator can't toggle Airplane Mode.** To test offline, turn off the Mac's Wi-Fi.
- **"Cannot find 'Secrets' in scope":** `Secrets.swift` is missing.
- **Crashes or odd data after pulling model changes:** delete the app from the simulator, which reseeds the demo data.
- **Tyler also builds on Linux** with a local-only tool setup (`xtool-local/`, `Package.swift`, `xtool.yml`). It's excluded from git and doesn't affect Xcode. Don't add those files to the repo.
