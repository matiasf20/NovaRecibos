// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'pantalla_conductor_independiente.dart'; 
import 'pantalla_registro_persona.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

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
  bool _recordarme = false;

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _mostrarInstruccionesInstalacionIOS();
      }
    });
  }

  void _mostrarInstruccionesInstalacionIOS() {
    if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final esPWAInstalada = html.window.matchMedia('(display-mode: standalone)').matches ||
                            (html.window.navigator as dynamic).standalone == true;

      if (esPWAInstalada) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "¡Instala NovaRecibos!",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Para una experiencia nativa y más rápida, instala la app en tu iPhone:",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text("1. Toca el ícono de Compartir 📤 en la barra inferior de Safari."),
                SizedBox(height: 10),
                Text("2. Selecciona 'Agregar a inicio' 📱."),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Entendido"),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _cargarCredencialesGuardadas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordarme = prefs.getBool('recordarme_activado_persona') ?? false;
      if (_recordarme) {
        // Al cargar, aseguramos que siempre se mantenga limpio y en minúsculas
        _emailCtrl.text = (prefs.getString('email_guardado_persona') ?? '').trim().toLowerCase();
        _passwordCtrl.text = ''; // 🚀 NUNCA carga la contraseña por seguridad corporativa
      }
    });
  }

  Future<void> _recuperarContrasena() async {
    // 🚀 BLINDAJE: Forzamos minúsculas al recuperar también
    final correo = _emailCtrl.text.trim().toLowerCase(); 
    if (correo.isEmpty || !correo.contains('@')) {
      _mostrarAlerta("Ingresa tu correo válido en la casilla de arriba para restablecer la contraseña.");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enlace enviado. Revisa tu correo."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) _mostrarAlerta("Error: No se pudo enviar el correo de recuperación.");
    }
  }

  Future<void> _iniciarSesionIndependiente() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _mostrarAlerta("Correo y contraseña son obligatorios.");
      return;
    }

    setState(() { _cargando = true; });

    try {
      // 🚀 LA REGLA DE ORO: Aplanamos el correo tipeado inmediatamente a minúsculas puras
      final String correoLimpio = _emailCtrl.text.trim().toLowerCase();

      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correoLimpio, // Enviamos el correo estandarizado a Auth
        password: _passwordCtrl.text.trim(),
      );

      final String? correoAuth = userCredential.user?.email?.trim().toLowerCase();

      // Red de seguridad cruzada por si quedan cuentas históricas creadas con mayúsculas en la nube
      List<String> variaciones = {
        correoLimpio,
        _emailCtrl.text.trim(),
        if (correoAuth != null) correoAuth,
      }.toList();

      bool encontrado = false;
      Map<String, dynamic>? data;

      // Buscar directamente por el ID óptimo (minúsculas)
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('conductores_independientes').doc(correoLimpio).get();
      if (doc.exists) {
        data = doc.data() as Map<String, dynamic>;
        encontrado = true;
      } else {
        // Búsqueda alternativa por ID de documento histórico
        for (String variante in variaciones) {
          DocumentSnapshot docVar = await FirebaseFirestore.instance.collection('conductores_independientes').doc(variante).get();
          if (docVar.exists) {
            data = docVar.data() as Map<String, dynamic>;
            encontrado = true;
            break;
          }
        }
      }

      // Si no se halló por ID, escaneamos de respaldo por campos internos 'correo' o 'email'
      if (!encontrado) {
        QuerySnapshot q = await FirebaseFirestore.instance
            .collection('conductores_independientes')
            .where('correo', whereIn: variaciones)
            .get();

        if (q.docs.isEmpty) {
          q = await FirebaseFirestore.instance
              .collection('conductores_independientes')
              .where('email', whereIn: variaciones)
              .get();
        }

        if (q.docs.isNotEmpty) {
          data = q.docs.first.data() as Map<String, dynamic>;
          encontrado = true;
        }
      }

      if (encontrado && data != null) {
        final misDatos = DatosEmpresa(
          nombreConductor: data['nombre']?.toString() ?? 'Chofer',
          nombreEmpresa: data['empresa_nombre']?.toString() ?? 'PARTICULAR',
          rutEmpresa: data['rut_empresa']?.toString() ?? '',
          celular: data['celular_contacto']?.toString() ?? '',
          correo: correoLimpio, // 🚀 Mandamos la minúscula limpia obligatoria para que filtre los recibos
          patente: data['patente']?.toString() ?? '',
          sitioWeb: data['sitio_web']?.toString() ?? '',
          rutaLogo: data['ruta_logo']?.toString(),
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        if (_recordarme) {
          await prefs.setString('email_guardado_persona', correoLimpio); // Guardamos la versión estandarizada
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
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error al iniciar sesión.";
      if (e.code == 'user-not-found') mensaje = "Usuario no encontrado.";
      if (e.code == 'wrong-password') mensaje = "Contraseña incorrecta.";
      if (e.code == 'invalid-credential') mensaje = "Credenciales inválidas.";
      _mostrarAlerta(mensaje);
    } catch (e) {
      _mostrarAlerta("Verifica tus credenciales y conexión.");
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
                  const Text("¡Bienvenido a\nNovaRecibos!", textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _recordarme,
                            activeColor: const Color(0xFF0D47A1),
                            onChanged: (bool? valor) {
                              setState(() { _recordarme = valor ?? false; });
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
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _iniciarSesionIndependiente,
                              child: const Text("INICIAR SESIÓN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _recuperarContrasena,
                        child: const Text("¿Olvidaste tu contraseña? Restablécela aquí", style: TextStyle(color: Color(0xFF0D47A1))),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRegistro()));
                        },
                        child: const Text("¿No tienes cuenta? Regístrate en NovaRecibos aquí", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
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