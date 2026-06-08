// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; 
import 'pantalla_bienvenida.dart';

class PantallaConductorEmpresa extends StatefulWidget {
  const PantallaConductorEmpresa({super.key});

  @override
  State<PantallaConductorEmpresa> createState() => _PantallaConductorEmpresaState();
}

class _PantallaConductorEmpresaState extends State<PantallaConductorEmpresa> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final _empresaPasajeroCtrl = TextEditingController();
  final _pasajeroCtrl = TextEditingController();
  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController(); 

  DateTime _fechaSeleccionada = DateTime.now(); 
  bool _convenioEmpresa = false;
  bool _mostrarLogosPago = true; 

  String _nombreConductor = "Chofer";
  String _patente = "S/P";
  String _empresaCorreo = "";
  String _nombreEmpresa = "Empresa de Transporte";
  String _rutEmpresa = "";
  String _celularEmpresa = "";
  String _sitioWeb = ""; 
  String? _logoUrl; 
  
  bool _cargandoDatos = true;
  bool _generandoRecibo = false;
  int _numeroCorrelativoActual = 1;

  static const String _svgWhatsapp = '''<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#25D366" d="M12.031 0C5.383 0 0 5.383 0 12.031c0 2.124.551 4.195 1.597 6.012L.038 24l6.113-1.603a11.96 11.96 0 0 0 5.88 1.535h.005c6.648 0 12.031-5.384 12.031-12.032C24.067 5.383 18.679 0 12.031 0zm0 21.933h-.004a9.922 9.922 0 0 1-5.062-1.385l-.363-.215-3.766.987.998-3.668-.236-.376a9.92 9.92 0 0 1-1.517-5.313c0-5.502 4.478-9.98 9.98-9.98 5.502 0 9.98 4.478 9.98 9.98 0 5.502-4.478 9.98-9.98 9.98z"/><path fill="#FFF" d="M17.505 14.453c-.301-.151-1.777-.878-2.052-.979-.276-.1-.477-.151-.678.151-.201.301-.778.979-.953 1.18-.175.201-.351.226-.652.075-.301-.151-1.27-.468-2.42-1.493-.895-.798-1.501-1.784-1.677-2.085-.175-.301-.019-.464.132-.614.135-.135.301-.351.452-.527.151-.175.201-.351.301-.502.1-.201.05-.376-.025-.527-.075-.151-.678-1.631-.928-2.233-.245-.59-.493-.51-.678-.519-.175-.01-.376-.01-.577-.01-.201 0-.527.075-.803.376-.276.301-1.053 1.029-1.053 2.509s1.078 2.91 1.229 3.111c.151.201 2.124 3.242 5.143 4.545.719.31 1.28.495 1.718.633.723.23 1.382.197 1.901.12.583-.087 1.777-.726 2.028-1.43.251-.703.251-1.305.175-1.43-.075-.125-.276-.2-.577-.351z"/></svg>''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada); 
    _cargarDatosDesdeFirestore();
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1), 
            ),
          ),
          child: child!,
        );
      },
    );
    if (seleccion != null && seleccion != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = seleccion;
        _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
      });
    }
  }

  Future<void> _cargarDatosDesdeFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot docChofer = await FirebaseFirestore.instance.collection('conductores_flota').doc(user.email).get();
        
        if (docChofer.exists) {
          final dataChofer = docChofer.data() as Map<String, dynamic>;
          _nombreConductor = dataChofer['nombre'] ?? 'Chofer';
          _patente = dataChofer['patente'] ?? 'S/P';
          _empresaCorreo = dataChofer['empresa_correo'] ?? '';

          if (_empresaCorreo.isNotEmpty) {
            Map<String, dynamic>? dataEmpresa;

            DocumentSnapshot docEmpresa = await FirebaseFirestore.instance.collection('empresas').doc(_empresaCorreo).get();
            if (!docEmpresa.exists) {
              QuerySnapshot q = await FirebaseFirestore.instance.collection('empresas').where('correo_admin', isEqualTo: _empresaCorreo).get();
              if (q.docs.isNotEmpty) docEmpresa = q.docs.first;
            }

            if (docEmpresa.exists) {
              dataEmpresa = docEmpresa.data() as Map<String, dynamic>;
            } else {
              DocumentSnapshot docAdmin = await FirebaseFirestore.instance.collection('administradores').doc(_empresaCorreo).get();
              if (docAdmin.exists) {
                dataEmpresa = docAdmin.data() as Map<String, dynamic>;
              }
            }

            if (dataEmpresa != null) {
              _nombreEmpresa = dataEmpresa['empresa_nombre'] ?? dataEmpresa['empresa'] ?? dataEmpresa['nombre'] ?? _nombreEmpresa;
              _rutEmpresa = dataEmpresa['rut_empresa'] ?? dataEmpresa['rut'] ?? "";
              _celularEmpresa = dataEmpresa['celular_contacto'] ?? dataEmpresa['celular'] ?? "";
              _sitioWeb = dataEmpresa['sitio_web'] ?? dataEmpresa['web'] ?? ""; 
              _logoUrl = dataEmpresa['ruta_logo'] ?? dataEmpresa['logo_url'] ?? dataEmpresa['url_logo'] ?? dataEmpresa['logo'];
            }

            QuerySnapshot qs = await FirebaseFirestore.instance
                .collection('recibos')
                .where('empresa_correo', isEqualTo: _empresaCorreo)
                .get();

            if (qs.docs.isNotEmpty) {
              int maxNumero = 0;
              for (var doc in qs.docs) {
                final dataRecibo = doc.data() as Map<String, dynamic>;
                int num = dataRecibo['numero'] ?? 0;
                if (num > maxNumero) { maxNumero = num; }
              }
              _numeroCorrelativoActual = maxNumero + 1;
            } else {
              _numeroCorrelativoActual = 1;
            }
          }
        }
      }
      setState(() { _cargandoDatos = false; });
    } catch (e) {
      setState(() { _cargandoDatos = false; });
    }
  }

  void _cerrarSesion() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Cerrar Sesión", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
          content: const Text("¿Seguro que deseas salir de tu cuenta corporativa?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("VOLVER")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogContext); 
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const PantallaBienvenida()),
                  (route) => false,
                );
              }, 
              child: const Text("SALIR"),
            ),
          ],
        );
      },
    );
  }

  pw.Widget _construirCajitaPDF(String texto) {
    return pw.Container(
      width: 22, height: 16,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      alignment: pw.Alignment.center,
      child: pw.Text(texto, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _construirLineaPDF(String etiqueta, String valor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text("$etiqueta ", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1, left: 4), 
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
            child: pw.Text(valor, style: const pw.TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _generarPDFCorporativo(Map<String, dynamic> data) async {
    try {
      pw.MemoryImage? imagenLogo;

      if (_logoUrl != null && _logoUrl!.isNotEmpty) {
        try {
          if (_logoUrl!.startsWith('http://') || _logoUrl!.startsWith('https://')) {
            final uri = Uri.parse(_logoUrl!);
            final request = await HttpClient().getUrl(uri);
            final response = await request.close();
            final List<int> bytes = [];
            await for (var chunk in response) { bytes.addAll(chunk); }
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else if (_logoUrl!.length > 500) { 
            final bytes = base64Decode(_logoUrl!);
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else {
            if (!kIsWeb) {
              final file = File(_logoUrl!);
              if (file.existsSync()) {
                imagenLogo = pw.MemoryImage(file.readAsBytesSync());
              }
            }
          }
        } catch (e) {
          print("Error cargando logo: $e");
        }
      }

      pw.MemoryImage? imagenPagos;
      try {
        final ByteData bytesPagos = await rootBundle.load('assets/pagos.jpg');
        imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
      } catch (e) {
        try {
          final ByteData bytesPagos = await rootBundle.load('assets/pagos.png');
          imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
        } catch (_) {}
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(22 * PdfPageFormat.cm, 11 * PdfPageFormat.cm, marginAll: 1 * PdfPageFormat.cm), 
          build: (pw.Context context) {
            final date = DateTime.parse(data['fecha'] ?? DateTime.now().toIso8601String());

            return pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (imagenLogo != null)
                        pw.Image(imagenLogo, width: 80, height: 80)
                      else
                        pw.Container(width: 80, height: 80, color: PdfColors.grey200, alignment: pw.Alignment.center, child: pw.Text("LOGO")),
                      pw.SizedBox(width: 15),
                      
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text("COMPROBANTE SERVICIO DE TRANSPORTE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 5),
                            pw.Text(data['empresa_nombre_titular'] ?? _nombreEmpresa.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            if (_rutEmpresa.isNotEmpty)
                              pw.Text("RUT: $_rutEmpresa", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            
                            // 🚀 ENCABEZADO LIMPIO: Sin prefijo "Correo:", tamaño 12 y en negrita
                            pw.SizedBox(height: 2),
                            pw.Text(_empresaCorreo.toLowerCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            
                            // 🚀 ENCABEZADO LIMPIO: Sin prefijo "Web:", tamaño 12 y en negrita
                            if (_sitioWeb.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(_sitioWeb.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            ],
                            
                            pw.SizedBox(height: 5),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.SvgImage(svg: _svgWhatsapp, width: 14, height: 14),
                                pw.SizedBox(width: 5),
                                pw.Text("+56 $_celularEmpresa", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ),
                      
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Recibo N° ${data['numero'].toString().padLeft(4, '0')}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            children: [
                              pw.Text("Fecha ", style: const pw.TextStyle(fontSize: 10)),
                              _construirCajitaPDF(DateFormat('dd').format(date)),
                              _construirCajitaPDF(DateFormat('MM').format(date)),
                              _construirCajitaPDF(DateFormat('yy').format(date)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  
                  _construirLineaPDF("SR (A):", (data['sr'] ?? '').toUpperCase()),
                  pw.SizedBox(height: 8),
                  if (data['convenio_empresa'] == true) ...[
                    _construirLineaPDF("EMPRESA CONVENIO:", (data['nombre_empresa_pasajero'] ?? '').toUpperCase()),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Row(
                    children: [
                      pw.Expanded(child: _construirLineaPDF("ORIGEN:", (data['origen'] ?? '').toUpperCase())),
                      pw.SizedBox(width: 15),
                      pw.Expanded(child: _construirLineaPDF("DESTINO:", (data['destino'] ?? '').toUpperCase())),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  _construirLineaPDF("OBSERVACIONES:", (data['observaciones'] ?? '').toUpperCase()),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: _construirLineaPDF("CONDUCTOR:", (data['conductor_nombre'] ?? '').toUpperCase())),
                      pw.SizedBox(width: 15),
                      pw.Expanded(flex: 2, child: _construirLineaPDF("PATENTE:", (data['patente'] ?? '').toUpperCase())),
                    ],
                  ),
                  
                  pw.Spacer(),
                  
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (data['mostrar_logos'] == true && imagenPagos != null)
                        pw.Container(width: 120, height: 35, child: pw.Image(imagenPagos, fit: pw.BoxFit.contain))
                      else
                        pw.SizedBox(width: 120), 
                      
                      pw.Expanded(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          mainAxisAlignment: pw.MainAxisAlignment.end, 
                          children: [
                            pw.Text("VALOR \$ ", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.Container(
                              width: 120, 
                              padding: const pw.EdgeInsets.only(bottom: 2, left: 5), 
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                              child: pw.Text(NumberFormat.currency(locale: 'es_CL', symbol: '', decimalDigits: 0).format(data['monto'] ?? 0), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      return await pdf.save();

    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear PDF: $e')));
      return null;
    }
  }

  void _abrirOpcionesPDF(Map<String, dynamic> item) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Procesando documento... ⏳"), duration: Duration(milliseconds: 800)));
    
    Uint8List? archivoPdfBytes = await _generarPDFCorporativo(item);
    if (archivoPdfBytes == null) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Opciones del Comprobante", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text("Ver / Imprimir PDF"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => archivoPdfBytes);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text("Compartir / Descargar"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.sharePdf(bytes: archivoPdfBytes, filename: 'Recibo_Flota_N${item['numero']}.pdf');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _emititRecibo() async {
    if (_montoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El monto es obligatorio.")));
      return;
    }

    setState(() { _generandoRecibo = true; });

    try {
      final nuevoRecibo = {
        'numero': _numeroCorrelativoActual,
        'fecha': _fechaSeleccionada.toIso8601String(), 
        'convenio_empresa': _convenioEmpresa, 
        'nombre_empresa_pasajero': _convenioEmpresa ? _empresaPasajeroCtrl.text.trim() : "", 
        'mostrar_logos': _mostrarLogosPago,
        'sr': _pasajeroCtrl.text.trim(), 
        'origen': _origenCtrl.text.trim(),
        'destino': _destinoCtrl.text.trim(),
        'observaciones': _observacionesCtrl.text.trim(),
        'monto': int.tryParse(_montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'conductor_nombre': _nombreConductor,
        'patente': _patente,
        'empresa_correo': _empresaCorreo, 
        'empresa_nombre_titular': _nombreEmpresa, 
        'correo_emisor': FirebaseAuth.instance.currentUser?.email,
      };

      await FirebaseFirestore.instance.collection('recibos').add(nuevoRecibo);

      _empresaPasajeroCtrl.clear();
      _pasajeroCtrl.clear();
      _origenCtrl.clear();
      _destinoCtrl.clear();
      _observacionesCtrl.clear();
      _montoCtrl.clear();
      
      setState(() { 
        _numeroCorrelativoActual++;
        _convenioEmpresa = false;
        _mostrarLogosPago = true; 
        _fechaSeleccionada = DateTime.now();
        _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
      }); 

      _abrirOpcionesPDF(nuevoRecibo);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al emitir: $e")));
    } finally { 
      setState(() { _generandoRecibo = false; });
    }
  }

  Widget _construirAvatarLogo(String? ruta) {
    Widget imagenFinal;

    if (ruta == null || ruta.isEmpty) {
      imagenFinal = const Icon(Icons.business, color: Color(0xFF0D47A1), size: 24);
    } else if (ruta.startsWith('http')) {
      imagenFinal = Image.network(ruta, fit: BoxFit.contain);
    } else if (ruta.length > 500) {
      imagenFinal = Image.memory(base64Decode(ruta), fit: BoxFit.contain);
    } else {
      if (kIsWeb) {
         imagenFinal = const Icon(Icons.business, color: Color(0xFF0D47A1), size: 24);
      } else {
        final file = File(ruta);
        if (file.existsSync()) {
          imagenFinal = Image.file(file, fit: BoxFit.contain);
        } else {
          imagenFinal = const Icon(Icons.business, color: Color(0xFF0D47A1), size: 24);
        }
      }
    }

    return Container(
      color: Colors.white, 
      padding: const EdgeInsets.all(3), 
      child: imagenFinal,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80, 
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 10, bottom: 10),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            clipBehavior: Clip.hardEdge,
            child: _construirAvatarLogo(_logoUrl),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Hola, $_nombreConductor", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_nombreEmpresa, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black87, width: 1.5),
              ),
              child: Text(
                _patente, 
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: _cerrarSesion,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.receipt), text: "Emitir"),
            Tab(icon: Icon(Icons.history), text: "Mis Viajes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormularioClasico(),
          _buildHistorialPersonal(),
        ],
      ),
    );
  }

  Widget _buildFormularioClasico() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _fechaCtrl,
            readOnly: true,
            onTap: () => _seleccionarFecha(context),
            decoration: InputDecoration(
              labelText: "Fecha del Servicio",
              suffixIcon: const Icon(Icons.calendar_month, color: Color(0xFF0D47A1)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade400)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
              filled: true,
              fillColor: Colors.blue[50],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Convenio de Empresa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Switch(
                value: _convenioEmpresa,
                activeThumbColor: const Color(0xFF0D47A1),
                onChanged: (val) { setState(() { _convenioEmpresa = val; }); },
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_convenioEmpresa) ...[
            _crearCajaTextoSimple("Nombre Empresa del Pasajero", _empresaPasajeroCtrl),
            const SizedBox(height: 16),
          ],

          _crearCajaTextoSimple("Nombre Pasajero (Sr/Sra)", _pasajeroCtrl),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _crearCajaTextoSimple("Origen", _origenCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _crearCajaTextoSimple("Destino", _destinoCtrl)),
            ],
          ),
          const SizedBox(height: 16),

          _crearCajaTextoSimple("Observaciones", _observacionesCtrl),
          const SizedBox(height: 16),

          TextField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: "Valor \$",
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade400)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)), 
            ),
          ),
          const SizedBox(height: 20),

          SwitchListTile(
            title: const Text("Mostrar medios de pago", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Agrega Redcompra, visa Y Mastercard Al Pdf"),
            value: _mostrarLogosPago, 
            activeThumbColor: const Color(0xFF0D47A1), 
            onChanged: (bool valor) { setState(() { _mostrarLogosPago = valor; }); },
          ),
          const SizedBox(height: 30),

          _generandoRecibo
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
                ),
                onPressed: _emititRecibo,
                child: const Text("GUARDAR E INYECTAR EN FLOTA", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
        ],
      ),
    );
  }

  Widget _crearCajaTextoSimple(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words, 
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
      ),
    );
  }

  Widget _buildHistorialPersonal() {
    final miCorreo = FirebaseAuth.instance.currentUser?.email ?? "";
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('recibos').where('correo_emisor', isEqualTo: miCorreo).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        if (docs.isEmpty) return const Center(child: Text("Aún no has emitido recibos."));

        docs.sort((a, b) {
          final int numA = (a.data() as Map<String, dynamic>)['numero'] ?? 0;
          final int numB = (b.data() as Map<String, dynamic>)['numero'] ?? 0;
          return numB.compareTo(numA);
        });

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = docs[index].data() as Map<String, dynamic>;
            final f = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFE3F2FD), child: Text(item['numero'].toString(), style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold))),
                title: Text("${item['origen']} ➔ ${item['destino']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text("${DateFormat('dd/MM/yy').format(DateTime.parse(item['fecha']))}  |  ${f.format(item['monto'] ?? 0)}"),
                trailing: IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: () => _abrirOpcionesPDF(item), 
                ),
              ),
            );
          },
        );
      },
    );
  }
}