import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _runSignupAutomation(BuildContext context) async {
    print('Starting signup automation'); // Debug start
    const int iterations = 3;
    final tempDir = Directory.systemTemp;

    for (int i = 1; i <= iterations; i++) {
      print('Attempting signup for user$i'); // Debug iteration
      final email = 'user$i@gmail.com';
      final password = 'usern@123';
      final name = 'user$i';
      final phone = '9945390672';
      const selectedLocation = 'Bangalore';

      try {
        // Check mock image
        const mockImagePath = 'test_assets/mock_image.jpg';
        print('Checking mock image at $mockImagePath');
        final mockProfileFile = File(mockImagePath);
        if (!await mockProfileFile.exists()) {
          print('Mock image not found');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mock image not found')),
          );
          return;
        }

        // Compress images
        print('Compressing images for user$i');
        final compressedProfilePath = '${tempDir.path}/compressed_profile_$i.jpg';
        final compressedShopPath = '${tempDir.path}/compressed_shop_$i.jpg';
        final compressedProfileFile = await FlutterImageCompress.compressAndGetFile(
          mockProfileFile.absolute.path,
          compressedProfilePath,
          quality: 70,
          minWidth: 800,
          minHeight: 800,
        );
        final compressedShopFile = await FlutterImageCompress.compressAndGetFile(
          mockProfileFile.absolute.path,
          compressedShopPath,
          quality: 70,
          minWidth: 800,
          minHeight: 800,
        );

        if (compressedProfileFile == null || compressedShopFile == null) {
          print('Image compression failed');
          throw Exception('Image compression failed');
        }

        // Signup
        print('Signing up user$i with email: $email');
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );

        if (response.user != null) {
          final userId = response.user!.id;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          print('User$i signed up, ID: $userId');

          // Upload profile image
          print('Uploading profile image for user$i');
          final profileFilePath = 'userprofile/$userId/profile_$timestamp.jpg';
          await Supabase.instance.client.storage
              .from('userprofile')
              .upload(profileFilePath, File(compressedProfileFile.path));
          final profileImageUrl = Supabase.instance.client.storage
              .from('userprofile')
              .getPublicUrl(profileFilePath);
          print('Profile image URL: $profileImageUrl');

          // Upload shop image
          print('Uploading shop image for user$i');
          final shopFilePath = 'shopimages/$userId/shop_$timestamp.jpg';
          await Supabase.instance.client.storage
              .from('shopimages')
              .upload(shopFilePath, File(compressedShopFile.path));
          final shopImageUrl = Supabase.instance.client.storage
              .from('shopimages')
              .getPublicUrl(shopFilePath);
          print('Shop image URL: $shopImageUrl');

          // Insert user
          print('Inserting user$i into users table');
          await Supabase.instance.client.from('users').insert({
            'id': userId,
            'full_name': name,
            'email': email,
            'phone': phone,
            'location': selectedLocation,
            'profile_image': profileImageUrl,
            'shop_image': shopImageUrl,
          });

          print('User$i signup successful');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signed up user$i successfully')),
          );
          await Future.delayed(const Duration(seconds: 1));
        } else {
          print('User$i creation failed');
          throw Exception('User creation failed');
        }
      } catch (e) {
        print('Error signing up user$i: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing up user$i: $e')),
        );
      }
    }

    print('Navigating to signup page');
    Navigator.pushNamed(context, '/signup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Login to HMS Egg Distributions',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text('Sign Up'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('Run Signup Automation button tapped'); // Debug tap
                _runSignupAutomation(context);
              },
              child: const Text('Run Signup Automation'),
            ),
          ],
        ),
      ),
    );
  }
}