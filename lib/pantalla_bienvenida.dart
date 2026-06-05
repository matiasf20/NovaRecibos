// ignore_for_file: prefer_const_constructors, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 IMPORTACIÓN DE MEMORIA
import 'pantalla_login_persona.dart'; 
import 'pantalla_seleccion_empresa.dart'; 
import 'dart:io'; // 🚀 Para cerrar la app en iOS
import 'package:flutter/services.dart'; // 🚀 Para cerrar la app en Android

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  bool _mostrarSplash = true;

  @override
  void initState() {
    super.initState();
    _relojDeCarga();
    _verificarTerminos(); // 🚀 EJECUTA LOS TÉRMINOS AL ENTRAR
  }

  void _relojDeCarga() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (mounted) {
      setState(() {
        _mostrarSplash = false;
      });
    }
  }

  
// 🚀 LÓGICA DE TÉRMINOS Y CONDICIONES (Con validación de lectura)
  Future<void> _verificarTerminos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool aceptados = prefs.getBool('terminos_aceptados') ?? false;

    if (!aceptados) {
      await Future.delayed(const Duration(milliseconds: 3000)); 
      
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (context) {
          // 🚀 Variables de control para esta ventana
          bool botonesActivados = false;
          final ScrollController scrollController = ScrollController();

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              
              // 🚀 Escuchador que detecta cuándo llegas al final del texto
              scrollController.addListener(() {
                if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 10) {
                  if (!botonesActivados) {
                    setStateDialog(() {
                      botonesActivados = true;
                    });
                  }
                }
              });

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.gavel, color: Color(0xFF0D47A1)),
                    SizedBox(width: 10),
                    Expanded(child: Text("Términos y Privacidad", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 18))),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400, 
                  child: SingleChildScrollView(
                    controller: scrollController, // 🚀 Conectamos el detector de lectura aquí
                    child: const Text(
                      "TÉRMINOS DE SERVICIO Y POLÍTICA DE PRIVACIDAD\n\n"
                      "Última actualización: Junio 2026\n\n"
                      "1. ACEPTACIÓN DE LOS TÉRMINOS\n"
                      "Al acceder y utilizar NovaRecibos, usted acepta estar sujeto a estos Términos de Servicio y a nuestra Política de Privacidad. Si no está de acuerdo, le rogamos no utilizar la plataforma.\n\n"
                      "2. USO DE LA PLATAFORMA Y DATOS\n"
                      "NovaRecibos es una herramienta para la emisión de comprobantes digitales y gestión financiera. El usuario es el único responsable de la veracidad de los datos fiscales, montos, RUT y nombres ingresados. NovaRecibos no actúa como entidad contable fiscal, sino como facilitador tecnológico.\n\n"
                      "3. ALMACENAMIENTO EN LA NUBE Y PRIVACIDAD\n"
                      "Toda la información ingresada (perfiles de empresa, conductores y registros de recibos) es almacenada de forma segura en servidores en la nube (Firebase). Nos comprometemos a no vender, compartir ni comercializar sus datos financieros o los de sus clientes con terceros.\n\n"
                      "4. PERMISOS DEL DISPOSITIVO\n"
                      "Para el correcto funcionamiento, la aplicación solicitará acceso a:\n"
                      "• Galería de imágenes: Exclusivamente para cargar el logotipo de su empresa.\n"
                      "• Almacenamiento/Documentos: Para generar y guardar los comprobantes en PDF y exportar los reportes en Excel (CSV).\n\n"
                      "5. LIMITACIÓN DE RESPONSABILIDAD\n"
                      "NovaRecibos no se hace responsable por la pérdida de datos derivada de un mal uso de las credenciales (correo/contraseña) por parte de los administradores de flota, conductores de flota o conductores independientes/particulares. Recomendamos mantener sus accesos de forma confidencial.\n\n"
                      "Al presionar 'Aceptar', usted confirma haber leído, entendido y aceptado estas condiciones para operar en nuestra plataforma. Por favor, deslice hasta el final para habilitar los botones.",
                      style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  // 🚀 BOTÓN RECHAZAR (ROJO)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: botonesActivados ? Colors.red : Colors.grey.shade300,
                      foregroundColor: botonesActivados ? Colors.white : Colors.grey.shade600,
                      elevation: botonesActivados ? 2 : 0,
                    ),
                    onPressed: botonesActivados ? () {
                      // Cierra la aplicación dependiendo del sistema operativo
                      if (Platform.isAndroid) {
                        SystemNavigator.pop();
                      } else if (Platform.isIOS) {
                        exit(0);
                      }
                    } : null, // null desactiva el botón
                    child: const Text("RECHAZAR Y SALIR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  
                  // 🚀 BOTÓN ACEPTAR (AZUL)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: botonesActivados ? const Color(0xFF0D47A1) : Colors.grey.shade300,
                      foregroundColor: botonesActivados ? Colors.white : Colors.grey.shade600,
                      elevation: botonesActivados ? 2 : 0,
                    ),
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
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle, 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_car, size: 50, color: Color(0xFF0D47A1)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarSplash) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D47A1), 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dibujarLogoReal(tamano: 180), 
              const SizedBox(height: 32), 
              const Text(
                "¡Bienvenido a NovaRecibos!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const CircularProgressIndicator(
                color: Colors.white70,
              ), 
            ],
          ), 
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D47A1), 
              Color(0xFF1565C0), 
              Colors.white       
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0], 
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _dibujarLogoReal(tamano: 160), 
                  const SizedBox(height: 36),

                  const Text(
                    "NovaRecibos", 
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Gestión inteligente, particular o empresa, ¡tú eliges cómo usarlo!", 
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 52),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaLoginPersona()));
                    },
                    icon: const Icon(Icons.person_outline, size: 24),
                    label: const Text("ACCESO PERSONA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaSeleccionEmpresa()));
                    },
                    icon: const Icon(Icons.business, size: 24),
                    label: const Text("ACCESO EMPRESA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}