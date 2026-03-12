import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/identity_service.dart';

/// A premium Paywall Screen for the $15/month subscription.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  Future<void> _subscribe(BuildContext context) async {
    final identity = context.read<IdentityService>();
    final api = context.read<ApiService>();

    // 1. Mock Payment Processing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    await Future.delayed(const Duration(seconds: 2)); // Simulate payment gateway
    
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    // 2. Notify Backend
    final deviceId = await identity.getDeviceId();
    final success = await api.upgradeToPremium(deviceId);

    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment Successful! Premium Features Unlocked.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Return home
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verified, but backend sync failed. Please contact support.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo, Colors.deepPurple],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                
                const Spacer(),
                
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Icon(Icons.star_rounded, size: 80, color: Colors.amber),
                      const SizedBox(height: 24),
                      const Text(
                        'Unlock Full Power',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Get unlimited document scans, OCR, and PDF editing with the Pro Plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Price Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Monthly Premium',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '\$15.00 / Month',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Lock/Unlock Monthly Cycle',
                              style: TextStyle(color: Colors.amber, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Subscribe Button
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () => _subscribe(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'SUBSCRIBE NOW',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Secured by Device Locking System',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
