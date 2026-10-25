import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parkingapp/Features/parking/providers/parking_providers.dart';




class loginScreen extends ConsumerStatefulWidget {
  const loginScreen({super.key});

  @override
  ConsumerState<loginScreen> createState() => _loginScreenState();
}

class _loginScreenState extends ConsumerState<loginScreen> {
final formKey = GlobalKey<FormState>();
final TextEditingController emailController = TextEditingController();
final TextEditingController passwordController = TextEditingController();
bool _isregistering = false;
bool _isloading = false;
bool _obscurePassword = true;

 @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

Future<void> _submit() async {
    if (!formKey.currentState!.validate() || _isloading) {
      return;
    }
    setState(() {
      _isloading = true;
    });
    try {
   final respository = ref.read(authRepositoryProvider);
   final email = emailController.text.trim();
   final password = passwordController.text.trim();
   if (_isregistering) {
      await respository.register(email: email, password: password);
    } else {
      await respository.signin(email: email, password: password);
    }
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? 'Authentication error')),
    );
    // Handle login error
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred')),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isloading = false;
      });
    }
  }
}
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
children:[
Icon( Icons.local_parking, size: 100, color: Colors.deepPurple,),
            
              const SizedBox(height: 20),
              Text('Parking App', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple), textAlign: TextAlign.center,),
             
              const SizedBox(height: 12),
              Text(
              _isregistering ? 'Create an account' : 'Login to your account',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
             
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _submit,
                child: _isloading
                    ? const CircularProgressIndicator()
                    : Text(_isregistering ? 'Register' : 'Login'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isregistering = !_isregistering;
                  });
                },
                child: Text(_isregistering
                    ? 'Already have an account? Login'
                    : 'Don\'t have an account? Register'),
              ),
]


            )),
        ),
      ))
    ),);
  }
}