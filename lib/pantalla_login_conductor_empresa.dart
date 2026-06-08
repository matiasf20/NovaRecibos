// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'pantalla_conductor_empresa.dart'; 

class PantallaLoginConductorEmpresa extends StatefulWidget {
  const PantallaLoginConductorEmpresa({super.key});

  @override
  State<PantallaLoginConductorEmpresa> createState() => _PantallaLoginConductorEmpresaState();
}

class _PantallaLoginConductorEmpresaState extends State<PantallaLoginConductorEmpresa> {
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordarme = prefs.getBool('recordarme_activado_flota') ?? false; 
      if (_recordarme) {
        // Al cargar, aseguramos minúsculas limpias
        _emailController.text = (prefs.getString('email_guardado_flota') ?? '').trim().toLowerCase();
        _passwordController.text = ''; // 🚀 NUNCA carga la contraseña por seguridad
      }
    });
  }

  void _loginConductorFlota() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _mostrarAlerta("Por favor, rellena todos los campos.");
      return;
    }

    setState(() { _cargando = true; });

    try {
      // 🚀 LA REGLA DE ORO: Estandarizamos el correo inmediatamente a minúsculas puras
      final String correoTipeado = _emailController.text.trim();
      final String correoLimpio = correoTipeado.toLowerCase();

      // 1. Validar identidad en Firebase Auth usando el correo controlado
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correoLimpio,
        password: _passwordController.text.trim(),
      );

      final String? correoAuth = userCredential.user?.email?.trim().toLowerCase();

      // Lista de respaldo para bases de datos con IDs históricos en mayúsculas
      List<String> variaciones = {
        correoLimpio,
        correoTipeado,
        if (correoAuth != null) correoAuth,
      }.toList();

      // 2. Verificar que exista en la base de datos de la flota de manera tolerante
      DocumentSnapshot choferDoc = await FirebaseFirestore.instance
          .collection('conductores_flota')
          .doc(correoLimpio)
          .get();

      if (!choferDoc.exists) {
        for (String variante in variaciones) {
          DocumentSnapshot docVar = await FirebaseFirestore.instance.collection('conductores_flota').doc(variante).get();
          if (docVar.exists) {
            choferDoc = docVar;
            break;
          }
        }
      }

      if (!choferDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _mostrarAlerta("Tus credenciales existen, pero no estás asignado a ninguna flota activa.");
        return;
      }

      // 🚀 SEGURO DE PERSISTENCIA: Solo guardamos el correo, jamás la clave
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_recordarme) {
        await prefs.setString('email_guardado_flota', correoLimpio);
        await prefs.setBool('recordarme_activado_flota', true);
        await prefs.remove('password_guardado_flota'); // Limpieza preventiva obligatoria
      } else {
        await prefs.remove('email_guardado_flota');
        await prefs.remove('password_guardado_flota');
        await prefs.setBool('recordarme_activado_flota', false);
      }

      _mostrarAlerta("¡Ingreso exitoso a la flota!");

      // 3. VIAJE DIRECTO AL DASHBOARD
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PantallaConductorEmpresa(),
        ),
      );

    } on FirebaseAuthException catch (e) {
      String mensaje = "Error al iniciar sesión.";
      if (e.code == 'user-not-found') mensaje = "Usuario no encontrado.";
      if (e.code == 'wrong-password') mensaje = "Contraseña incorrecta.";
      if (e.code == 'invalid-credential') mensaje = "Credenciales inválidas.";
      _mostrarAlerta(mensaje);
    } catch (e) {
      _mostrarAlerta("Error de sincronización con la flota: $e");
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
                  const Text("Ingreso Conductor Flota", style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Text(
                        "Ingreso de Choferes Flotas",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Ingresa las credenciales provistas por tu flota",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 40),

                      ExcludeSemantics(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Correo Conductor Flota",
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0D47A1)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      ExcludeSemantics(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _ocultarPassword,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: "Clave de ingreso",
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0D47A1)),
                            suffixIcon: IconButton(
                              icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                              onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
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
                          const Text("Recordar mi correo", style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                            onPressed: _loginConductorFlota,
                            child: const Text("INGRESAR A LA FLOTA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "¿No tienes cuenta? Solicítala al Administrador de tu Flota.",
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