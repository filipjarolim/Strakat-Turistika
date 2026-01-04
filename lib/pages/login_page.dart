import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../config/app_colors.dart';
import '../animations/app_animations.dart';

import '../widgets/ui/app_toast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;
  bool _biometricAvailable = false;
  bool _isBiometricEnabled = false;
  
  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = AppColors.textTertiary;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shakeController;
  late AnimationController _successController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _successAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  // Local auth
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Debounce timer for email validation
  Timer? _emailValidationTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSavedCredentials();
    _setupPasswordListener();
    // Initialize biometrics and auto-trigger if possible/enabled
    _initializeBiometrics();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000), 
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: AppAnimations.durationMedium,
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    _successAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));
    
    // Start entrance animations
    _fadeController.forward();
    _slideController.forward();
  }
  
  Future<void> _initializeBiometrics() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        if (mounted) setState(() => _biometricAvailable = false);
        return;
      }
      
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (mounted) setState(() => _biometricAvailable = isAvailable);
      
      if (isAvailable) {
        final prefs = await SharedPreferences.getInstance();
        final isEnabled = prefs.getBool('biometric_enabled') ?? false;
        
        if (mounted) {
          setState(() => _isBiometricEnabled = isEnabled);
          
          // Auto-trigger if enabled and not currently loading (and page is fresh)
          if (isEnabled && !_isLoading) {
             // Small delay to let UI settle
             Future.delayed(const Duration(milliseconds: 500), () {
               if (mounted) _authenticateWithBiometrics();
             });
          }
        }
      }
    } catch (e) {
      debugPrint('Biometric initialization error: $e');
      if (mounted) setState(() {
        _biometricAvailable = false;
        _isBiometricEnabled = false;
      });
    }
  }
  
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedRememberMe = prefs.getBool('remember_me') ?? false;
      
      if (mounted && savedEmail != null && savedRememberMe) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }
  
  void _setupPasswordListener() {
    _passwordController.addListener(() {
      _updatePasswordStrength(_passwordController.text);
    });
  }
  
  void _updatePasswordStrength(String password) {
    double strength = 0.0;
    String text = '';
    Color color = AppColors.textTertiary; // Default dark text, but we need light for this bg? 
    // Actually we will use specific colors for strength regardless of theme
    
    if (password.isEmpty) {
      strength = 0.0;
      text = '';
    } else if (password.length < 6) {
      strength = 0.25;
      text = 'Slabé';
      color = const Color(0xFFFF5252); // Bright Red
    } else if (password.length < 8) {
      strength = 0.5;
      text = 'Střední';
      color = const Color(0xFFFFAB40); // Orange Accent
    } else if (password.length < 10) {
      strength = 0.75;
      text = 'Silné';
      color = const Color(0xFFFFD740); // Yellow Accent
    } else {
      strength = 1.0;
      text = 'Velmi silné';
      color = const Color(0xFF69F0AE); // Green Accent
    }
    
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.1;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.1;
    
    strength = strength.clamp(0.0, 1.0);
    
    if (mounted) {
      setState(() {
        _passwordStrength = strength;
        _passwordStrengthText = text;
        _passwordStrengthColor = color;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shakeController.dispose();
    _successController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _emailValidationTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }
  
  Future<void> _toggleBiometric() async {
    if (!_biometricAvailable) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final newValue = !_isBiometricEnabled;
      
      await prefs.setBool('biometric_enabled', newValue);
      
      if (mounted) {
        setState(() {
          _isBiometricEnabled = newValue;
        });
      }
      
      HapticService.lightImpact();
      
      if (newValue) {
        AppToast.showSuccess(context, 'Biometrické přihlášení povoleno');
      } else {
        AppToast.showInfo(context, 'Biometrické přihlášení zakázáno');
      }
    } catch (e) {
      debugPrint('Error toggling biometric: $e');
    }
  }
  
  Future<void> _authenticateWithBiometrics() async {
    if (!_biometricAvailable || !_isBiometricEnabled) return;
    
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Přihlaste se pomocí biometrie',
      );
      
      if (isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('saved_email');
        
        if (savedEmail != null) {
          _emailController.text = savedEmail;
          await _signInWithCredentials();
        }
      }
    } catch (e) {
      // Don't show error if user canceled
      debugPrint('Biometric auth failed: $e');
    }
  }
  
  void _showError(String message) {
    HapticService.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reverse());
    AppToast.showError(context, message);
  }
  
  void _showSuccess(String message) {
    HapticService.mediumImpact();
    _successController.forward().then((_) => _successController.reverse());
    AppToast.showSuccess(context, message);
  }
  
  Future<void> _validateEmail(String email) async {
    _emailValidationTimer?.cancel();
    _emailValidationTimer = Timer(const Duration(milliseconds: 500), () async {
      if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        return;
      }
      // Future expansion: check if email exists
    });
  }

  Future<void> _signInWithCredentials() async {
    if (!_formKey.currentState!.validate()) {
      HapticService.heavyImpact();
      _shakeController.forward().then((_) => _shakeController.reverse());
      return;
    }
    
    setState(() => _isLoading = true);
    HapticService.mediumImpact();

    try {
      final result = await AuthService.signInWithCredentials(
        _emailController.text,
        _passwordController.text,
      );
      
      if (result.success && result.user != null) {
        await _saveCredentials();
        if (mounted) {
          _showSuccess('Vítejte zpět, ${result.user!.name}!');
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        _showError(result.error ?? 'Přihlášení selhalo');
      }
    } catch (e) {
      _showError('Chyba: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithCredentials() async {
    if (!_formKey.currentState!.validate()) {
       HapticService.heavyImpact();
      _shakeController.forward().then((_) => _shakeController.reverse());
      return;
    }
    
    setState(() => _isLoading = true);
    HapticService.mediumImpact();

    try {
      final result = await AuthService.signUpWithCredentials(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
      );
      
      if (result.success && result.user != null) {
        await _saveCredentials();
        if (mounted) {
          _showSuccess('Vítejte, ${result.user!.name}!');
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        _showError(result.error ?? 'Registrace selhala');
      }
    } catch (e) {
      _showError('Chyba: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    HapticService.mediumImpact();

    try {
      final result = await AuthService.signInWithGoogle();
      
      if (result.success && result.user != null) {
        await _saveCredentials();
        if (mounted) {
          _showSuccess('Vítejte zpět, ${result.user!.name}!');
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        _showError(result.error ?? 'Google přihlášení selhalo');
      }
    } catch (e) {
      _showError('Chyba: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Zadejte email pro obnovení hesla');
      return;
    }
    // ... basic validation ...
    
    // Show glass dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: const Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 16),
              Text('Odesílám email...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.of(context).pop();
      _showSuccess('Email pro obnovení hesla byl odeslán na $email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Immersive Background Layer
          Positioned.fill(
            child: Image.asset(
              'assets/login_background.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // 2. Dark Gradient Overlay (copied from Home to ensure match)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.60),
                    Colors.black.withOpacity(0.50),
                    Colors.black.withOpacity(0.60),
                    Colors.black.withOpacity(0.80), 
                  ],
                ),
              ),
            ),
          ),
          
          // 3. Content Scrollable Area
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value * 10 * (_shakeAnimation.value - 0.5), 0),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Header Text
                        Text(
                          _isLogin ? 'Vítejte zpět!' : 'Vytvořit účet',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin ? 'Přihlaste se a pokračujte v objevování' : 'Přidejte se k nám a začněte dobrodružství',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Glass Container Form
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                                decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35), // Darker but clearer
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  // Toggle Tabs
                                  _buildGlassTabs(),
                                  const SizedBox(height: 32),
                                  
                                  Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        if (!_isLogin) ...[
                                          _buildGlassField(
                                            controller: _nameController,
                                            label: 'Celé jméno',
                                            icon: Icons.person_outline_rounded,
                                            validator: (v) => v!.length < 2 ? 'Jméno je příliš krátké' : null,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        
                                        _buildGlassField(
                                          controller: _emailController,
                                          label: 'Email',
                                          icon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          onChanged: _validateEmail,
                                          validator: (v) => !v!.contains('@') ? 'Neplatný email' : null,
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        _buildGlassField(
                                          controller: _passwordController,
                                          label: 'Heslo',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: _obscurePassword,
                                          toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                          validator: (v) => v!.length < 6 ? 'Heslo musí mít alespoň 6 znaků' : null,
                                        ),
                                        
                                        if (_passwordController.text.isNotEmpty && !_isLogin)
                                          _buildPasswordStrength(),
                                          
                                        if (!_isLogin) ...[
                                          const SizedBox(height: 16),
                                          _buildGlassField(
                                            controller: _confirmPasswordController,
                                            label: 'Potvrdit heslo',
                                            icon: Icons.lock_reset_rounded,
                                            obscureText: _obscureConfirmPassword,
                                            toggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                            validator: (v) => v != _passwordController.text ? 'Hesla se neshodují' : null,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Login Actions (Remember Me / Forgot Password)
                                  if (_isLogin)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                onChanged: (v) {
                                                  HapticService.lightImpact();
                                                  setState(() => _rememberMe = v!);
                                                },
                                                fillColor: WidgetStateProperty.resolveWith((states) => 
                                                  states.contains(WidgetState.selected) ? AppColors.primary : Colors.white.withOpacity(0.3)
                                                ),
                                                side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Zapamatovat',
                                              style: TextStyle(color: Colors.white, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        GestureDetector(
                                          onTap: _forgotPassword,
                                          child: Text(
                                            'Zapomenuté heslo?',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                  const SizedBox(height: 32),
                                  
                                  // Main Action Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading 
                                        ? null 
                                        : (_isLogin ? _signInWithCredentials : _signUpWithCredentials),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 8,
                                        shadowColor: AppColors.primary.withOpacity(0.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isLoading 
                                        ? const SizedBox(
                                            height: 24, 
                                            width: 24, 
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                          )
                                        : Text(
                                            _isLogin ? 'Přihlásit se' : 'Registrovat se',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'nebo',
                                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Social Login
                                  _buildGlassSocialButton(
                                    text: 'Pokračovat s Google',
                                    iconPath: 'assets/google_logo.png',
                                    onPressed: _signInWithGoogle,
                                  ),
                                  
                                  if (_isLogin && _biometricAvailable) ...[
                                    const SizedBox(height: 16), 
                                    _buildGlassBiometricButton(),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Glass Widgets ---

  Widget _buildGlassTabs() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTabItem(title: 'Přihlášení', isSelected: _isLogin, onTap: () => setState(() => _isLogin = true)),
          _buildTabItem(title: 'Registrace', isSelected: !_isLogin, onTap: () => setState(() => _isLogin = false)),
        ],
      ),
    );
  }

  Widget _buildTabItem({required String title, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    VoidCallback? toggleObscure,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.08), 
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7), size: 22),
            suffixIcon: toggleObscure != null 
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.white.withOpacity(0.7),
                    size: 22,
                  ),
                  onPressed: toggleObscure,
                )
              : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
            ),
            errorStyle: const TextStyle(color: Color(0xFFFF8A80)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPasswordStrength() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _passwordStrength,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor), 
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _passwordStrengthText,
            style: TextStyle(
              color: _passwordStrengthColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGlassSocialButton({
    required String text,
    required String iconPath,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          HapticService.lightImpact();
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white, // Solid white background
          foregroundColor: Colors.black87, // Dark text
          side: BorderSide.none, // No border needed for pill
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, height: 24, width: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGlassBiometricButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleBiometric,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isBiometricEnabled 
              ? AppColors.primary.withOpacity(0.2) 
              : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isBiometricEnabled ? AppColors.primary : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fingerprint, 
                size: 18, 
                color: _isBiometricEnabled ? AppColors.primary : Colors.white.withOpacity(0.6)
              ),
              const SizedBox(width: 8),
              Text(
                'Biometrické přihlášení ${_isBiometricEnabled ? "Zapnuto" : "Vypnuto"}',
                style: TextStyle(
                  fontSize: 12,
                  color: _isBiometricEnabled ? AppColors.primary : Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}