class Prescription {
  final String medID;
  final String medName;
  final String frequency;
  final List<DateTime> reminderTimes;

  Prescription({
    required this.medID,
    required this.medName,
    required this.frequency,
    required this.reminderTimes,
  });

  Map<String, dynamic> toJson() => {
    'medID': medID,
    'medName': medName,
    'frequency': frequency,
    'reminderTimes': reminderTimes.map((dt) => dt.toIso8601String()).toList(),
  };

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
    medID: json['medID'],
    medName: json['medName'],
    frequency: json['frequency'],
    reminderTimes: (json['reminderTimes'] as List)
        .map((dt) => DateTime.parse(dt))
        .toList(),
  );
}