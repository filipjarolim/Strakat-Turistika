import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../config/app_colors.dart';
import '../animations/app_animations.dart';
import 'webview_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

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
    _initializeBiometrics();
    _loadSavedCredentials();
    _setupPasswordListener();
  }
  
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800), // Keep longer for initial fade
      vsync: this,
    );
    _slideController = AnimationController(
      duration: AppAnimations.durationLong,
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: AppAnimations.durationMedium,
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 1000), // Keep longer for success
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: AppAnimations.curveStandard,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: AppAnimations.curveDecelerate,
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
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }
  
  Future<void> _initializeBiometrics() async {
    try {
      // Check if device supports biometrics
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!isDeviceSupported) {
        if (mounted) {
          setState(() {
            _biometricAvailable = false;
            _isBiometricEnabled = false;
          });
        }
        return;
      }
      
      // Check if biometrics are available
      final isAvailable = await _localAuth.canCheckBiometrics;
      
      if (mounted) {
        setState(() {
          _biometricAvailable = isAvailable;
        });
      }
      
      if (_biometricAvailable) {
        final prefs = await SharedPreferences.getInstance();
        final isEnabled = prefs.getBool('biometric_enabled') ?? false;
        
        if (mounted) {
          setState(() {
            _isBiometricEnabled = isEnabled;
          });
        }
      }
    } catch (e) {
      print('Biometric initialization error: $e');
      // Set biometrics to false on error
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _isBiometricEnabled = false;
        });
      }
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
      print('Error loading saved credentials: $e');
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
    Color color = AppColors.textTertiary;
    
    if (password.isEmpty) {
      strength = 0.0;
      text = '';
    } else if (password.length < 6) {
      strength = 0.25;
      text = 'Slabé';
      color = Colors.red;
    } else if (password.length < 8) {
      strength = 0.5;
      text = 'Střední';
      color = Colors.orange;
    } else if (password.length < 10) {
      strength = 0.75;
      text = 'Silné';
      color = Colors.yellow.shade700;
    } else {
      strength = 1.0;
      text = 'Velmi silné';
      color = AppColors.success;
    }
    
    // Add bonus for complexity
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
      print('Error saving credentials: $e');
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue ? '✅ Biometrické přihlášení povoleno' : '❌ Biometrické přihlášení zakázáno'),
          backgroundColor: newValue ? AppColors.success : AppColors.textTertiary,
        ),
      );
    } catch (e) {
      print('Error toggling biometric: $e');
    }
  }
  
  Future<void> _authenticateWithBiometrics() async {
    if (!_biometricAvailable || !_isBiometricEnabled) return;
    
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Přihlaste se pomocí biometrie',
      );
      
      if (isAuthenticated) {
        // Try to load saved credentials and sign in
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('saved_email');
        
        if (savedEmail != null) {
          _emailController.text = savedEmail;
          await _signInWithCredentials();
        } else {
          _showError('Žádné uložené přihlašovací údaje');
        }
      }
    } catch (e) {
      _showError('Biometrické přihlášení selhalo: $e');
    }
  }
  
  void _showError(String message) {
    HapticService.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reverse());
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
  
  void _showSuccess(String message) {
    HapticService.mediumImpact();
    _successController.forward().then((_) => _successController.reverse());
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $message'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
  
  Future<void> _validateEmail(String email) async {
    // Cancel previous timer
    _emailValidationTimer?.cancel();
    
    // Set new timer for debounced validation
    _emailValidationTimer = Timer(const Duration(milliseconds: 500), () async {
      if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        return;
      }
      
      // Here you could add additional validation like checking if email exists
      // For now, we'll just simulate a brief delay
      await Future.delayed(const Duration(milliseconds: 200));
    });
  }

  Future<void> _signInWithCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signUpWithCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      _showError('Zadejte email pro obnovení hesla');
      return;
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Zadejte platný email');
      return;
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Odesílám email...'),
          ],
        ),
      ),
    );
    
    // Simulate email sending
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      _showSuccess('Email pro obnovení hesla byl odeslán na $email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Back button with animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * 10 * (_shakeAnimation.value - 0.5), 0),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  const SizedBox(height: 8),
                  
                  // Main card containing tabs, form and actions
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmented tabs
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _isLogin = true);
                                    HapticService.lightImpact();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _isLogin ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Přihlášení',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _isLogin ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _isLogin = false);
                                    HapticService.lightImpact();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: !_isLogin ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Registrace',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: !_isLogin ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                  
                  const SizedBox(height: 32),
                  
                  // Biometric login option
                  if (_biometricAvailable && _isLogin)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          // Biometric toggle
                          Row(
                            children: [
                              Switch(
                                value: _isBiometricEnabled,
                                onChanged: (value) => _toggleBiometric(),
                                activeColor: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Povolit biometrické přihlášení',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Biometric login button
                          if (_isBiometricEnabled)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _authenticateWithBiometrics,
                                icon: const Icon(Icons.fingerprint, size: 20),
                                label: const Text('Přihlásit se biometrií'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.info,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  
                  // Enhanced Form inside card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          // Name field (for register)
                          _buildEnhancedInputField(
                            controller: _nameController,
                            label: 'Celé jméno',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Prosím zadejte své jméno';
                              }
                              if (value.length < 2) {
                                return 'Jméno musí mít alespoň 2 znaky';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        // Email field with validation
                        _buildEnhancedInputField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) => _validateEmail(value),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Prosím zadejte svůj email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Prosím zadejte platný email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Password field with strength indicator
                        _buildEnhancedInputField(
                          controller: _passwordController,
                          label: 'Heslo',
                          icon: Icons.lock,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                              HapticService.lightImpact();
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Prosím zadejte své heslo';
                            }
                            if (value.length < 6) {
                              return 'Heslo musí mít alespoň 6 znaků';
                            }
                            return null;
                          },
                        ),
                        
                        // Password strength indicator
                        if (_passwordController.text.isNotEmpty && !_isLogin)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: _passwordStrength,
                                        backgroundColor: AppColors.border,
                                        valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _passwordStrengthText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _passwordStrengthColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Heslo by mělo obsahovat alespoň 8 znaků, velká a malá písmena, čísla a symboly',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Confirm password field (for register)
                        if (!_isLogin) ...[
                          const SizedBox(height: 20),
                          _buildEnhancedInputField(
                            controller: _confirmPasswordController,
                            label: 'Potvrdit heslo',
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                color: AppColors.primary,
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                HapticService.lightImpact();
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Prosím potvrďte své heslo';
                              }
                              if (value != _passwordController.text) {
                                return 'Hesla se neshodují';
                              }
                              return null;
                            },
                          ),
                        ],
                        
                        if (_isLogin) ...[
                          const SizedBox(height: 16),
                          
                          // Remember me and Forgot password
                          Row(
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() => _rememberMe = value ?? false);
                                      HapticService.lightImpact();
                                    },
                                    activeColor: const Color(0xFF4CAF50),
                                  ),
                                  const Text(
                                    'Zapamatovat si mě',
                                    style: TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _forgotPassword,
                                child: const Text(
                                  'Zapomněli jste heslo?',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        
                        // Enhanced Login/Register button
                        AnimatedBuilder(
                          animation: _successAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_successAnimation.value * 0.1),
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : (_isLogin ? _signInWithCredentials : _signUpWithCredentials),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          _isLogin ? 'Přihlásit se' : 'Registrovat se',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Enhanced Or divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Nebo se přihlaste pomocí',
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Enhanced Google login button
                        _buildEnhancedSocialButton(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: 'assets/google_logo.png',
                          label: 'Google',
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF333333),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  ),
                      ],
                    ),
                  ),

                  const Spacer(),
                  
                  // Compact Terms and Privacy links
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 0,
                      children: [
                        const Text(
                          'Registrací souhlasíte s',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticService.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WebViewPage(
                                  title: 'Podmínky použití',
                                  url: 'https://www.strakata.cz/terms',
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('podmínkami použití', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                        const Text('a', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        TextButton(
                          onPressed: () {
                            HapticService.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WebViewPage(
                                  title: 'Zásady ochrany osobních údajů',
                                  url: 'https://www.strakata.cz/privacy',
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('zásadami ochrany osobních údajů', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildAnimatedVeggieIcon(int index) {
    return AnimatedPositioned(
      duration: Duration(seconds: 3 + (index % 3)),
      curve: Curves.easeInOut,
      top: 20 + (index * 25),
      right: 20 + (index % 2 * 30),
      child: _buildVeggieIcon(
        Icons.eco,
        [
          const Color(0xFF4CAF50),
          const Color(0xFF66BB6A),
          const Color(0xFF81C784),
        ][index % 3],
      ),
    );
  }

  Widget _buildVeggieIcon(IconData icon, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }

  Widget _buildEnhancedInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType ?? TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          enableIMEPersonalizedLearning: true,
          enableSuggestions: true,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFF111827), // High-contrast input text (always visible on light fill)
            fontSize: 16,
          ),
          cursorColor: const Color(0xFF4CAF50),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF4CAF50),
              size: 20,
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedSocialButton({
    required VoidCallback? onPressed,
    required String label,
    String? icon,
    IconData? iconData,
    bool isIcon = false,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isIcon && iconData != null)
                Icon(
                  iconData,
                  size: 20,
                  color: textColor ?? const Color(0xFF333333),
                )
              else if (icon != null)
                Image.asset(
                  icon,
                  width: 20,
                  height: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? const Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 

// Moved to pages/webview_page.dart