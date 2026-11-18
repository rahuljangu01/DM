import 'package:csv/csv.dart';
import '../core/utils/share_helper.dart';
import '../models/party.dart';
import '../models/document.dart';
import '../models/transaction.dart';
import '../models/inventory_item.dart';

class CsvService {
  /// Export Parties List as CSV
  static Future<void> exportParties(List<Party> parties) async {
    final List<List<dynamic>> rows = [
      ['ID', 'Name', 'Type', 'Phone', 'Address', 'Opening Balance (₹)', 'Balance Type', 'Current Balance (₹)', 'Notes'],
      ...parties.map((p) => [
            p.id,
            p.name,
            p.type,
            p.phone ?? '',
            p.address ?? '',
            p.openingBalanceRupees,
            p.balanceType,
            p.currentBalanceRupees,
            p.notes ?? '',
          ]),
    ];

    final csvData = csv.encode(rows);
    await ShareHelper.shareText(csvData, subject: 'DM_Lace_Parties_Export.csv');
  }

  /// Export Documents / Bills as CSV
  static Future<void> exportDocuments(List<BusinessDocument> docs) async {
    final List<List<dynamic>> rows = [
      ['Doc Number', 'Doc Type', 'Party', 'Date', 'Due Date', 'Subtotal (₹)', 'Discount (₹)', 'Tax (₹)', 'Grand Total (₹)', 'Paid (₹)', 'Remaining (₹)', 'Status'],
      ...docs.map((d) => [
            d.docNumber,
            d.docType,
            d.partyName ?? '',
            d.docDate,
            d.dueDate ?? '',
            d.subtotalRupees,
            d.discountRupees,
            d.taxRupees,
            d.grandTotalRupees,
            d.paidAmountRupees,
            d.remainingBalanceRupees,
            d.paymentStatus,
          ]),
    ];

    final csvData = csv.encode(rows);
    await ShareHelper.shareText(csvData, subject: 'DM_Lace_Bills_Export.csv');
  }

  /// Export Transactions / Cashbook as CSV
  static Future<void> exportTransactions(List<BusinessTransaction> txs) async {
    final List<List<dynamic>> rows = [
      ['ID', 'Date', 'Type', 'Party', 'Amount (₹)', 'Payment Method', 'Category', 'Reference #', 'Notes'],
      ...txs.map((t) => [
            t.id,
            t.transactionDate,
            t.transactionType,
            t.partyName ?? '',
            t.amountRupees,
            t.paymentMethod,
            t.expenseCategory ?? '',
            t.referenceNumber ?? '',
            t.notes ?? '',
          ]),
    ];

    final csvData = csv.encode(rows);
    await ShareHelper.shareText(csvData, subject: 'DM_Lace_Cashbook_Export.csv');
  }

  /// Export Inventory as CSV
  static Future<void> exportInventory(List<InventoryItem> items) async {
    final List<List<dynamic>> rows = [
      ['Design Code', 'Item Name', 'Unit', 'Opening Stock', 'Purchases', 'Sales', 'Current Stock', 'Purchase Rate (₹)', 'Selling Rate (₹)', 'Low Stock Alert'],
      ...items.map((i) => [
            i.designCode,
            i.itemName,
            i.unit,
            i.openingQuantity,
            i.purchaseQuantity,
            i.salesQuantity,
            i.currentStock,
            i.purchaseRateRupees,
            i.sellingRateRupees,
            i.lowStockWarningQty,
          ]),
    ];

    final csvData = csv.encode(rows);
    await ShareHelper.shareText(csvData, subject: 'DM_Lace_Inventory_Export.csv');
  }
}
