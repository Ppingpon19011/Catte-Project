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
}