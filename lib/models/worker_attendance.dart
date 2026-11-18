class WorkerAttendance {
  final int? id;
  final int workerId;
  final String? workerName;
  final String date; // YYYY-MM-DD
  final String status; // 'present', 'absent', 'half_day', 'overtime'
  final double overtimeHours;
  final String? notes;
  final String createdAt;

  WorkerAttendance({
    this.id,
    required this.workerId,
    this.workerName,
    required this.date,
    this.status = 'present',
    this.overtimeHours = 0.0,
    this.notes,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  String statusDisplay(bool isHindi) {
    switch (status) {
      case 'absent':
        return isHindi ? 'अनुपस्थित' : 'Absent';
      case 'half_day':
        return isHindi ? 'आधा दिन' : 'Half Day';
      case 'overtime':
        return isHindi ? 'ओवरटाइम' : 'Overtime';
      case 'present':
      default:
        return isHindi ? 'उपस्थित' : 'Present';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'worker_id': workerId,
      'date': date,
      'status': status,
      'overtime_hours': overtimeHours,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory WorkerAttendance.fromMap(Map<String, dynamic> map, [String? workerName]) {
    return WorkerAttendance(
      id: map['id'] as int?,
      workerId: map['worker_id'] as int,
      workerName: workerName ?? map['worker_name'] as String?,
      date: map['date'] as String,
      status: map['status'] as String? ?? 'present',
      overtimeHours: (map['overtime_hours'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}
