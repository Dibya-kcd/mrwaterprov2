# 💧 MrWater v2.1 — Flutter PWA

Smart Water Jar Delivery Management for Indian businesses.

## 🚀 Quick Start

```bash
cd mrwater
flutter pub get
flutter run -d chrome --web-renderer html
```

## 📦 Build for Production

```bash
flutter build web --web-renderer html --release
# Output in build/web/
```

## 🏗️ Project Structure

```
lib/
├── main.dart                         # App entry
├── core/
│   ├── providers/app_state.dart      # All Riverpod state (settings, customers, inventory, transactions, audit)
│   └── theme/
│       ├── app_colors.dart           # Design tokens
│       └── app_theme.dart            # Light/dark themes with Google Fonts
├── shared/widgets/shared_widgets.dart # CoolJarIcon, PetJarIcon, GradientButton, QuantityStepper, etc.
└── features/
    ├── dashboard/
    │   ├── main_scaffold.dart        # Adaptive layout (mobile bottom nav ↔ desktop sidebar)
    │   └── dashboard_screen.dart     # KPIs, inventory bars, quick actions
    ├── transactions/
    │   └── transactions_screen.dart  # Unified delivery+return form + transaction list with edit/delete
    ├── customers/
    │   └── all_screens.dart          # Customers list + detail + reports + notifications
    └── settings/
        └── settings_screen.dart      # Full settings with all sections
```

## ✅ Features

### Unified Transactions
- **One form** for delivery + return — both Cool and PET jars side by side
- Delivery = new jar going out; Return = empty jar coming back
- Customer can receive any combination (e.g. 2 Cool delivered, 1 PET returned)
- Every transaction is **editable and deletable** with confirmation dialog
- Edit/delete **fully reverses** then re-applies inventory and payment changes

### Jar Icons
- ❄️ **Cool jars** → Custom snowflake icon (drawn with CustomPainter)
- 🍶 **PET jars** → Custom bottle silhouette icon (drawn with CustomPainter)

### Inventory Sync
- Stock decreases on delivery, increases on return
- Damage tracking: removes jars from total fleet permanently
- Low stock alerts configurable per threshold

### Payment Sync
- Auto-calculates billed amount from jar counts × prices
- Supports Cash, UPI, Advance deduction, Credit
- Advance balance shown and deductible in one tap

### Settings (all working)
- 🏢 Business Profile: name, owner, phone, address, GSTIN
- 🏷️ App Identity: app name, currency, date format, invoice prefix
- 💰 Pricing: cool price, PET price, transport fee, damage charge per jar
- 📦 Inventory Rules: low stock threshold, overdue days
- 💳 Payment & Sync: auto-sync toggle, audit log toggle
- 🎨 Theme: light/dark/system + 6 accent colors
- 📋 Audit Log: full trail of all creates, edits, deletes

### Adaptive Layout
- **Mobile** (<900px): Bottom navigation with center FAB
- **Desktop** (≥900px): Sidebar navigation with quick transaction button

## 🎨 Design System

| Token | Value |
|-------|-------|
| Primary | #1A6BFF |
| Cool Jar | #0096C7 |
| PET Jar | #52B788 |
| Heading font | Syne 700/800 |
| Body font | DM Sans 400/500/600 |
| Amount font | JetBrains Mono |
| Card radius | 16px |

## 🔥 Firebase Integration (next phase)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then replace in-memory state in `app_state.dart` with Firestore streams.

## 📋 Dependencies

| Package | Use |
|---------|-----|
| flutter_riverpod | State management |
| shared_preferences | Settings persistence |
| google_fonts | Syne + DM Sans + JetBrains Mono |
| intl | Date/currency formatting |
| uuid | Transaction IDs |
| pdf + printing | Invoice export |
| share_plus | WhatsApp sharing |

## 🇮🇳 Built for India

- ₹ INR currency throughout
- Indian phone number format
- Local area/route management
- Advance payment system common in Indian water delivery
