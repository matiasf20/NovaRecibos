// ignore_for_file: prefer_const_constructors, use_build_context_synchronously
// 🚀 NECESARIO PARA kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pantalla_admin.dart';
import 'pantalla_registro_empresa.dart';

class PantallaLoginAdmin extends StatefulWidget {
  const PantallaLoginAdmin({super.key});

  @override
  State<PantallaLoginAdmin> createState() => _PantallaLoginAdminState();
}

class _PantallaLoginAdminState extends State<PantallaLoginAdmin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _cargando = false;
  bool _ocultarPassword = true;
  bool _recordarme = false;

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
  }

  Future<void> _cargarCredencialesGuardadas() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _recordarme = prefs.getBool('recordarme_activado_admin') ?? false;
        if (_recordarme) {
          _emailController.text = prefs.getString('email_guardado_admin') ?? '';
          _passwordController.text = prefs.getString('password_guardado_admin') ?? '';
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _loginAdministrador() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _mostrarAlerta("Por favor, rellena todos los campos.");
      return;
    }

    setState(() { _cargando = true; });

    try {
      final String correoIngresado = _emailController.text.trim();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correoIngresado,
        password: _passwordController.text.trim(),
      );

      DocumentSnapshot docEmpresa = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(correoIngresado)
          .get();

      if (!docEmpresa.exists) {
        QuerySnapshot queryAlternativa = await FirebaseFirestore.instance
            .collection('empresas')
            .where('correo_admin', isEqualTo: correoIngresado)
            .get();

        if (queryAlternativa.docs.isEmpty) {
          await FirebaseAuth.instance.signOut();
          _mostrarAlerta("No tienes permisos de Administrador Corporativo.");
          return;
        }
      }

      // 🚀 ESCUDO DE PERSISTENCIA PARA IPHONE (Evita caídas si Safari bloquea el LocalStorage)
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        if (_recordarme) {
          await prefs.setString('email_guardado_admin', _emailController.text.trim());
          await prefs.setString('password_guardado_admin', _passwordController.text.trim());
          await prefs.setBool('recordarme_activado_admin', true);
        } else {
          await prefs.remove('email_guardado_admin');
          await prefs.remove('password_guardado_admin');
          await prefs.setBool('recordarme_activado_admin', false);
        }
      } catch (e) {
        debugPrint("Error al conectar con la base de datos: $e");
      }

      _mostrarAlerta("¡Ingreso exitoso al Panel Administrador de Flota!");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PantallaAdminDashboard(),
        ),
      );

    } on FirebaseAuthException catch (e) {
      _mostrarAlerta(e.message ?? "Error de ingreso. Verifica tus credenciales.");
    } catch (e) {
      _mostrarAlerta("Error al conectar con la base de datos: $e");
    } finally {
      if (mounted) {
        setState(() { _cargando = false; });
      }
    }
  }

  void _mostrarAlerta(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 40),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const Text(
                    "¡Bienvenido a\nNovaRecibos!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                      height: 1.1, 
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text("Ingreso Administrador", style: TextStyle(fontSize: 16, color: Colors.white70)),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Text("Panel Administrador de Flota", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Correo Electrónico Administrador",
                          prefixIcon: const Icon(Icons.admin_panel_settings, color: Color(0xFF0D47A1)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _passwordController,
                        obscureText: _ocultarPassword,
                        decoration: InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0D47A1)),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _recordarme,
                            activeColor: const Color(0xFF0D47A1),
                            onChanged: (bool? valor) {
                              setState(() {
                                _recordarme = valor ?? false;
                              });
                            },
                          ),
                          const Text("Recordar mis datos", style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _cargando
                        ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _loginAdministrador,
                            child: const Text("INGRESAR AL PANEL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRegistroEmpresa()));
                        },
                        child: const Text(
                          "¿No tienes una cuenta? Une tu empresa a NovaRecibos aquí",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}