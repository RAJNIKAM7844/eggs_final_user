import 'dart:convert';
import 'dart:developer';

import 'package:EggPort/payment_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:EggPort/home_page.dart';
import 'package:EggPort/widgets/custom_background.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class Transaction {
  final String id;
  final String date;
  final double credit;
  final double paid;
  final double balance;
  final String modeOfPayment;
  final String driverId;
  final String userId;

  Transaction({
    required this.driverId,
    required this.userId,
    required this.id,
    required this.date,
    required this.credit,
    required this.paid,
    required this.balance,
    required this.modeOfPayment,
  });
}

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double eggRate = 1.0;
  double neccEggRate = 1.0;
  double targetRate = 4.7;
  double targetNeccRate = 4.7;
  String? _profileImageUrl;
  bool _isLoadingProfileImage = true;
  DateTime? _lastUpdated;
  double creditBalance = 0.0;
  double crateQuantity = 0.0;
  List<Transaction> transactions = [];
  String? _userRole;
  final List<String> images = [
    'assets/eggs1.jpg',
    'assets/eggs2.png',
    'assets/eggs3.jpg',
  ];
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    _loadUserRoleAndData();
    _setupRealtimeSubscription();
  }

  Future<void> _loadUserRoleAndData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No authenticated user found');
        return;
      }

      var userResponse = await _supabase.from('users').select('role, profile_image').eq('id', userId).maybeSingle();

      if (userResponse == null || userResponse['role'] == null) {
        userResponse = await _supabase.from('wholesale_users').select('role, profile_image').eq('id', userId).maybeSingle();
      }

      if (userResponse == null || userResponse['role'] == null) {
        throw Exception('User role not found');
      }

      setState(() {
        _userRole = userResponse?['role'] as String?;
        if (userResponse != null && userResponse['profile_image'] != null) {
          final imagePath = userResponse['profile_image'];
          if (imagePath.startsWith('userprofile/')) {
            _profileImageUrl = _supabase.storage.from('userprofile').getPublicUrl(imagePath.replaceFirst('userprofile/', ''));
          } else {
            _profileImageUrl = imagePath;
          }
        }
        _isLoadingProfileImage = false;
      });

      await Future.wait([
        _loadEggRate(),
        _loadNeccEggRate(),
        _loadCreditData(),
        _loadCrateQuantity(),
      ]);
    } catch (e) {
      print('Error loading user role or data: $e');
      setState(() {
        _isLoadingProfileImage = false;
        targetRate = 4.7;
        targetNeccRate = 4.7;
        neccEggRate = 4.7;
        creditBalance = 0.0;
        crateQuantity = 0.0;
        transactions = [];
      });
    }
  }

  Future<void> _loadCrateQuantity() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No authenticated user found for crates');
        return;
      }

      print('User role: $_userRole, User ID: $userId');

      if (_userRole == 'wholesale') {
        print('Fetching from wholesale_crates for wholesale_user_id: $userId');
        final response = await _supabase.from('wholesale_crates').select('quantity').eq('wholesale_user_id', userId).order('updated_at', ascending: false).limit(1).maybeSingle();

        print('Wholesale crates response: $response');

        setState(() {
          crateQuantity = response != null && response['quantity'] != null ? response['quantity'].toDouble() : 0.0;
          print('Wholesale crate quantity set to: $crateQuantity');
        });
      } else {
        print('Fetching from crates for user_id: $userId');
        final response = await _supabase.from('crates').select('quantity').eq('user_id', userId).maybeSingle();

        print('Customer crates response: $response');

        setState(() {
          crateQuantity = response != null && response['quantity'] != null ? response['quantity'].toDouble() : 0.0;
          print('Customer crate quantity set to: $crateQuantity');
        });
      }
    } catch (e) {
      print('Error fetching crate quantity: $e');
      setState(() {
        crateQuantity = 0.0;
      });
    }
  }

  Future<void> _loadCreditData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No authenticated user found');
        return;
      }

      final transactionsTable = _userRole == 'wholesale' ? 'wholesale_transaction' : 'transactions';
// 'id, date, credit, paid, balance, mode_of_payment'
      final transactionsResponse = await _supabase.from(transactionsTable).select().eq('user_id', userId).order('date', ascending: false);
      log(transactionsResponse.toString(), name: "kjdfsaklj");
      setState(() {
        double totalCredit = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['credit']?.toDouble() ?? 0.0);
        });
        double totalPaid = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['paid']?.toDouble() ?? 0.0);
        });
        creditBalance = totalCredit - totalPaid;

        transactions = transactionsResponse.map<Transaction>((t) {
          String dateStr = t['date']?.toString() ?? DateTime.now().toIso8601String();
          DateTime parsedDate;
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            try {
              parsedDate = DateFormat('MMM dd').parse(dateStr);
              parsedDate = DateTime(DateTime.now().year, parsedDate.month, parsedDate.day);
            } catch (e) {
              print('Error parsing date $dateStr: $e');
              parsedDate = DateTime.now();
            }
          }
          return Transaction(
            id: t['id'].toString(),
            userId: t['user_id']?.toString() ?? "",
            driverId: t['driver_id']?.toString() ?? "",
            date: DateFormat('MMM dd, h:mm a').format(parsedDate),
            credit: t['credit']?.toDouble() ?? 0.0,
            paid: t['paid']?.toDouble() ?? 0.0,
            balance: t['balance']?.toDouble() ?? 0.0,
            modeOfPayment: t['mode_of_payment']?.toString() ?? 'N/A',
          );
        }).toList();
      });
    } catch (e) {
      print('Error fetching credit data: $e');
      setState(() {
        creditBalance = 0.0;
        transactions = [];
      });
    }
  }

  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('No userId for real-time subscription');
      return;
    }

    final transactionsTable = _userRole == 'wholesale' ? 'wholesale_transaction' : 'transactions';

    _supabase
        .channel('transactions_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: transactionsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('Real-time transaction update: $payload');
            _loadCreditData();
          },
        )
        .subscribe();
  }

  Future<void> _loadEggRate() async {
    try {
      final eggRateTable = _userRole == 'wholesale' ? 'wholesale_eggrate' : 'egg_rates';

      final response = await _supabase.from(eggRateTable).select('rate, updated_at').eq('id', 1).maybeSingle();

      if (response != null && response['rate'] != null) {
        setState(() {
          targetRate = response['rate'].toDouble();
          _lastUpdated = response['updated_at'] != null ? DateTime.parse(response['updated_at'].toString()) : null;
        });
      } else {
        setState(() {
          targetRate = 4.7;
          _lastUpdated = null;
        });
      }
    } catch (e) {
      print('Error fetching egg rate: $e');
      setState(() {
        targetRate = 4.7;
        _lastUpdated = null;
      });
    }
    animateRates();
  }

  Future<void> _loadNeccEggRate() async {
    try {
      final response = await _supabase.from('necc_eggrate').select('rate').eq('id', 1).maybeSingle();

      if (response != null && response['rate'] != null) {
        setState(() {
          targetNeccRate = response['rate'].toDouble();
        });
      } else {
        setState(() {
          targetNeccRate = 4.7;
        });
      }
    } catch (e) {
      print('Error fetching necc egg rate: $e');
      setState(() {
        targetNeccRate = 4.7;
      });
    }
    animateRates();
  }

  void _startAutoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (_pageController.hasClients && mounted) {
        setState(() {
          _currentPage = (_currentPage + 1) % images.length;
        });
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      return true;
    });
  }

  void animateRates() async {
    double step = 0.01;
    double currentEggRate = 1.0;
    double currentNeccRate = 1.0;

    while (currentEggRate < targetRate || currentNeccRate < targetNeccRate) {
      await Future.delayed(const Duration(milliseconds: 2));
      if (mounted) {
        setState(() {
          if (currentEggRate < targetRate) {
            currentEggRate = (currentEggRate + step).clamp(1.0, targetRate);
            eggRate = double.parse(currentEggRate.toStringAsFixed(2));
          }
          if (currentNeccRate < targetNeccRate) {
            currentNeccRate = (currentNeccRate + step).clamp(1.0, targetNeccRate);
            neccEggRate = double.parse(currentNeccRate.toStringAsFixed(2));
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    final formatter = DateFormat('d MMMM, h:mm a');
    return formatter.format(dateTime);
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadEggRate(),
      _loadNeccEggRate(),
      _loadCreditData(),
      _loadCrateQuantity(),
    ]);
  }

  Widget _buildDotsIndicator() {
    final size = MediaQuery.of(context).size;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(images.length, (index) {
        return GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
            setState(() => _currentPage = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(horizontal: size.width * 0.01),
            width: _currentPage == index ? size.width * 0.03 : size.width * 0.02,
            height: size.height * 0.01,
            decoration: BoxDecoration(
              color: _currentPage == index ? const Color.fromARGB(255, 0, 79, 188) : const Color(0xFF757575),
              borderRadius: BorderRadius.circular(size.width * 0.01),
            ),
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _supabase.channel('transactions_user_*').unsubscribe();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: CustomBackground(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color.fromARGB(255, 30, 0, 255),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(size.width * 0.04),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => CreditDetailsPage(
                                creditBalance: creditBalance,
                                transactions: transactions,
                                userRole: _userRole ?? 'customer',
                              ),
                              transitionsBuilder: (_, animation, __, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(size.width * 0.03),
                          ),
                          elevation: 6,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.01),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Credit: ₹${creditBalance.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0288D1),
                                        fontSize: size.width * 0.04,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: size.height * 0.005),
                                Text(
                                  'Crates: ${crateQuantity.toStringAsFixed(0)} = ₹${(crateQuantity * 35).toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0288D1),
                                        fontSize: size.width * 0.04,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const HomePage(initialIndex: 3),
                              transitionsBuilder: (_, animation, __, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.only(top: size.height * 0.01),
                          child: CircleAvatar(
                            radius: size.width * 0.06,
                            backgroundColor: const Color(0xFFFFFFFF),
                            backgroundImage: _profileImageUrl != null && !_isLoadingProfileImage ? NetworkImage(_profileImageUrl!) : null,
                            child: _profileImageUrl == null || _isLoadingProfileImage
                                ? Icon(
                                    Icons.person,
                                    color: const Color(0xFF757575),
                                    size: size.width * 0.06,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -(size.height * 0.02 * 0.2)),
                  child: SizedBox(
                    height: size.height * 0.25,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (index) => setState(() => _currentPage = index),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
                          child: Hero(
                            tag: 'carousel-image-$index',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(size.width * 0.04),
                              child: Image.asset(
                                images[index],
                                fit: BoxFit.cover,
                                width: size.width * 0.9,
                                height: size.height * 0.25,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.01),
                _buildDotsIndicator(),
                SizedBox(height: size.height * 0.015),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _userRole == 'wholesale' ? 'Wholesale Egg Rate In' : 'NECC Egg Rate In',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: size.width * 0.08,
                            color: const Color(0xFF0288D1),
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: size.height * 0.005),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Bengaluru',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: size.width * 0.08,
                                  color: const Color(0xFF0288D1),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: size.width * 0.02),
                        AnimatedScale(
                          scale: neccEggRate > 1.0 ? 1.0 : 0.9,
                          duration: const Duration(milliseconds: 200),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(size.width * 0.02),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: size.width * 0.02, vertical: size.height * 0.005),
                              child: Text(
                                '₹${neccEggRate.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color.fromARGB(255, 0, 134, 224),
                                      fontSize: size.width * 0.04,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.01),
                AnimatedScale(
                  scale: eggRate > 1.0 ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 200),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(size.width * 0.03),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: size.width * 0.06, vertical: size.height * 0.02),
                      child: Text(
                        '₹${eggRate.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color.fromARGB(255, 0, 134, 224),
                              fontSize: size.width * 0.12,
                            ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.01),
                Text(
                  'Last updated: ${_formatDateTime(_lastUpdated)}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: size.width * 0.035,
                        color: const Color(0xFF757575),
                      ),
                ),
                SizedBox(height: size.height * 0.015),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: "At "),
                        TextSpan(
                          text: _userRole == 'wholesale' ? "HMS EGG DISTRIBUTORS - Wholesale" : "HMS EGG DISTRIBUTORS",
                          style: const TextStyle(fontSize: 17, color: Color.fromARGB(255, 255, 12, 12), fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: ", we take pride in delivering the finest quality eggs to your shop.....",
                        ),
                      ],
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontSize: size.width * 0.05,
                            color: const Color(0xFF757575),
                          ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: size.height * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreditDetailsPage extends StatefulWidget {
  final double creditBalance;
  final List<Transaction> transactions;
  final String userRole;

  const CreditDetailsPage({
    super.key,
    required this.creditBalance,
    required this.transactions,
    required this.userRole,
  });

  @override
  State<CreditDetailsPage> createState() => _CreditDetailsPageState();
}

class _CreditDetailsPageState extends State<CreditDetailsPage> {
  double creditBalance = 0.0;
  List<Transaction> transactions = [];
  final _supabase = Supabase.instance.client;
  bool isLoading = false;
  int currentPage = 1;
  bool showVerifyButton = false;
  static const int itemsPerPage = 5;
  String sortBy = 'date';
  bool sortAscending = true;
  String? searchQuery;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    creditBalance = widget.creditBalance;
    transactions = widget.transactions;
    _loadCreditData();
    _setupRealtimeSubscription();
    showVerifyButtonActivte();
  }

  showVerifyButtonActivte() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString("jiopay_merchantId");
    if (value != null && value.isNotEmpty) {
      setState(() {
        showVerifyButton = true;
      });
    }
  }

  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('No userId for real-time subscription in CreditDetailsPage');
      return;
    }

    final transactionsTable = widget.userRole == 'wholesale' ? 'wholesale_transaction' : 'transactions';

    _supabase
        .channel('credit_details_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: transactionsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('Real-time transaction update for ${widget.userRole}: $payload');
            _loadCreditData();
          },
        )
        .subscribe();
  }

  Future<void> _loadCreditData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No authenticated user found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      final transactionsTable = widget.userRole == 'wholesale' ? 'wholesale_transaction' : 'transactions';

      final transactionsResponse = await _supabase.from(transactionsTable).select('id, date, credit, paid, balance, mode_of_payment').eq('user_id', userId).order('date', ascending: false);

      setState(() {
        double totalCredit = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['credit']?.toDouble() ?? 0.0);
        });
        double totalPaid = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['paid']?.toDouble() ?? 0.0);
        });
        creditBalance = totalCredit - totalPaid;

        transactions = transactionsResponse.map<Transaction>((t) {
          String dateStr = t['date']?.toString() ?? DateTime.now().toIso8601String();
          DateTime parsedDate;
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            try {
              parsedDate = DateFormat('MMM dd').parse(dateStr);
              parsedDate = DateTime(DateTime.now().year, parsedDate.month, parsedDate.day);
            } catch (e) {
              print('Error parsing date $dateStr: $e');
              parsedDate = DateTime.now();
            }
          }
          return Transaction(
            userId: t['user_id']?.toString() ?? "",
            driverId: t['driver_id']?.toString() ?? "",
            id: t['id'].toString(),
            date: DateFormat('MMM dd, h:mm a').format(parsedDate),
            credit: t['credit']?.toDouble() ?? 0.0,
            paid: t['paid']?.toDouble() ?? 0.0,
            balance: t['balance']?.toDouble() ?? 0.0,
            modeOfPayment: t['mode_of_payment']?.toString() ?? 'N/A',
          );
        }).toList();

        _sortTransactions();
        _filterTransactions();
      });
    } catch (e) {
      print('Error fetching transactions for ${widget.userRole}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
      setState(() {
        transactions = [];
        creditBalance = 0.0;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _sortTransactions() {
    transactions.sort((a, b) {
      switch (sortBy) {
        case 'date':
          return sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date);
        case 'credit':
          return sortAscending ? a.credit.compareTo(b.credit) : b.credit.compareTo(a.credit);
        case 'paid':
          return sortAscending ? a.paid.compareTo(b.paid) : b.paid.compareTo(a.paid);
        case 'balance':
          return sortAscending ? a.balance.compareTo(b.balance) : b.balance.compareTo(a.balance);
        case 'modeOfPayment':
          return sortAscending ? a.modeOfPayment.compareTo(b.modeOfPayment) : b.modeOfPayment.compareTo(a.modeOfPayment);
        default:
          return 0;
      }
    });
  }

  void _filterTransactions() {
    if (searchQuery == null || searchQuery!.isEmpty) return;
    transactions = transactions.where((t) {
      final query = searchQuery!.toLowerCase();
      return t.id.toLowerCase().contains(query) || t.date.toLowerCase().contains(query) || t.modeOfPayment.toLowerCase().contains(query) || t.credit.toString().contains(query) || t.paid.toString().contains(query) || t.balance.toString().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _supabase.channel('credit_details_user_*').unsubscribe();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final paginatedTransactions = transactions.skip((currentPage - 1) * itemsPerPage).take(itemsPerPage).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userRole == 'wholesale' ? 'Wholesale Credit Details' : 'Credit Details',
          style: TextStyle(
            fontSize: size.width * 0.05,
            color: const Color(0xFFFFFFFF),
          ),
        ),
        backgroundColor: const Color(0xFF0288D1),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              size: size.width * 0.06,
              color: const Color(0xFFFFFFFF),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: size.width * 0.045,
                      color: const Color(0xFF0288D1),
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<String>(
                          value: sortBy,
                          isExpanded: true,
                          items: ['date', 'credit', 'paid', 'balance', 'modeOfPayment']
                              .map((String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value.capitalize(),
                                      style: TextStyle(
                                        fontSize: size.width * 0.04,
                                        color: const Color(0xFF757575),
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              sortBy = value!;
                              _sortTransactions();
                            });
                            Navigator.pop(context);
                          },
                        ),
                        SwitchListTile(
                          title: Text(
                            'Ascending',
                            style: TextStyle(
                              fontSize: size.width * 0.04,
                              color: const Color(0xFF757575),
                            ),
                          ),
                          value: sortAscending,
                          onChanged: (value) {
                            setState(() {
                              sortAscending = value;
                              _sortTransactions();
                            });
                            Navigator.pop(context);
                          },
                          activeColor: const Color(0xFF0288D1),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: size.width * 0.04,
                          color: const Color(0xFF757575),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: size.width * 0.04,
                          color: const Color(0xFF0288D1),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCreditData,
        color: const Color(0xFF0288D1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(size.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                  ),
                  elevation: 6,
                  child: Padding(
                    padding: EdgeInsets.all(size.width * 0.04),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                widget.userRole == 'wholesale' ? 'Wholesale Credit Balance:' : 'Credit Balance:',
                                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                      fontSize: size.width * 0.045,
                                      color: const Color(0xFF0288D1),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '₹${creditBalance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                    fontSize: size.width * 0.045,
                                    color: creditBalance > 0 ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
                                  ),
                            ),
                          ],
                        ),
                        SizedBox(height: size.height * 0.01),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Credit:',
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                    fontSize: size.width * 0.04,
                                    color: const Color(0xFF757575),
                                  ),
                            ),
                            Text(
                              '₹${transactions.fold(0.0, (sum, t) => sum + t.credit).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                    fontSize: size.width * 0.04,
                                    color: const Color(0xFF388E3C),
                                  ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Paid:',
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                    fontSize: size.width * 0.04,
                                    color: const Color(0xFF757575),
                                  ),
                            ),
                            Text(
                              '₹${transactions.fold(0.0, (sum, t) => sum + t.paid).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                    fontSize: size.width * 0.04,
                                    color: const Color(0xFF0288D1),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.02),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search (Date, Mode, Amount)',
                    labelStyle: TextStyle(
                      fontSize: size.width * 0.04,
                      color: const Color(0xFF757575),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(size.width * 0.03),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: size.width * 0.06,
                        color: const Color(0xFF757575),
                      ),
                      onPressed: () {
                        setState(() {
                          searchController.clear();
                          searchQuery = null;
                          _loadCreditData();
                        });
                      },
                    ),
                  ),
                  style: TextStyle(
                    fontSize: size.width * 0.04,
                    color: const Color(0xFF757575),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      _filterTransactions();
                    });
                  },
                ),
                SizedBox(height: size.height * 0.02),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                  ),
                  elevation: 6,
                  child: Padding(
                    padding: EdgeInsets.all(size.width * 0.04),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            widget.userRole == 'wholesale' ? 'Make a Wholesale Payment' : 'Make a Payment',
                            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                  fontSize: size.width * 0.045,
                                  color: const Color(0xFF0288D1),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Builder(builder: (context) {
                          return ElevatedButton(
                            onPressed: creditBalance > 0
                                ? isLoading
                                    ? null
                                    : () {
                                        if (showVerifyButton) return showPaymentPendingDialog(context);
                                        showAmountInputDialog(context, creditBalance);
                                      }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              foregroundColor: const Color(0xFFFFFFFF),
                              padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(size.width * 0.03),
                              ),
                            ),
                            child: Text(
                              'Pay Now',
                              style: TextStyle(fontSize: size.width * 0.04),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.02),
                Text(
                  widget.userRole == 'wholesale' ? 'Wholesale Transaction History' : 'Customer Transaction History',
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        fontSize: size.width * 0.06,
                        color: const Color(0xFF0288D1),
                      ),
                ),
                SizedBox(height: size.height * 0.01),
                if (isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF0288D1)),
                    ),
                  )
                else
                  Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paginatedTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = paginatedTransactions[index];
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(size.width * 0.03),
                            ),
                            elevation: 6,
                            child: Padding(
                              padding: EdgeInsets.all(size.width * 0.04),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          transaction.modeOfPayment,
                                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0288D1),
                                                fontSize: size.width * 0.04,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: size.height * 0.01),
                                  Text(
                                    'Date: ${transaction.date}',
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          fontSize: size.width * 0.035,
                                          color: const Color(0xFF757575),
                                        ),
                                  ),
                                  Text(
                                    'Credit: ₹${transaction.credit.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          fontSize: size.width * 0.035,
                                          color: const Color(0xFF388E3C),
                                        ),
                                  ),
                                  Text(
                                    'Paid: ₹${transaction.paid.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          fontSize: size.width * 0.035,
                                          color: const Color(0xFF0288D1),
                                        ),
                                  ),
                                  Text(
                                    'Balance: ₹${transaction.balance.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                          fontSize: size.width * 0.035,
                                          color: transaction.balance > 0 ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: size.height * 0.02),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              size: size.width * 0.06,
                              color: currentPage > 1 ? const Color(0xFF0288D1) : const Color(0xFF757575),
                            ),
                            onPressed: currentPage > 1
                                ? () {
                                    setState(() {
                                      currentPage--;
                                    });
                                  }
                                : null,
                          ),
                          Text(
                            'Page $currentPage of ${((transactions.length - 1) ~/ itemsPerPage) + 1}',
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontSize: size.width * 0.035,
                                  color: const Color(0xFF757575),
                                ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              size: size.width * 0.06,
                              color: currentPage < ((transactions.length - 1) ~/ itemsPerPage) + 1 ? const Color(0xFF0288D1) : const Color(0xFF757575),
                            ),
                            onPressed: currentPage < ((transactions.length - 1) ~/ itemsPerPage) + 1
                                ? () {
                                    setState(() {
                                      currentPage++;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                SizedBox(height: size.height * 0.04),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: showVerifyButton
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            checkJioPayStatus();
                          },
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: isLoading
                            ? CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                "Verity Payment",
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void showAmountInputDialog(BuildContext context, double maxAmount) {
    final TextEditingController controller = TextEditingController(text: maxAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          elevation: 10,
          title: const Center(
            child: Text(
              "Enter Amount",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content: SizedBox(
            height: 80,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                    // _MaxAmountInputFormatter(maxAmount),
                  ],
                  decoration: InputDecoration(
                    hintText: "Enter amount ≤ ${maxAmount.toStringAsFixed(0)}",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 10),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isLoading
                  ? null
                  : () {
                      final entered = double.tryParse(controller.text) ?? 0;
                      if (entered > 0 && entered <= maxAmount) {
                        Navigator.pop(context);
                        initiatePayment(entered);
                      }
                    },
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> initiatePayment(double amount) async {
    setState(() {
      isLoading = true;
    });
    const merchantId = "JP2001100060862";
    const merchantKey = "7a18c8a8725247e698060c5771cab40d"; // ⚠️ DO NOT PUT IN PROD

    final merchantTxnNo = "Txn${DateTime.now().millisecondsSinceEpoch}";
    final txnDate = DateTime.now().toIso8601String().replaceAll(RegExp(r'[-:.TZ]'), '').substring(0, 14);
    const returnUrl = "https://uat.jiopay.co.in/tsp/pg/api/merchant";

    final payload = {
      "merchantId": merchantId,
      "merchantTxnNo": merchantTxnNo,
      "amount": amount,
      "currencyCode": "356",
      "payType": "0",
      "customerEmailID": "test@example.com",
      "transactionType": "SALE",
      "returnURL": returnUrl,
      "txnDate": txnDate,
    };
    final secureHash = generateSecureHash(payload, merchantKey);
    payload.addAll({
      "secureHash": secureHash,
    });
    try {
      final response = await http.post(
        Uri.parse("https://uat.jiopay.co.in/tsp/pg/api/v2/initiateSale"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      log(data.toString());
      final redirectUri = data["redirectURI"];
      final tranCtx = data["tranCtx"];

      if (redirectUri != null && tranCtx != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jiopay_merchantId", merchantId);
        await prefs.setString("jiopay_merchantKey", merchantKey);
        await prefs.setString("jiopay_merchantTxnNo", merchantTxnNo);
        await prefs.setString("jiopay_amount", amount.toString());
        setState(() {
          showVerifyButton = true;
        });
        final fullUrl = "$redirectUri?tranCtx=$tranCtx";
        Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentScreen(htmlResponse: fullUrl)));
        // await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Invalid JioPay response: $data");
      }
    } catch (e) {
      log(e.toString());
      debugPrint("Error initiating payment: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> checkJioPayStatus() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final merchantId = prefs.getString("jiopay_merchantId") ?? "";
    final merchantTxnNo = prefs.getString("jiopay_merchantTxnNo") ?? "";
    final merchantKey = prefs.getString("jiopay_merchantKey") ?? "";
    final amountPaid = prefs.getString("jiopay_amount") ?? "";

    if (merchantId.isEmpty || merchantTxnNo.isEmpty || merchantKey.isEmpty) {
      debugPrint("Missing transaction data. Cannot check status.");
      return;
    }

    const transactionType = "STATUS";
    Map<String, dynamic> statusParams = {
      "merchantId": "JP2001100060862",
      "transactionType": "STATUS",
      "merchantTxnNo": merchantTxnNo,
      "originalTxnNo": merchantTxnNo,
    };

    final secureHash = generateSecureHash(
      statusParams,
      merchantKey,
    );

    final url = Uri.parse("https://uat.jiopay.co.in/tsp/pg/api/command");
    final body = {
      "merchantId": merchantId,
      "transactionType": transactionType,
      "merchantTxnNo": merchantTxnNo,
      "originalTxnNo": merchantTxnNo,
      "secureHash": secureHash,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: body,
    );

    final result = jsonDecode(response.body);
    log(result.toString());
    if (response.statusCode == 200) {
      debugPrint("🟢 JioPay Status Response: $result");

      final txnStatus = result["txnStatus"];
      final txnRespDescription = result["txnRespDescription"];
      final txnResponseCode = result["txnResponseCode"];

      if (txnStatus == "SUC" && txnResponseCode == "0000") {
        try {
          final parsedDriverId = int.parse(widget.transactions.first.driverId);
          log(parsedDriverId.toString());
          final newBalance = creditBalance - double.parse(amountPaid);
          print('Inserting payment transaction with driver_id: $parsedDriverId');
          await _supabase.from('transactions').insert({
            'user_id': widget.transactions.first.userId,
            'date': DateTime.now().toIso8601String(),
            'credit': 0.0,
            'paid': amountPaid,
            'balance': newBalance,
            'mode_of_payment': "UPI",
            'driver_id': parsedDriverId,
          }).then((value) async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Transaction successfull')),
            );
            _loadCreditData();
          });

          setState(() {
            creditBalance = newBalance;
            isLoading = false;
          });

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment recorded successfully')),
          );
        } catch (e) {
          log(e.toString());
          print('Error in _showPaymentDialog: $e');
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record payment: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction Failed')),
        );
        debugPrint("⌛ Pending/Unknown: $txnRespDescription");
      }
    } else {
      debugPrint("❌ Failed to fetch payment status. HTTP ${response.statusCode}");
    }
    await prefs.remove("jiopay_merchantId");
    await prefs.remove("jiopay_merchantTxnNo");
    await prefs.remove("jiopay_merchantKey");
    await prefs.remove("jiopay_amount");
    setState(() {
      isLoading = false;
      showVerifyButton = false;
    });
  }

  String generateSecureHash(Map<String, dynamic> params, String merchantKey) {
    // 1. Filter out null/empty values
    final filtered = params.entries.where((e) => e.value.toString() != "").toList();

    // 2. Sort keys in ascending order
    filtered.sort((a, b) => a.key.compareTo(b.key));

    final concatenatedValues = filtered.map((e) => e.value).join();

    final key = utf8.encode(merchantKey);
    final bytes = utf8.encode(concatenatedValues);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString().toLowerCase();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class _MaxAmountInputFormatter extends TextInputFormatter {
  final double max;

  _MaxAmountInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    try {
      final value = double.tryParse(newValue.text);
      if (value == null || value > max) return oldValue;
    } catch (_) {
      return oldValue;
    }
    return newValue;
  }
}

void showPaymentPendingDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Action Needed",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "You haven’t verified the payment yet.\nPlease tap the 'Verify Payment' button to check payment status.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF184C98),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Okay",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
