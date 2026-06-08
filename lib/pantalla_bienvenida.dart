// ignore_for_file: prefer_const_constructors, use_build_context_synchronously
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'pantalla_login_persona.dart'; 
import 'pantalla_seleccion_empresa.dart'; 
import 'dart:io' as io; 
import 'package:flutter/services.dart'; 
import 'package:universal_html/html.dart' as html;

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  bool _mostrarSplash = true;
  bool _mostrarBotonInstalarIOS = false;

  @override
  void initState() {
    super.initState();
    _iniciarSecuenciaDeCarga();
  }

  Future<void> _iniciarSecuenciaDeCarga() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    setState(() { _mostrarSplash = false; });
    
    await _verificarTerminos();
    _evaluarBotonInstalacionIOS();
  }

  void _evaluarBotonInstalacionIOS() {
    if (kIsWeb) {
      final ua = html.window.navigator.userAgent.toLowerCase();
      bool esIOS = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
      
      // Verifica si NO está abierta como PWA instalada
      final esPWA = html.window.matchMedia('(display-mode: standalone)').matches || 
                   (html.window.navigator as dynamic).standalone == true;

      if (esIOS && !esPWA) {
        setState(() {
          _mostrarBotonInstalarIOS = true;
        });
        // Intenta abrir el modal automático de cortesía
        _mostrarInstalacionIOSCorporativa();
      }
    }
  }

  void _mostrarInstalacionIOSCorporativa() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          child: Container(
            width: 320,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(color: Color(0xFF0D47A1), borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
                  child: const Column(
                    children: [
                      Icon(Icons.apple, color: Colors.white, size: 48),
                      SizedBox(height: 12),
                      Text("Instalar NovaRecibos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text("Para una experiencia nativa, rápida y sin barras de navegación, agrega la plataforma a tu iPhone:", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.ios_share, color: Color(0xFF0D47A1), size: 20)),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("1. Toca el ícono de Compartir en la barra inferior de Safari.", style: TextStyle(fontSize: 14, color: Colors.black87))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.add_box_outlined, color: Color(0xFF0D47A1), size: 20)),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("2. Selecciona la opción 'Agregar a inicio'.", style: TextStyle(fontSize: 14, color: Colors.black87))),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _verificarTerminos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool aceptados = prefs.getBool('terminos_aceptados') ?? false;

    if (!aceptados) {
      await Future.delayed(const Duration(milliseconds: 500)); 
      if (!mounted) return;
      
      await showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (context) {
          bool botonesActivados = false;
          final ScrollController scrollController = ScrollController();
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              scrollController.addListener(() {
                if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 10) {
                  if (!botonesActivados) setStateDialog(() => botonesActivados = true);
                }
              });
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(children: [Icon(Icons.gavel, color: Color(0xFF0D47A1)), SizedBox(width: 10), Expanded(child: Text("Términos y Privacidad", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 18)))]),
                content: SizedBox(
                  width: double.maxFinite, height: 400, 
                  child: SingleChildScrollView(
                    controller: scrollController, 
                    child: const Text(
                      "TÉRMINOS DE SERVICIO Y POLÍTICA DE PRIVACIDAD\n\n1. ACEPTACIÓN DE LOS TÉRMINOS\nAl acceder y utilizar NovaRecibos, usted acepta estar sujeto a estos Términos de Servicio y a nuestra Política de Privacidad.\n\n2. USO DE LA PLATAFORMA Y DATOS\nNovaRecibos es una herramienta para la emisión de comprobantes digitales y gestión financiera. El usuario es el único responsable de la veracidad de los datos fiscales.\n\n3. ALMACENAMIENTO EN LA NUBE Y PRIVACIDAD\nToda la información ingresada es almacenada de forma segura en servidores en la nube (Firebase). Nos comprometemos a no vender, compartir ni comercializar sus datos financieros.\n\n4. PERMISOS DEL DISPOSITIVO\nPara el correcto funcionamiento, la aplicación solicitará acceso a:\n• Galería de imágenes: Exclusivamente para cargar el logotipo de su empresa.\n• Almacenamiento/Documentos: Para generar y guardar los comprobantes en PDF y exportar los reportes en Excel (CSV).\n\n5. LIMITACIÓN DE RESPONSABILIDAD\nNovaRecibos no se hace responsable por la pérdida de datos derivada de un mal uso de las credenciales. Recomendamos mantener sus accesos de forma confidencial.\n\nAl presionar 'Aceptar', usted confirma haber leído, entendido y aceptado estas condiciones para operar en nuestra plataforma. Por favor, deslice hasta el final para habilitar los botones.",
                      style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4), textAlign: TextAlign.justify,
                    ),
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: botonesActivados ? Colors.red : Colors.grey.shade300, foregroundColor: botonesActivados ? Colors.white : Colors.grey.shade600),
                    onPressed: botonesActivados ? () {
                      if (kIsWeb) Navigator.pop(context);
                      else {
                        if (defaultTargetPlatform == TargetPlatform.android) SystemNavigator.pop();
                        else if (defaultTargetPlatform == TargetPlatform.iOS) io.exit(0);
                      }
                    } : null,
                    child: const Text("RECHAZAR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: botonesActivados ? const Color(0xFF0D47A1) : Colors.grey.shade300, foregroundColor: botonesActivados ? Colors.white : Colors.grey.shade600),
                    onPressed: botonesActivados ? () async {
                      await prefs.setBool('terminos_aceptados', true);
                      if (context.mounted) Navigator.pop(context); 
                    } : null,
                    child: const Text("ACEPTAR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              );
            }
          );
        },
      );
    }
  }

  Widget _dibujarLogoReal({required double tamano}) {
    return Container(
      width: tamano, height: tamano,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8))]),
      child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_car, size: 50, color: Color(0xFF0D47A1)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarSplash) {
      return Scaffold(backgroundColor: const Color(0xFF0D47A1), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [_dibujarLogoReal(tamano: 180), const SizedBox(height: 32), const Text("¡Bienvenido a NovaRecibos!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)), const SizedBox(height: 8), const CircularProgressIndicator(color: Colors.white70)])));
    }
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.0, 0.5, 1.0])),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _dibujarLogoReal(tamano: 160), 
                      const SizedBox(height: 36),
                      const Text("NovaRecibos", style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      const Text("Gestión inteligente, particular o empresa, ¡tú eliges cómo usarlo!", style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                      const SizedBox(height: 52),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: Colors.white, foregroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 3),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaLoginPersona())),
                        icon: const Icon(Icons.person_outline, size: 24), label: const Text("ACCESO PERSONA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: Colors.white, foregroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 3),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaSeleccionEmpresa())),
                        icon: const Icon(Icons.business, size: 24), label: const Text("ACCESO EMPRESA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              // 🚀 BOTÓN FLOTANTE DE EMERGENCIA PARA IPHONE (Estilo App Store)
              if (_mostrarBotonInstalarIOS)
                Positioned(
                  bottom: 20,
                  left: 32,
                  right: 32,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _mostrarInstalacionIOSCorporativa,
                    icon: const Icon(Icons.phone_iphone, size: 22),
                    label: const Text("INSTALAR APLICACIÓN 📱", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}