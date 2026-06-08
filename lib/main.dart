// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 
import 'pantalla_bienvenida.dart';
import 'pantalla_conductor_independiente.dart';
import 'pantalla_admin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NovaRecibos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        useMaterial3: true,
      ),
      home: const EnrutadorSeguridadAutenticacion(),
    );
  }
}

class EnrutadorSeguridadAutenticacion extends StatefulWidget {
  const EnrutadorSeguridadAutenticacion({super.key});

  @override
  State<EnrutadorSeguridadAutenticacion> createState() => _EnrutadorSeguridadAutenticacionState();
}

class _EnrutadorSeguridadAutenticacionState extends State<EnrutadorSeguridadAutenticacion> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)))));
        }

        // Si no hay token de sesión guardado en el teléfono, va directo a la bienvenida
        if (!snapshot.hasData || snapshot.data == null) {
          return const PantallaBienvenida();
        }

        // 🚀 BLINDAJE ABSOLUTO: Capturamos el correo del inicio automático y lo aplanamos a minúsculas
        final String emailUsuario = snapshot.data!.email ?? "";
        final String emailLower = emailUsuario.trim().toLowerCase();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('conductores_independientes').doc(emailLower).get(),
          builder: (context, snapshotIndep) {
            if (snapshotIndep.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            bool esIndependiente = snapshotIndep.hasData && snapshotIndep.data!.exists;
            Map<String, dynamic>? dataIndep = esIndependiente ? snapshotIndep.data!.data() as Map<String, dynamic> : null;

            if (esIndependiente && dataIndep != null) {
              return PantallaInicio(
                datosEmpresa: DatosEmpresa(
                  nombreConductor: dataIndep['nombre']?.toString() ?? 'Chofer',
                  nombreEmpresa: dataIndep['empresa_nombre']?.toString() ?? 'PARTICULAR',
                  rutEmpresa: dataIndep['rut_empresa']?.toString() ?? '',
                  celular: dataIndep['celular_contacto']?.toString() ?? '',
                  correo: emailLower, // Enviamos el correo limpio para que filtre los recibos sin fallar
                  patente: dataIndep['patente']?.toString() ?? '',
                  sitioWeb: dataIndep['sitio_web']?.toString() ?? '',
                  rutaLogo: dataIndep['ruta_logo']?.toString(),
                ),
              );
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('empresas').doc(emailLower).get(),
              builder: (context, snapshotEmpresa) {
                if (snapshotEmpresa.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                if (snapshotEmpresa.hasData && snapshotEmpresa.data!.exists) {
                  return const PantallaAdminDashboard();
                }

                // 🚀 RED DE BÚSQUEDA CRUZADA CASO-INSENSITIVO: Evita el cierre de sesión si hay variaciones de letras
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('conductores_independientes')
                      .where('correo', whereIn: [emailUsuario, emailLower, emailUsuario.toLowerCase(), emailUsuario.toUpperCase()])
                      .get(),
                  builder: (context, snapshotQueryInd) {
                    if (snapshotQueryInd.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

                    if (snapshotQueryInd.hasData && snapshotQueryInd.data!.docs.isNotEmpty) {
                      final d = snapshotQueryInd.data!.docs.first.data() as Map<String, dynamic>;
                      return PantallaInicio(
                        datosEmpresa: DatosEmpresa(
                          nombreConductor: d['nombre']?.toString() ?? 'Chofer',
                          nombreEmpresa: d['empresa_nombre']?.toString() ?? 'PARTICULAR',
                          rutEmpresa: d['rut_empresa']?.toString() ?? '',
                          celular: d['celular_contacto']?.toString() ?? '',
                          correo: emailLower, // Forzado para consistencia total en los recibos
                          patente: d['patente']?.toString() ?? '',
                          sitioWeb: d['sitio_web']?.toString() ?? '',
                          rutaLogo: d['ruta_logo']?.toString(),
                        ),
                      );
                    }

                    // Tercera capa de seguridad: Por si el campo interno en la base de datos se llama 'email'
                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('conductores_independientes')
                          .where('email', whereIn: [emailUsuario, emailLower, emailUsuario.toLowerCase()])
                          .get(),
                      builder: (context, snapshotQueryEmail) {
                        if (snapshotQueryEmail.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

                        if (snapshotQueryEmail.hasData && snapshotQueryEmail.data!.docs.isNotEmpty) {
                          final d = snapshotQueryEmail.data!.docs.first.data() as Map<String, dynamic>;
                          return PantallaInicio(
                            datosEmpresa: DatosEmpresa(
                              nombreConductor: d['nombre']?.toString() ?? 'Chofer',
                              nombreEmpresa: d['empresa_nombre']?.toString() ?? 'PARTICULAR',
                              rutEmpresa: d['rut_empresa']?.toString() ?? '',
                              celular: d['celular_contacto']?.toString() ?? '',
                              correo: emailLower,
                              patente: d['patente']?.toString() ?? '',
                              sitioWeb: d['sitio_web']?.toString() ?? '',
                              rutaLogo: d['ruta_logo']?.toString(),
                            ),
                          );
                        }

                        // Cuarta capa de seguridad: Búsqueda de respaldo para empresas administradoras
                        return FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('empresas')
                              .where('correo', whereIn: [emailUsuario, emailLower, emailUsuario.toLowerCase()])
                              .get(),
                          builder: (context, snapshotQueryEmp) {
                            if (snapshotQueryEmp.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

                            if (snapshotQueryEmp.hasData && snapshotQueryEmp.data!.docs.isNotEmpty) {
                              return const PantallaAdminDashboard();
                            }

                            // Si de verdad no existe registro alguno bajo ninguna combinación, rompe de forma limpia
                            FirebaseAuth.instance.signOut();
                            return const PantallaBienvenida();
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}