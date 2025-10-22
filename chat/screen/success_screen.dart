import 'package:flutter/material.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('suceess page'),
      ),
      body: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'login succuess'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
                onPressed: (){
                  Navigator.pushNamed(context, '/login');
                },
                child: Text('logut')),
          ],
        ),
      ),
    );
  }
}