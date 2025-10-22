import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text
      );

      if (credential.user!.emailVerified){
        Navigator.pushNamed(context, '/success');
      } else {
        credential.user!.sendEmailVerification();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('인증메일을 확인하세요.')));
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('로그인 화면'),
      ),
      body: Padding(
        padding: EdgeInsets.all(15),
        child: Form(
          key: _formKey,
          child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'Email'),
                  controller: _emailController,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return '이메일을 입력해주세요.';
                    }
                    return null;
                  }
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Password'),
                    controller: _passwordController,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return '비밀번호를 입력해주세요.';
                      }
                      return null;
                    }
                ),
                SizedBox(height: 20),
                ElevatedButton(
                    onPressed: _login, child: Text('로그인')),
                TextButton(
                    onPressed: (){
                      Navigator.pushNamed(context,'/signup');
                    },
                    child: Text('회원가입')),
              ],
          ),
        )
      ),
    );
  }
}
