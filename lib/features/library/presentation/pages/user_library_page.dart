import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserLibraryPage extends StatelessWidget {
  const UserLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Library')),
      body: ListView(
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade800, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white),
            ),
            title: const Text('Downloads'),
            subtitle: const Text(
              'Tracks you\'ve downloaded for offline playback',
            ),
            onTap: () => context.push('/library/downloads'),
          ),
          const Divider(indent: 16, endIndent: 16),

          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              color: Colors.grey[800],
              child: const Icon(Icons.favorite_rounded, color: Colors.grey),
            ),
            title: const Text('Liked Songs'),
            subtitle: const Text('Coming Soon'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
