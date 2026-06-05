// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_admin.dart'; 

class PantallaRegistroEmpresa extends StatefulWidget {
  const PantallaRegistroEmpresa({super.key});

  @override
  State<PantallaRegistroEmpresa> createState() => _PantallaRegistroEmpresaState();
}

class _PantallaRegistroEmpresaState extends State<PantallaRegistroEmpresa> {
  final _adminController = TextEditingController();
  final _empresaController = TextEditingController();
  final _rutController = TextEditingController();
  final _celularController = TextEditingController();
  final _webController = TextEditingController(); 
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _rutaLogo;
  bool _cargando = false;
  bool _ocultarPassword = true;

  Future<void> _seleccionarLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40); 
    if (imagen != null) {
      setState(() { _rutaLogo = imagen.path; });
    }
  }

  void _registrarEmpresa() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty || _empresaController.text.trim().isEmpty) {
      _mostrarAlerta("Por favor, rellena los campos obligatorios.");
      return;
    }

    if (_celularController.text.trim().length != 9) {
      _mostrarAlerta("El celular debe tener exactamente 9 dígitos.");
      return;
    }

    setState(() { _cargando = true; });

    try {
      final String correoLimpio = _emailController.text.trim();

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: correoLimpio,
        password: _passwordController.text.trim(),
      );

      String? logoComoTexto;
      if (_rutaLogo != null) {
        try {
          File archivoImagen = File(_rutaLogo!);
          List<int> bytesImagen = await archivoImagen.readAsBytes();
          logoComoTexto = base64Encode(bytesImagen); 
        } catch (e) {
          print("Error convirtiendo logo: $e");
        }
      }

      await FirebaseFirestore.instance.collection('empresas').doc(correoLimpio).set({
        'admin_nombre': _adminController.text.trim(), 
        'empresa_nombre': _empresaController.text.trim(),
        'rut_empresa': _rutController.text.trim(),
        'celular_contacto': _celularController.text.trim(),
        'sitio_web': _webController.text.trim().toUpperCase(), // 🚀 Guardado en MAYÚSCULAS
        'correo_admin': correoLimpio,
        'rol': 'admin',
        'ruta_logo': logoComoTexto, 
      });

      if (!mounted) return;
      _mostrarAlerta("¡Empresa registrada con éxito!");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PantallaAdminDashboard()),
        (route) => false, 
      );

    } on FirebaseAuthException catch (e) {
      _mostrarAlerta(e.message ?? "Error al registrar.");
    } catch (e) {
      _mostrarAlerta("Error inesperado: $e");
    } finally {
      if (mounted) setState(() { _cargando = false; });
    }
  }

  void _mostrarAlerta(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Widget _buildField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    bool esNumero = false,
    bool todoMayuscula = false,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: esNumero ? TextInputType.number : TextInputType.text,
      // 🚀 AUTO-MAYÚSCULA INTELIGENTE: Letras capitales para nombres, Mayúscula total para Web
      textCapitalization: esNumero ? TextCapitalization.none : (todoMayuscula ? TextCapitalization.characters : TextCapitalization.words), 
      inputFormatters: formatters ?? (esNumero ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)] : []),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0D47A1), size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
        ),
      ),
    );
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
                  const Text("NovaRecibos", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text("¡Unete a la plataforma de NovaRecibos!", style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                      const Text("Crear Cuenta De Administrador de Flota", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: _seleccionarLogo,
                        child: Column(
                          children: [
Container(
                                  width: 110,
                                  height: 110,
                                  // 🚀 Añadimos un padding (margen interno) para que el logo respire y no toque la línea azul
                                  padding: const EdgeInsets.all(6), 
                                  decoration: BoxDecoration(
                                    color: Colors.white, // Fondo siempre blanco por si el logo es transparente
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0D47A1), width: 2),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: _rutaLogo != null
                                      ? Image.file(
                                          File(_rutaLogo!), 
                                          // 🚀 LA CLAVE: Ajuste automático universal
                                          fit: BoxFit.contain, 
                                        )
                                      : const Icon(Icons.add_photo_alternate_outlined, size: 50, color: Color(0xFF0D47A1)),
                                ),
                            const SizedBox(height: 8),
                            const Text("Logo de la Empresa", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildField(label: "Nombre del Administrador", controller: _adminController, icon: Icons.person_outline),
                      const SizedBox(height: 20),
                      
                      _buildField(label: "Nombre de la Empresa", controller: _empresaController, icon: Icons.business_outlined),
                      const SizedBox(height: 20),
                      
                      _buildField(
                        label: "RUT Empresa", 
                        controller: _rutController, 
                        icon: Icons.badge_outlined,
                        formatters: [RutEmpresaFormatter(), LengthLimitingTextInputFormatter(12)],
                      ),
                      const SizedBox(height: 20),
                      
                      // 🚀 CELULAR RESTRINGIDO SOLO A NÚMEROS Y MÁXIMO 9
                      _buildField(
                        label: "Celular de Contacto", 
                        controller: _celularController, 
                        icon: Icons.phone_android_outlined, 
                        esNumero: true, 
                      ),
                      const SizedBox(height: 20),

                      _buildField(label: "Sitio Web (Opcional)", controller: _webController, icon: Icons.language_outlined, todoMayuscula: true), 
                      const SizedBox(height: 20),
                      
                      _buildField(label: "Correo Electrónico Admin", controller: _emailController, icon: Icons.email_outlined),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _passwordController,
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
                      const SizedBox(height: 36),

                      _cargando
                        ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _registrarEmpresa,
                            child: const Text("REGISTRAR MI EMPRESA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

class RutEmpresaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^\dkK]'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    String dv = text.substring(text.length - 1);
    String body = text.substring(0, text.length - 1);
    String formattedBody = '';
    int count = 0;
    for (int i = body.length - 1; i >= 0; i--) {
      formattedBody = body[i] + formattedBody;
      count++;
      if (count == 3 && i != 0) {
        formattedBody = '.$formattedBody';
        count = 0;
      }
    }
    String finalTxt = body.isEmpty ? dv : '$formattedBody-$dv';
    return TextEditingValue(
      text: finalTxt,
      selection: TextSelection.collapsed(offset: finalTxt.length),
    );
  }
}