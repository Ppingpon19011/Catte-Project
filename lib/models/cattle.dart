class Cattle {
  final String id;
  final String name;
  final String breed;
  final String imageUrl;
  final double estimatedWeight;
  final DateTime lastUpdated;
  // ข้อมูลเพิ่มเติม
  final String cattleNumber;
  final String gender;
  final DateTime birthDate;
  final String fatherNumber;
  final String motherNumber;
  final String breeder;
  final String currentOwner;
  final String? color; // เพิ่มข้อมูลสีของโค

  Cattle({
    required this.id,
    required this.name,
    required this.breed,
    required this.imageUrl,
    required this.estimatedWeight,
    required this.lastUpdated,
    required this.cattleNumber,
    required this.gender,
    required this.birthDate,
    required this.fatherNumber,
    required this.motherNumber,
    required this.breeder,
    required this.currentOwner,
    this.color, // เพิ่มข้อมูลสีของโค (ไม่จำเป็นต้องมี)
  });

  /// สร้างสำเนาของ Cattle object พร้อมการแก้ไขค่าบางตัว
  Cattle copyWith({
    String? id,
    String? name,
    String? breed,
    String? imageUrl,
    double? estimatedWeight,
    DateTime? lastUpdated,
    String? cattleNumber,
    String? gender,
    DateTime? birthDate,
    String? fatherNumber,
    String? motherNumber,
    String? breeder,
    String? currentOwner,
    String? color,
  }) {
    return Cattle(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      imageUrl: imageUrl ?? this.imageUrl,
      estimatedWeight: estimatedWeight ?? this.estimatedWeight,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      cattleNumber: cattleNumber ?? this.cattleNumber,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      fatherNumber: fatherNumber ?? this.fatherNumber,
      motherNumber: motherNumber ?? this.motherNumber,
      breeder: breeder ?? this.breeder,
      currentOwner: currentOwner ?? this.currentOwner,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'imageUrl': imageUrl,
      'estimatedWeight': estimatedWeight,
      'lastUpdated': lastUpdated.toIso8601String(),
      'cattleNumber': cattleNumber,
      'gender': gender,
      'birthDate': birthDate.toIso8601String(),
      'fatherNumber': fatherNumber,
      'motherNumber': motherNumber,
      'breeder': breeder,
      'currentOwner': currentOwner,
      'color': color, // เพิ่มข้อมูลสีของโค
    };
  }

  factory Cattle.fromMap(Map<String, dynamic> map) {
    return Cattle(
      id: map['id'],
      name: map['name'],
      breed: map['breed'],
      imageUrl: map['imageUrl'],
      estimatedWeight: map['estimatedWeight'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
      cattleNumber: map['cattleNumber'],
      gender: map['gender'],
      birthDate: DateTime.parse(map['birthDate']),
      fatherNumber: map['fatherNumber'],
      motherNumber: map['motherNumber'],
      breeder: map['breeder'],
      currentOwner: map['currentOwner'],
      color: map['color'], // เพิ่มข้อมูลสีของโค
    );
  }

  /// เปรียบเทียบ Cattle objects เพื่อตรวจสอบว่าเหมือนกันหรือไม่
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cattle &&
        other.id == id &&
        other.name == name &&
        other.breed == breed &&
        other.imageUrl == imageUrl &&
        other.estimatedWeight == estimatedWeight &&
        other.lastUpdated == lastUpdated &&
        other.cattleNumber == cattleNumber &&
        other.gender == gender &&
        other.birthDate == birthDate &&
        other.fatherNumber == fatherNumber &&
        other.motherNumber == motherNumber &&
        other.breeder == breeder &&
        other.currentOwner == currentOwner &&
        other.color == color;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      breed,
      imageUrl,
      estimatedWeight,
      lastUpdated,
      cattleNumber,
      gender,
      birthDate,
      fatherNumber,
      motherNumber,
      breeder,
      currentOwner,
      color,
    );
  }

  @override
  String toString() {
    return 'Cattle{id: $id, name: $name, breed: $breed, estimatedWeight: $estimatedWeight}';
  }
}