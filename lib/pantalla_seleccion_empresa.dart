// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'pantalla_login_conductor_empresa.dart'; 
import 'pantalla_login_admin.dart';

class PantallaSeleccionEmpresa extends StatelessWidget {
  const PantallaSeleccionEmpresa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)], 
                begin: Alignment.topCenter, 
                end: Alignment.bottomCenter,
              ),
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
                  "NovaRecibos", 
                  style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Acceso administradores y conductores de flota", 
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  
                  _buildMenuCard(
                    context: context,
                    titulo: "Acceso Administrador",
                    descripcion: "Control de flotas, finanzas, ranking y registro de nuevos choferes.",
                    icono: Icons.person_pin_rounded,
                    destino: PantallaLoginAdmin(), // 🚀 CORREGIDO: Removido 'const' para que compile en Web
                  ),
                  
                  const SizedBox(height: 24),

                  _buildMenuCard(
                    context: context,
                    titulo: "Acceso Conductor",
                    descripcion: "Emisión corporativa de recibos vinculados directamente a tu flota.",
                    icono: Icons.directions_car_filled_rounded,
                    destino: const PantallaLoginConductorEmpresa(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context, 
    required String titulo, 
    required String descripcion, 
    required IconData icono, 
    required Widget destino,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destino)),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), 
                blurRadius: 16, 
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD), 
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: const Color(0xFF0D47A1), size: 30),
              ),
              const SizedBox(width: 18),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo, 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descripcion, 
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3), 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}