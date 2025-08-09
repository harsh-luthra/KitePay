
class AppUser {
   String id;
   String email;
   String name;
   bool status;
   List<String> labels;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.status,
    required this.labels,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['\$id'],
      email: json['email'],
      name: json['name'],
      status: json['status'],
      labels: List<String>.from(json['labels'] ?? []),
    );
  }

  @override
  String toString() {
    return 'AppUser{id: $id, email: $email, name: $name, status: $status, labels: $labels}';
  }
}
