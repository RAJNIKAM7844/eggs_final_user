import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final String htmlResponse;
  const PaymentScreen({super.key, required this.htmlResponse});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..loadRequest(Uri.parse(widget.htmlResponse))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final url = request.url;
          log(url);
          debugPrint("🔁 Navigation URL: $url");
          if (url.contains("returnURL") || url.contains("tsp/pg/api/merchant")) {
            Navigator.pop(context, "payment_complete");
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
     
      child: Scaffold(
        appBar: AppBar(title: const Text("Complete Payment")),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}

Future<void> launchUPIUrl(String upiUrl) async {
  final uri = Uri.parse(upiUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // Show error to user
    print('Could not launch $upiUrl');
  }
}
