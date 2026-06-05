// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 IMPORTACIÓN AGREGADA
import 'pantalla_conductor_independiente.dart'; 
import 'pantalla_registro_persona.dart';

class PantallaLoginPersona extends StatefulWidget {
  const PantallaLoginPersona({super.key});

  @override
  State<PantallaLoginPersona> createState() => _PantallaLoginPersonaState();
}

class _PantallaLoginPersonaState extends State<PantallaLoginPersona> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _cargando = false;
  bool _ocultarPassword = true;

  // 🚀 PIEZA A: VARIABLE Y CARGADOR INICIAL
  bool _recordarme = false;

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
  }

  // Carga los datos si el usuario activó "Recuérdame" antes
  Future<void> _cargarCredencialesGuardadas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordarme = prefs.getBool('recordarme_activado_persona') ?? false; // Usamos un nombre específico
      if (_recordarme) {
        _emailCtrl.text = prefs.getString('email_guardado_persona') ?? '';
        _passwordCtrl.text = prefs.getString('password_guardado_persona') ?? '';
      }
    });
  }

  Future<void> _iniciarSesionIndependiente() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _mostrarAlerta("Correo y contraseña son obligatorios.");
      return;
    }

    setState(() { _cargando = true; });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final correo = userCredential.user?.email;

      if (correo != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('conductores_independientes')
            .doc(correo)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          
          final misDatos = DatosEmpresa(
            nombreConductor: data['nombre'] ?? 'Chofer',
            nombreEmpresa: data['empresa_nombre'] ?? 'PARTICULAR',
            rutEmpresa: data['rut_empresa'] ?? '',
            celular: data['celular_contacto'] ?? '',
            correo: correo,
            patente: data['patente'] ?? '',
            sitioWeb: data['sitio_web'] ?? '',
            rutaLogo: data['ruta_logo'],
          );

          // 🚀 PIEZA C: GUARDAR O BORRAR MEMORIA SEGÚN EL CHECKBOX
          SharedPreferences prefs = await SharedPreferences.getInstance();
          if (_recordarme) {
            await prefs.setString('email_guardado_persona', _emailCtrl.text.trim());
            await prefs.setString('password_guardado_persona', _passwordCtrl.text.trim());
            await prefs.setBool('recordarme_activado_persona', true);
          } else {
            await prefs.remove('email_guardado_persona');
            await prefs.remove('password_guardado_persona');
            await prefs.setBool('recordarme_activado_persona', false);
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PantallaInicio(datosEmpresa: misDatos)),
          );
        } else {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _mostrarAlerta("Este correo no pertenece a un Conductor Particular.");
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error al iniciar sesión.";
      if (e.code == 'user-not-found') mensaje = "Usuario no encontrado.";
      if (e.code == 'wrong-password') mensaje = "Contraseña incorrecta.";
      _mostrarAlerta(mensaje);
    } catch (e) {
      _mostrarAlerta("Error al cargar datos: $e");
    } finally {
      if (mounted) {
        setState(() { _cargando = false; });
      }
    }
  }

  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
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
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
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
                  const Text("Ingreso Conductor", style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      const Icon(Icons.person_pin, size: 80, color: Color(0xFF0D47A1)),
                      const SizedBox(height: 24),

                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Correo Electrónico",
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0D47A1), size: 22),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _ocultarPassword,
                        decoration: InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0D47A1), size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16), // Espacio ajustado

                      // 🚀 PIEZA B: CHECKBOX RECUÉRDAME
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
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _iniciarSesionIndependiente,
                              child: const Text("INICIAR SESIÓN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                      
                      const SizedBox(height: 20),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PantallaRegistro()),
                          );
                        },
                        child: const Text(
                          "¿No tienes cuenta? Regístrate en NovaRecibos aquí",
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