import 'package:flutter/material.dart';
   import 'package:supabase_flutter/supabase_flutter.dart';
   import 'package:image_picker/image_picker.dart';
   import 'dart:io';
   import 'package:flutter/gestures.dart';
   import 'package:flutter_image_compress/flutter_image_compress.dart';
   import 'dart:convert';
   import 'package:flutter/services.dart' show rootBundle;

   class SignUpPage extends StatefulWidget {
     const SignUpPage({super.key});

     @override
     State<SignUpPage> createState() => _SignUpPageState();
   }

   class _SignUpPageState extends State<SignUpPage> {
     final _emailController = TextEditingController();
     final _passwordController = TextEditingController();
     final _confirmPasswordController = TextEditingController();
     final _nameController = TextEditingController();
     final _phoneController = TextEditingController();
     bool _isLoading = false;
     bool _isChecked = false;
     String? _selectedLocation;
     List<String> _locations = [];
     final ImagePicker _picker = ImagePicker();
     XFile? _userImage;
     XFile? _shopImage;
     RealtimeChannel? _subscription;

     static const String _emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
     static const String _phonePattern = r'^\+?1?\d{9,15}$';
     static const int _minPasswordLength = 8;
     static const int _maxFileSizeBytes = 5 * 1024 * 1024;

     @override
     void initState() {
       super.initState();
       _fetchLocations();
       _setupRealtimeSubscription();
     }

     @override
     void dispose() {
       _emailController.dispose();
       _passwordController.dispose();
       _confirmPasswordController.dispose();
       _nameController.dispose();
       _phoneController.dispose();
       _subscription?.unsubscribe();
       super.dispose();
     }

     Future<void> _fetchLocations() async {
       try {
         final response = await Supabase.instance.client
             .from('delivery_areas')
             .select('area_name');

         if (response.isNotEmpty) {
           setState(() {
             _locations = (response as List<dynamic>)
                 .map((item) => item['area_name'].toString())
                 .toList()
               ..sort();
             if (_selectedLocation != null &&
                 !_locations.contains(_selectedLocation)) {
               _selectedLocation = null;
             }
           });
         } else {
           setState(() {
             _locations = [];
             _selectedLocation = null;
           });
           _showSnackBar('No areas available');
         }
       } catch (e) {
         _showSnackBar('Error fetching areas: $e');
       }
     }

     void _setupRealtimeSubscription() {
       _subscription = Supabase.instance.client
           .channel('public:delivery_areas')
           .onPostgresChanges(
             event: PostgresChangeEvent.all,
             schema: 'public',
             table: 'delivery_areas',
             callback: (payload) {
               _fetchLocations();
               _showSnackBar('Locations updated');
             },
           )
           .subscribe();
     }

     // Automation script
     Future<void> _runSignupAutomation() async {
       print('Automate button tapped');
       setState(() => _isLoading = true);

       try {
         // Load users.json
         print('Loading users.json');
         final jsonString = await rootBundle.loadString('assets/users.json');
         final List<dynamic> users = jsonDecode(jsonString);
         print('Loaded ${users.length} users');

         for (int i = 0; i < users.length; i++) {
           final user = users[i];
           final email = user['email'] as String;
           final password = user['password'] as String;
           final name = user['name'] as String;
           final phone = user['phone'] as String;
           final location = user['location'] as String;

           print('Processing user ${i + 1}: $email');

           // Mock images
           const mockImagePath = 'assets/test_assets/mock_image.jpg';
           final mockFile = File(mockImagePath);
           if (!await mockFile.exists()) {
             print('Mock image not found at $mockImagePath');
             _showSnackBar('Mock image not found at $mockImagePath');
             return;
           }

           // Compress images
           final timestamp = DateTime.now().millisecondsSinceEpoch;
           final compressedProfileFile = await _compressImage(mockFile, 'user${i + 1}', 'profile_$timestamp');
           final compressedShopFile = await _compressImage(mockFile, 'user${i + 1}', 'shop_$timestamp');

           if (compressedProfileFile == null || compressedShopFile == null) {
             print('Image compression failed for user ${i + 1}');
             _showSnackBar('Image compression failed for user ${i + 1}');
             continue;
           }

           // Validate inputs
           if (!_validateInputs(email, password, password, name, phone, location)) {
             print('Validation failed for user ${i + 1}');
             continue;
           }

           // Signup
           print('Signing up user ${i + 1}');
           final response = await Supabase.instance.client.auth.signUp(
             email: email,
             password: password,
           );

           if (response.user != null && mounted) {
             final userId = response.user!.id;
             print('User ${i + 1} signed up, ID: $userId');

             // Upload profile image
             final profileFilePath = 'userprofile/$userId/profile_$timestamp.jpg';
             await Supabase.instance.client.storage
                 .from('userprofile')
                 .upload(profileFilePath, compressedProfileFile);
             final profileImageUrl = Supabase.instance.client.storage
                 .from('userprofile')
                 .getPublicUrl(profileFilePath);
             print('Profile image uploaded: $profileImageUrl');

             // Upload shop image
             final shopFilePath = 'shopimages/$userId/shop_$timestamp.jpg';
             await Supabase.instance.client.storage
                 .from('shopimages')
                 .upload(shopFilePath, compressedShopFile);
             final shopImageUrl = Supabase.instance.client.storage
                 .from('shopimages')
                 .getPublicUrl(shopFilePath);
             print('Shop image uploaded: $shopImageUrl');

             // Insert user
             await Supabase.instance.client.from('users').insert({
               'id': userId,
               'full_name': name,
               'email': email,
               'phone': phone,
               'location': location,
               'profile_image': profileImageUrl,
               'shop_image': shopImageUrl,
             });

             print('User ${i + 1} signup completed');
             _showSnackBar('Signed up user ${i + 1} successfully');
             await Future.delayed(const Duration(seconds: 1));
           } else {
             print('User ${i + 1} signup failed');
             _showSnackBar('User ${i + 1} signup failed');
           }
         }
       } catch (e) {
         print('Automation error: $e');
         _showSnackBar('Automation error: $e');
       } finally {
         setState(() => _isLoading = false);
         print('Automation complete');
       }
     }

     Future<void> _signUp() async {
       final email = _emailController.text.trim();
       final password = _passwordController.text.trim();
       final confirmPassword = _confirmPasswordController.text.trim();
       final name = _nameController.text.trim();
       final phone = _phoneController.text.trim();

       if (!_validateInputs(email, password, confirmPassword, name, phone, _selectedLocation)) {
         return;
       }

       setState(() => _isLoading = true);

       try {
         final response = await Supabase.instance.client.auth.signUp(
           email: email,
           password: password,
         );

         if (response.user != null && mounted) {
           final userId = response.user!.id;
           final timestamp = DateTime.now().millisecondsSinceEpoch;

           String? profileImageUrl;
           String? shopImageUrl;

           if (_userImage != null) {
             final file = File(_userImage!.path);
             if (await file.length() > _maxFileSizeBytes) {
               _showSnackBar('Profile image size must be less than 5MB');
               return;
             }

             final compressedFile =
                 await _compressImage(file, userId, 'profile_$timestamp');
             if (compressedFile == null) {
               _showSnackBar('Failed to compress profile image');
               return;
             }

             final fileName = 'profile_$timestamp.jpg';
             final filePath = 'userprofile/$userId/$fileName';

             await Supabase.instance.client.storage
                 .from('userprofile')
                 .upload(filePath, compressedFile);

             profileImageUrl = Supabase.instance.client.storage
                 .from('userprofile')
                 .getPublicUrl(filePath);
           }

           if (_shopImage != null) {
             final shopFile = File(_shopImage!.path);
             if (await shopFile.length() > _maxFileSizeBytes) {
               _showSnackBar('Shop image size must be less than 5MB');
               return;
             }

             final compressedShopFile =
                 await _compressImage(shopFile, userId, 'shop_$timestamp');
             if (compressedShopFile == null) {
               _showSnackBar('Failed to compress shop image');
               return;
             }

             final shopFileName = 'shop_$timestamp.jpg';
             final shopFilePath = 'shopimages/$userId/$shopFileName';

             await Supabase.instance.client.storage
                 .from('shopimages')
                 .upload(shopFilePath, compressedShopFile);

             shopImageUrl = Supabase.instance.client.storage
                 .from('shopimages')
                 .getPublicUrl(shopFilePath);
           }

           await Supabase.instance.client.from('users').insert({
             'id': userId,
             'full_name': name,
             'email': email,
             'phone': phone,
             'location': _selectedLocation,
             'profile_image': profileImageUrl,
             'shop_image': shopImageUrl,
           });

           Navigator.pushReplacementNamed(context, '/login');
         }
       } on AuthException catch (e) {
         _showSnackBar('Signup failed: ${e.message}');
       } catch (e) {
         _showSnackBar('Signup failed: $e');
       } finally {
         if (mounted) setState(() => _isLoading = false);
       }
     }

     Future<File?> _compressImage(
         File file, String userId, String fileName) async {
       try {
         final tempDir = Directory.systemTemp;
         final targetPath = '${tempDir.path}/compressed_$fileName.jpg';

         final compressedFile = await FlutterImageCompress.compressAndGetFile(
           file.absolute.path,
           targetPath,
           quality: 70,
           minWidth: 800,
           minHeight: 800,
         );

         if (compressedFile == null) {
           return null;
         }

         final compressedSize = await compressedFile.length();
         if (compressedSize > 100 * 1024) {
           final furtherCompressedFile =
               await FlutterImageCompress.compressAndGetFile(
             file.absolute.path,
             targetPath,
             quality: 50,
             minWidth: 600,
             minHeight: 600,
           );
           return furtherCompressedFile != null
               ? File(furtherCompressedFile.path)
               : null;
         }

         return File(compressedFile.path);
       } catch (e) {
         _showSnackBar('Error compressing image: $e');
         return null;
       }
     }

     bool _validateInputs(String email, String password, String confirmPassword,
         String name, String phone, String? location) {
       if (name.isEmpty) {
         _showSnackBar('Please enter your full name');
         return false;
       }

       if (email.isEmpty) {
         _showSnackBar('Please enter your email');
         return false;
       }

       if (!RegExp(_emailPattern).hasMatch(email)) {
         _showSnackBar('Please enter a valid email address');
         return false;
       }

       if (password.isEmpty) {
         _showSnackBar('Please enter a password');
         return false;
       }

       if (password.length < _minPasswordLength) {
         _showSnackBar('Password must be at least $_minPasswordLength characters');
         return false;
       }

       if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$')
           .hasMatch(password)) {
         _showSnackBar('Password must contain letters and numbers');
         return false;
       }

       if (password != confirmPassword) {
         _showSnackBar('Passwords do not match');
         return false;
       }

       if (phone.isEmpty) {
         _showSnackBar('Please enter your phone number');
         return false;
       }

       if (!RegExp(_phonePattern).hasMatch(phone)) {
         _showSnackBar('Please enter a valid phone number');
         return false;
       }

       if (location == null) {
         _showSnackBar('Please select a location');
         return false;
       }

       // Programmatically accept terms for automation
       setState(() => _isChecked = true);

       return true;
     }

     void _showSnackBar(String message) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(message),
             duration: const Duration(seconds: 3),
           ),
         );
       }
     }

     Future<void> _pickImage(bool isProfile) async {
       showModalBottomSheet(
         context: context,
         builder: (context) => Container(
           padding: const EdgeInsets.all(20),
           height: 160,
           child: Column(
             children: [
               const Text(
                 "Upload Image",
                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
               ),
               const SizedBox(height: 10),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   ElevatedButton.icon(
                     onPressed: () async {
                       Navigator.pop(context);
                       final pickedFile =
                           await _picker.pickImage(source: ImageSource.camera);
                       if (pickedFile != null) {
                         setState(() {
                           if (isProfile) {
                             _userImage = pickedFile;
                           } else {
                             _shopImage = pickedFile;
                           }
                         });
                       }
                     },
                     icon: const Icon(Icons.camera_alt),
                     label: const Text("Camera"),
                   ),
                   ElevatedButton.icon(
                     onPressed: () async {
                       Navigator.pop(context);
                       final pickedFile =
                           await _picker.pickImage(source: ImageSource.gallery);
                       if (pickedFile != null) {
                         setState(() {
                           if (isProfile) {
                             _userImage = pickedFile;
                           } else {
                             _shopImage = pickedFile;
                           }
                         });
                       }
                     },
                     icon: const Icon(Icons.photo_library),
                     label: const Text("Gallery"),
                   ),
                 ],
               ),
             ],
           ),
         ),
       );
     }

     @override
     Widget build(BuildContext context) {
       return Scaffold(
         backgroundColor: Colors.white,
         body: RefreshIndicator(
           onRefresh: _fetchLocations,
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Center(
               child: SingleChildScrollView(
                 physics: const AlwaysScrollableScrollPhysics(),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const SizedBox(height: 5),
                     const Text(
                       "Register Now",
                       style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                     ),
                     const Text(
                       "Sign up with email and password and all fields to continue",
                       style: TextStyle(fontSize: 14, color: Colors.grey),
                     ),
                     const SizedBox(height: 10),
                     _buildTextField(Icons.person, "Full Name",
                         controller: _nameController),
                     _buildTextField(Icons.email, "Email Address",
                         controller: _emailController),
                     _buildTextField(Icons.lock, "Password",
                         obscureText: true, controller: _passwordController),
                     _buildTextField(Icons.lock, "Confirm Password",
                         obscureText: true,
                         controller: _confirmPasswordController),
                     const SizedBox(height: 10),
                     _buildTextField(Icons.phone, "Phone Number",
                         controller: _phoneController),
                     _locationDropdown(),
                     const SizedBox(height: 10),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         _imageCircle(_userImage, Icons.person, true),
                         const SizedBox(width: 20),
                         _imageCircle(_shopImage, Icons.store, false),
                       ],
                     ),
                     const SizedBox(height: 10),
                     _termsCheckbox(),
                     const SizedBox(height: 10),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         minimumSize: const Size(double.infinity, 50),
                         backgroundColor: Colors.black,
                       ),
                       onPressed: _isLoading ? null : _signUp,
                       child: _isLoading
                           ? const CircularProgressIndicator(color: Colors.white)
                           : const Text("Register",
                               style: TextStyle(color: Colors.white)),
                     ),
                     const SizedBox(height: 10),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         minimumSize: const Size(double.infinity, 50),
                         backgroundColor: Colors.blue,
                       ),
                       onPressed: _isLoading ? null : _runSignupAutomation,
                       child: _isLoading
                           ? const CircularProgressIndicator(color: Colors.white)
                           : const Text("Automate",
                               style: TextStyle(color: Colors.white)),
                     ),
                     const SizedBox(height: 10),
                     Center(
                       child: RichText(
                         text: TextSpan(
                           text: "Already have an account? ",
                           style: const TextStyle(color: Colors.black),
                           children: [
                             TextSpan(
                               text: "Sign in",
                               style: const TextStyle(
                                   color: Colors.red, fontWeight: FontWeight.bold),
                               recognizer: TapGestureRecognizer()
                                 ..onTap = () => Navigator.pop(context),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
           ),
         ),
       );
     }

     Widget _buildTextField(IconData icon, String hint,
         {bool obscureText = false, required TextEditingController controller}) {
       return Padding(
         padding: const EdgeInsets.symmetric(vertical: 6.0),
         child: SizedBox(
           height: 40,
           child: TextField(
             controller: controller,
             obscureText: obscureText,
             style: const TextStyle(fontSize: 14),
             decoration: InputDecoration(
               isDense: true,
               contentPadding:
                   const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
               prefixIcon: Icon(icon, color: Colors.grey, size: 18),
               hintText: hint,
               hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
               filled: true,
               fillColor: Colors.grey[200],
               border: InputBorder.none,
               enabledBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: BorderSide.none,
               ),
               focusedBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: BorderSide.none,
               ),
             ),
           ),
         ),
       );
     }

     Widget _locationDropdown() {
       return Row(
         children: [
           Expanded(
             child: DropdownButtonFormField<String>(
               decoration: InputDecoration(
                 prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                 hintText: _locations.isEmpty ? "Loading..." : "Select Location",
                 hintStyle: const TextStyle(color: Colors.grey),
                 border: InputBorder.none,
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                   borderSide: BorderSide.none,
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(12),
                   borderSide: BorderSide.none,
                 ),
                 filled: true,
                 fillColor: Colors.grey[200],
               ),
               value: _selectedLocation,
               items: _locations
                   .map((location) => DropdownMenuItem(
                         value: location,
                         child: Text(location),
                       ))
                   .toList(),
               onChanged: (value) => setState(() => _selectedLocation = value),
             ),
           ),
           IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: _fetchLocations,
             tooltip: 'Refresh Locations',
           ),
         ],
       );
     }

     Widget _imageCircle(XFile? image, IconData icon, bool isProfile) {
       return GestureDetector(
         onTap: () => _pickImage(isProfile),
         child: CircleAvatar(
           radius: 25,
           backgroundColor: Colors.grey[300],
           backgroundImage: image != null ? FileImage(File(image.path)) : null,
           child: image == null ? Icon(icon, size: 30, color: Colors.black) : null,
         ),
       );
     }

     Widget _termsCheckbox() {
       return Row(
         children: [
           Checkbox(
             value: _isChecked,
             onChanged: (value) => setState(() => _isChecked = value ?? false),
           ),
           GestureDetector(
             onTap: () => showDialog(
               context: context,
               builder: (context) => AlertDialog(
                 title: const Text("Terms & Conditions"),
                 content: SingleChildScrollView(
                   child: RichText(
                     text: TextSpan(
                       style: TextStyle(fontSize: 12, color: Colors.black),
                       children: [
                         TextSpan(
                           text:
                               'Terms and Conditions for Egg Distribution Services\n\n',
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                         TextSpan(
                           text: 'Last Revised: [Date]\n\n',
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                         TextSpan(
                           text: '1. Introduction\n\n',
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                         TextSpan(
                           text:
                               '''These Terms and Conditions (“Agreement”) govern the provision of egg supply services ("Services") provided by HMS EGG DISTRIBUTIONS (“We”, “Us”, “Our”) to retail shop owners (“You”, “Customer”). By accepting and using our egg distribution services, You agree to comply with and be bound by these Terms and Conditions.\n\n''',
                         ),
                         TextSpan(
                           text: '2. Egg Supply and Credit Terms\n\n',
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                         TextSpan(
                           text: '''   a. Supply of Eggs  
   We will deliver eggs to Your retail shop as part of our regular supply cycle, which is typically every two (2) days (“Supply Cycle”). The amount of eggs provided will be based on prior agreements and Your demand.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '''   b. Credit Terms  
   We extend credit to You for the eggs supplied. The total amount due for each cycle of eggs provided must be paid within two (2) days from the delivery date, at which point the payment becomes due. This two-day period represents the credit window granted to You, which ends at midnight on the second day after the delivery of eggs.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '3. Repayment Failure and Legal Action\n\n',
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                         TextSpan(
                           text: '''   a. Failure to Pay  
   If You fail to repay the amount owed by the due date (end of the second day after egg delivery), We may initiate legal actions to recover the outstanding amount. This could include, but is not limited to, sending reminders, engaging collection agencies, or pursuing claims through the legal system.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '''   b. Interest and Late Fees  
   If payment is not made within the specified credit period, We reserve the right to charge a late fee of 5% of the total purchased value for every overdue cycle. This late fee will be calculated on the total amount owed and added to the outstanding balance.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '4. Crates Provided for Egg Delivery\n\n',
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                         TextSpan(
                           text: '''   a. Crates and Responsibility  
   We provide eggs in crates that remain Our property. It is Your responsibility to ensure the safe handling, use, and return of these crates. These crates are used exclusively for the transportation of eggs and must not be used for any other purpose.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '''   b. Crate Return  
   You must return the crates in good condition to Us by the time of the next egg delivery. If the crates are not returned or if they are damaged, You will be required to pay Us the full replacement value of each crate.  
   Crate Replacement Cost: 35 Rupees per crate.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '5. Liability and Damages\n\n',
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                         TextSpan(
                           text: '''   a. Egg Handling and Quality  
   You are solely responsible for the proper handling, storage, and sale of the eggs once delivered. We are not liable for any damages to the eggs resulting from improper storage or handling on Your part.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '''   b. Damage to Goods  
   Claims regarding damaged goods must be made to Us within 24 hours of receiving the eggs. After this period, We will not accept any liability for damages, and it will be deemed that You have accepted the goods in good condition.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                         TextSpan(
                           text: '''   c. Force Majeure  
   We are not liable for any failure to perform our obligations under this Agreement if such failure is due to events outside of Our control, including but not limited to natural disasters, transport disruptions, strikes, or any unforeseen circumstances.\n\n''',
                           style: TextStyle(fontWeight: FontWeight.normal),
                         ),
                       ],
                     ),
                   ),
                 ),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.pop(context),
                     child: const Text(
                       "Close",
                       style: TextStyle(color: Colors.blue),
                     ),
                   ),
                 ],
               ),
             ),
             child: const Text(
               "Click Here to Accept Terms & Conditions",
               style: TextStyle(color: Colors.red),
             ),
           ),
         ],
       );
     }
   }