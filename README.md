# DM Lace Surat – Business Manager Mobile Application

**DM Lace Surat – Business Manager** is a complete, offline-first mobile ERP and accounting application custom-designed for lace manufacturers, wholesalers, and textile traders operating in the Surat textile markets (Ring Road, Millennium Market, GIDC Sachin, Pandesara, Gujarat).

---

## 🌟 Key Business Features

### 1. Branding & Premium UI
- **Branded Identity**: Elegant lace-inspired medallion vector logo in Navy Blue (`#0A192F`), Metallic Gold (`#D4AF37`), and Pure White.
- **Bilingual Interface**: Hindi-English financial labels tailored to Surat textile traders (*Lena Baqi*, *Dena Baqi*, *Kaccha Bill*, *Jama*, *Kharcha*, *Karigar*).
- **Responsive Material 3 Design**: Card elevations, badges, and high-contrast numerical readability.

### 2. Parties Ledger (Customers & Suppliers)
- Manage Customers, Suppliers, and Dual-role traders.
- Opening balance support with clear classification: **Receivable (लेना बाकी)** or **Payable (देना बाकी)**.
- Real-time double-entry ledger calculation tracking debits, credits, and running balances.
- Deletion guard preventing permanent deletion of parties with recorded transactions (soft-archiving).
- One-tap account statement sharing via WhatsApp and native sharing.

### 3. Bills & Delivery Challans
- **Simple Kaccha Bill / Cash Memo**: Specifically designed for Surat mandi trading with clear notice (*Internal business record, not official GST tax invoice*).
- **Delivery Challan (चालान)**: For goods dispatched on approval or dyeing trial without creating premature sales revenue.
- **1-Click Challan Conversion**: Converts delivery challans into sales bills without duplicate inventory deductions or accounting entries.
- **Multi-Line Item Pricing**: Supports meters, rolls, pieces, and kg with discounts, rates, and line totals.
- **Printable PDF Export**: Generates professional PDF invoices with complete billing and signature boxes.

### 4. Daily Payments & Cashbook
- Tracks customer collections, supplier payments, and business expenses.
- Expense categorization for *Karigar / Labour Wages*, *Transport / Tempo*, *Packaging Material*, *Rent*, *Electricity*, and *Refreshments*.
- **Cash & Bank Liquidity Tracking**: Separate physical cash drawer and bank balances.
- **Cash-to-Bank and Bank-to-Cash Transfers**: Seamless liquidity shifts without distorting income or expense statistics.
- Automatic allocation against specific unpaid bills.

### 5. Due & Aging Payment Tracking
- Categorizes all pending customer dues into aging buckets:
  - **Due Today**
  - **Overdue 1–7 Days**
  - **Overdue 8–30 Days**
  - **Overdue > 30 Days**
  - **Not Yet Due**
- Preformatted, polite Gujarati/Hindi/English WhatsApp payment reminder messages.

### 6. Lace Inventory (Basic)
- Design code tracking (e.g. `LACE-ZARI-101`, `GOTA-GOLD-05`).
- Unit selection: Meter, Roll, Piece, Kg, Yard.
- Real-time stock movement logging for opening stock, purchases, dispatches, and sales.
- Low-stock visual alerts and physical stock adjustment dialog.

### 7. Reports & Analytics
- **Daily Business Summary**: Bills created, sales billed, payments received, and expenses paid.
- **Customer & Supplier Outstanding Reports**.
- **Expense Category Breakdown**.
- **Gross Profit & Operating Surplus Estimation**.
- **1-Click CSV Export** for parties, bills, cashbook transactions, and inventory.

### 8. Security & Offline Backup
- **4-Digit Owner Security PIN**: Encrypted with salted SHA-256 cryptographic hashing.
- **Cryptographic JSON Backup**: Includes checksum verification to safeguard data integrity.
- **100% Offline-First**: Stored locally in SQLite; zero cloud dependency.

---

## 🛠️ Technology Stack & Architecture

- **Framework**: Flutter 3.47+ / Dart 3.13+
- **Database**: SQLite (via `sqflite` on Android/iOS and `sqflite_common_ffi` on Desktop/Test)
- **Monetary Precision**: Integer Paise calculation (`1 Rupee = 100 paise`) avoiding IEEE 754 floating-point inaccuracies
- **Charts**: `fl_chart`
- **PDF & Printing**: `pdf`, `printing`
- **Data Export**: `csv`, `share_plus`
- **Security**: `crypto` (Salted SHA-256)

---

## 📂 Project Architecture

```
lib/
├── core/
│   ├── constants/       # AppColors, AppStrings
│   ├── database/        # DatabaseHelper, DatabaseTables, SampleDataSeeder
│   ├── security/        # PinService (Salted SHA-256)
│   ├── theme/           # AppTheme (Material 3 Navy & Gold)
│   └── utils/           # CurrencyFormatter (Indian Lakhs/Crores), DateFormatter, ShareHelper
├── models/              # Party, BusinessDocument, DocumentItem, BusinessTransaction, InventoryItem
├── repositories/        # PartyRepo, DocumentRepo, TransactionRepo, InventoryRepo, DashboardRepo, ReportRepo
├── services/            # PdfService, CsvService, BackupService
├── widgets/             # DmLaceLogo, StatCard, BadgeChip, EmptyState, ConfirmationDialog
└── screens/
    ├── splash_screen.dart
    ├── pin_screen.dart
    ├── main_navigation_screen.dart
    ├── dashboard/       # DashboardScreen
    ├── parties/         # PartiesListScreen, AddEditPartyScreen, PartyLedgerScreen
    ├── bills/           # BillsListScreen, CreateEditBillScreen, BillDetailScreen
    ├── challans/        # ChallansListScreen, CreateEditChallanScreen, ConvertChallanDialog
    ├── transactions/    # PaymentEntryScreen
    ├── cashbook/        # CashbookScreen
    ├── dues/            # DueTrackingScreen
    ├── reports/         # ReportsScreen
    ├── inventory/       # InventoryScreen, AddEditItemScreen
    ├── backup/          # BackupRestoreScreen
    ├── settings/        # SettingsScreen
    └── more/            # MoreMenuScreen
```

---

## 🧪 Testing & Verification

Run the comprehensive unit and widget test suite:
```bash
flutter test
```

Run static analysis with zero lint warnings:
```bash
flutter analyze
```

---

## 🚀 Running the App

### On Android Device / Emulator:
```bash
flutter run
```

### On Windows Desktop:
```bash
flutter run -d windows
```

### On Chrome / Web:
```bash
flutter run -d chrome
```

---
*Developed with precision for DM Lace Surat Textile Business.*
