import 'dart:io';
import 'dart:convert'; // Added for jsonEncode

void main() {
  final users = List.generate(100, (i) => {
        'email': 'user${i + 1}@example.com',
        'password': 'usern@123',
        'name': 'User ${i + 1}',
        'phone': '9945390${672 + i}',
        'location': 'Bangalore'
      });

  // Write to a temporary file in the project root
  final outputFile = File('users.json');
  outputFile.writeAsStringSync(jsonEncode(users, toEncodable: (obj) => obj));
  print('Generated users.json with ${users.length} users in project root');
  print('Move users.json to assets/ and update pubspec.yaml');
}