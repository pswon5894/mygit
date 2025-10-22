import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  Future<void> signUp() async {
    if (_formKey.currentState!.validate()){
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('비밀번호가 다릅니다')));
      }
      try {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        var db = FirebaseFirestore.instance;

        final user = <String, String>{
          "name": _nameController.text,
          "email": _emailController.text,
        };

        credential.user!.sendEmailVerification();

        await db
            .collection("users")
            .doc(credential.user!.uid)
            .set(user)
            .onError((e, _) => print("Error writing document: $e"));
        Navigator.pushNamed(context, '/login');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          print('The password provided is too weak.');
        } else if (e.code == 'email-already-in-use') {
          print('The account already exists for that email.');
        }
      } catch (e) {
        print(e);
      }
    }

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('signup page'),
      ),
      body: Padding(
        padding: EdgeInsets.all(15),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if(value!.isEmpty){
                    return '이메일을 입력해주세요.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'name'),
                validator: (value) {
                  if(value!.isEmpty){
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if(value!.isEmpty){
                    return '비밀번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: 'confirm Password'),
                obscureText: true,
                validator: (value) {
                  if(value!.isEmpty){
                    return '비밀번호 확인을 입력해주세요.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: signUp, child: Text('signup')),
            ],
          ),
        )
      ),
    );
  }
}