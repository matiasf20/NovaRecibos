// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_bienvenida.dart';
import 'pantalla_conductor_independiente.dart'; 

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _nombreController = TextEditingController();
  final _empresaController = TextEditingController();
  final _rutController = TextEditingController(); 
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); 
  final _patenteController = TextEditingController(); 
  final _webController = TextEditingController(); 

  Uint8List? _bytesImagenWeb; 
  bool _cargando = false;
  bool _ocultarPassword = true;

  Future<void> _seleccionarLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (imagen != null) {
      final bytes = await imagen.readAsBytes();
      setState(() { 
        _bytesImagenWeb = bytes; 
      });
    }
  }

  Future<void> _procesarRegistro() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _mostrarAlerta("Correo y contraseña son obligatorios.");
      return;
    }

    if (_celularController.text.trim().length != 9) {
      _mostrarAlerta("El celular debe tener exactamente 9 dígitos.");
      return;
    }

    setState(() { _cargando = true; });

    try {
      // 🚀 REGLA DE ORO: Forzamos que el correo siempre se guarde en minúsculas en la base de datos
      final String correoLimpio = _emailController.text.trim().toLowerCase();

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: correoLimpio, // Usamos la versión limpia
        password: _passwordController.text.trim(),
      );

      String? logoGuardar;
      if (_bytesImagenWeb != null) {
        try {
          logoGuardar = base64Encode(_bytesImagenWeb!);
        } catch (e) { print("Error al convertir imagen: $e"); }
      }

      // Guardamos en Firestore asegurándonos de que el ID del documento sea en minúsculas
      await FirebaseFirestore.instance.collection('conductores_independientes').doc(correoLimpio).set({
        'correo': correoLimpio, // 🚀 Añadimos el correo internamente para la red de búsqueda del Login
        'nombre': _nombreController.text.isEmpty ? "Conductor" : _nombreController.text.trim(),
        'empresa_nombre': _empresaController.text.isEmpty ? "PARTICULAR" : _empresaController.text.trim(),
        'rut_empresa': _rutController.text,
        'celular_contacto': _celularController.text.isEmpty ? "Sin telefono" : _celularController.text,
        'patente': _patenteController.text.isEmpty ? "Sin patente" : _patenteController.text.toUpperCase(),
        'sitio_web': _webController.text.toUpperCase(),
        'rol': 'independiente',
        'ruta_logo': logoGuardar, 
      });

      final misDatos = DatosEmpresa(
        nombreConductor: _nombreController.text.isEmpty ? "Conductor" : _nombreController.text.trim(),
        nombreEmpresa: _empresaController.text.isEmpty ? "PARTICULAR" : _empresaController.text.trim(),
        rutEmpresa: _rutController.text, 
        celular: _celularController.text.isEmpty ? "Sin telefono" : _celularController.text,
        correo: correoLimpio, // Mandamos la versión limpia al panel
        patente: _patenteController.text.isEmpty ? "Sin patente" : _patenteController.text.toUpperCase(),
        sitioWeb: _webController.text.toUpperCase(), 
        rutaLogo: logoGuardar, 
      );
      
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PantallaInicio(datosEmpresa: misDatos)));
      _mostrarAlerta("¡Cuenta creada exitosamente!");
      
    } on FirebaseAuthException catch (e) {
      _mostrarAlerta("Error de Autenticacion: ${e.message}");
    } catch (e) {
      _mostrarAlerta("Error al registrar: $e");
    } finally {
      setState(() { _cargando = false; });
    }
  }

  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool esNumero = false,
    bool todoMayuscula = false,
    List<TextInputFormatter>? formatters,
  }) {
    List<TextInputFormatter> filtrosAplicados = formatters ?? [];
    TextInputType tipoTeclado = TextInputType.text;

    if (esNumero) {
      tipoTeclado = TextInputType.number;
      filtrosAplicados = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)];
    }

    return TextField(
      controller: controller,
      keyboardType: tipoTeclado,
      inputFormatters: filtrosAplicados,
      textCapitalization: esNumero ? TextCapitalization.none : (todoMayuscula ? TextCapitalization.characters : TextCapitalization.words),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0D47A1), size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaBienvenida())),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const Text("NovaRecibos", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text("Registro de Conductor ", style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                      const Text("Crear Cuenta Conductor", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _seleccionarLogo,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  padding: const EdgeInsets.all(6), 
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0D47A1), width: 2),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: _bytesImagenWeb != null
                                      ? Image.memory(_bytesImagenWeb!, fit: BoxFit.contain)
                                      : const Icon(Icons.add_photo_alternate_outlined, size: 50, color: Color(0xFF0D47A1)),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle),
                                    child: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 16),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text("LOGO PERSONAL", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)), 
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildField(label: "Tu Nombre (Conductor)", controller: _nombreController, icon: Icons.person_outline),
                      const SizedBox(height: 20),
                      _buildField(label: "Nombre de tu Empresa / Fantasia", controller: _empresaController, icon: Icons.business_outlined),
                      const SizedBox(height: 20),
                      _buildField(
                        label: "RUT Personal / Empresa",  
                        controller: _rutController, 
                        icon: Icons.badge_outlined, 
                        formatters: [RutFormatter(), LengthLimitingTextInputFormatter(12)]
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildField(label: "Celular", controller: _celularController, icon: Icons.phone_android_outlined, esNumero: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildField(label: "Patente", controller: _patenteController, icon: Icons.branding_watermark_outlined, todoMayuscula: true, formatters: [FormateadorPatenteEstricto()])),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildField(label: "Correo Electronico", controller: _emailController, icon: Icons.email_outlined),
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
                      const SizedBox(height: 20),
                      _buildField(label: "Sitio Web (Opcional)", controller: _webController, icon: Icons.language_outlined, todoMayuscula: true),
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
                            onPressed: _procesarRegistro,
                            child: const Text("REGISTRAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^\dkK]'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    String dv = text.substring(text.length - 1).toUpperCase();
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
    return TextEditingValue(text: finalTxt, selection: TextSelection.collapsed(offset: finalTxt.length));
  }
}

class FormateadorPatenteEstricto extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (text.length > 6) text = text.substring(0, 6);
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 4) formatted += '-';
      formatted += text[i];
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}