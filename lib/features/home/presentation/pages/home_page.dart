import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.goNamed(AppRouter.profile),
          ),
        ],
      ),
      body: const Center(
        child: Text('Home Page Content'),
      ),
    );
  }
}