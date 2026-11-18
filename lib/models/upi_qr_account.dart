class UpiQrAccount {
  final String id;
  final String title;
  final String upiId;
  final String accountHolderName;
  final String bankName;
  final bool isPrimary;
  final String? note;

  const UpiQrAccount({
    required this.id,
    required this.title,
    required this.upiId,
    required this.accountHolderName,
    this.bankName = 'Bank Account',
    this.isPrimary = false,
    this.note,
  });

  UpiQrAccount copyWith({
    String? id,
    String? title,
    String? upiId,
    String? accountHolderName,
    String? bankName,
    bool? isPrimary,
    String? note,
  }) {
    return UpiQrAccount(
      id: id ?? this.id,
      title: title ?? this.title,
      upiId: upiId ?? this.upiId,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      isPrimary: isPrimary ?? this.isPrimary,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'upiId': upiId,
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'isPrimary': isPrimary,
      'note': note,
    };
  }

  factory UpiQrAccount.fromMap(Map<String, dynamic> map) {
    return UpiQrAccount(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'दुकान काउंटर',
      upiId: map['upiId']?.toString() ?? 'dmlace@upi',
      accountHolderName: map['accountHolderName']?.toString() ?? 'DM LACE SURAT',
      bankName: map['bankName']?.toString() ?? 'Bank Account',
      isPrimary: map['isPrimary'] == true || map['isPrimary'] == 1,
      note: map['note']?.toString(),
    );
  }
}
