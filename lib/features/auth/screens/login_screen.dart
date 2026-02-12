import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_event.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';
import 'package:location_tracker/features/auth/widgets/login_button.dart';
import 'package:location_tracker/features/auth/widgets/login_logo.dart';
import 'package:location_tracker/features/auth/widgets/password_field.dart';
import 'package:location_tracker/features/auth/widgets/register_link.dart';
import 'package:location_tracker/features/auth/widgets/username_field.dart';
import 'package:location_tracker/features/auth/widgets/welcome_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        LoginSubmitted(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    const LoginLogo(),
                    const SizedBox(height: 32),
                    const WelcomeText(),
                    const SizedBox(height: 48),
                    UsernameField(controller: _usernameController),
                    const SizedBox(height: 16),

                    PasswordField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmitted: (_) => _submit(context),
                    ),
                    const SizedBox(height: 32),
                    LoginButton(
                      isLoading: state is AuthLoading,
                      onPressed: () => _submit(context),
                    ),

                    const SizedBox(height: 24),
                    const RegisterLink(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
