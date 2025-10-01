
class AppUser {
   String id;
   String email;
   String name;
   bool status;
   String role;
   String? parentId;
   List<String> labels;
   double? commission;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.status,
    required this.role,
    this.parentId,
    required this.labels,
    required this.commission,
  });

   factory AppUser.fromJson(Map<String, dynamic> json) {
     return AppUser(
       id: (json[r'$id'] ?? json['id']) as String, // sample shows "id"
       email: json['email'] as String,
       name: json['name'] as String,
       status: json['status'] as bool,
       role: json['role'] as String,
       parentId: json['parentId'] as String?, // null stays null
       labels: (json['labels'] as List<dynamic>? ?? const [])
           .map((e) => e.toString())
           .toList(),
       commission: (json['commission'] != null) ? (json['commission'] as num).toDouble() : 0.0,
     );
   }

   Map<String, dynamic> toJson() => {
     r'$id': id,
     'email': email,
     'name': name,
     'status': status,
     'role': role,
     'parentId': parentId,
     'labels': labels,
     'commission' : commission,
   };

   @override
  String toString() {
    return 'AppUser{id: $id, email: $email, name: $name, status: $status, role: $role, parentId: $parentId, labels: $labels, commission: $commission}';
  }

}
