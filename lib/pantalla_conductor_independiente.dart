// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart'; 
import 'pantalla_bienvenida.dart';
import 'package:universal_html/html.dart' as html;

class Recibo {
  final int numero;
  final String sr;
  final String origen;
  final String destino;
  final String observaciones;
  final double monto;
  final DateTime fecha;
  final bool esConvenio;
  final String empresaPasajero;
  final bool mostrarLogosPago;

  Recibo({
    required this.numero, required this.sr, required this.origen,
    required this.destino, required this.observaciones, required this.monto,
    required this.fecha, required this.esConvenio, required this.empresaPasajero,
    required this.mostrarLogosPago,
  });

  Map<String, dynamic> toJson() => {
        'numero': numero, 'sr': sr, 'origen': origen, 'destino': destino,
        'observaciones': observaciones, 'monto': monto, 'fecha': fecha.toIso8601String(),
        'esConvenio': esConvenio, 'empresaPasajero': empresaPasajero, 'mostrarLogosPago': mostrarLogosPago,
      };

  factory Recibo.fromJson(Map<String, dynamic> json) => Recibo(
        numero: json['numero'] ?? 1, sr: json['sr'] ?? '', origen: json['origen'] ?? '',
        destino: json['destino'] ?? '', observaciones: json['observaciones'] ?? '',
        monto: (json['monto'] ?? 0).toDouble(), fecha: DateTime.parse(json['fecha']),
        esConvenio: json['esConvenio'] ?? false, empresaPasajero: json['empresaPasajero'] ?? '',
        mostrarLogosPago: json['mostrarLogosPago'] ?? false,
      );
}

class DatosEmpresa {
  final String nombreConductor;
  final String nombreEmpresa;
  final String rutEmpresa;
  final String celular; 
  final String correo;
  final String patente; 
  final String sitioWeb; 
  final String? rutaLogo;

  DatosEmpresa({
    required this.nombreConductor, 
    required this.nombreEmpresa, 
    required this.rutEmpresa,
    required this.celular, 
    required this.correo, 
    required this.patente, 
    required this.sitioWeb, 
    this.rutaLogo,
  });
}

class PantallaInicio extends StatefulWidget {
  final DatosEmpresa datosEmpresa;
  const PantallaInicio({super.key, required this.datosEmpresa});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<Recibo> misRecibos = [];
  bool _esFlota = false;
  bool _cargandoVinculo = true;
  String? _empresaCorreoReal;
  late DatosEmpresa datosEmpresaActiva;

  @override
  void initState() {
    super.initState();
    datosEmpresaActiva = widget.datosEmpresa;
    _analizarPerfilYVinculacion();
  }

  void _escucharRecibosNube(String correoEmpresa) {
    // 🚀 BLINDAJE: Forzamos minúsculas en el parámetro para evitar descalces con el visor
    final String correoFiltro = correoEmpresa.trim().toLowerCase();
    final DateTime? creationTime = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    
    final DateTime limiteIgnorar = creationTime != null 
        ? creationTime.subtract(const Duration(days: 1)) 
        : DateTime(2000);

    FirebaseFirestore.instance
        .collection('recibos')
        .where('empresa_correo', isEqualTo: correoFiltro)
        .snapshots()
        .listen((snapshot) {
      List<Recibo> recibosNube = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final DateTime fechaRecibo = DateTime.parse(data['fecha'] ?? DateTime.now().toIso8601String());

        if (creationTime != null && fechaRecibo.isBefore(limiteIgnorar)) {
          continue; 
        }

        recibosNube.add(Recibo(
          numero: data['numero'] ?? 0,
          sr: data['sr'] ?? '',
          origen: data['origen'] ?? '',
          destino: data['destino'] ?? '',
          observaciones: data['observaciones'] ?? '',
          monto: (data['monto'] ?? 0).toDouble(),
          fecha: fechaRecibo,
          esConvenio: data['esConvenio'] ?? false,
          empresaPasajero: data['empresaPasajero'] ?? '',
          mostrarLogosPago: data['mostrar_logos'] ?? data['mostrarLogosPago'] ?? true,
        ));
      }
      recibosNube.sort((a, b) => b.numero.compareTo(a.numero));
      setState(() {
        misRecibos = recibosNube;
      });
    });
  }

  Future<void> _analizarPerfilYVinculacion() async {
    try {
      // 🚀 UNIFICACIÓN ABSOLUTA: Aplanamos el correo de entrada a minúsculas
      final String emailClean = widget.datosEmpresa.correo.trim().toLowerCase();
      List<String> variaciones = [emailClean, widget.datosEmpresa.correo.trim(), widget.datosEmpresa.correo.trim().toUpperCase()];

      // 1. Intentar buscar como Conductor de Empresa (Flota)
      DocumentSnapshot docFlota = await FirebaseFirestore.instance
          .collection('conductores_flota')
          .doc(emailClean)
          .get();

      if (!docFlota.exists) {
        // Fallback por si acaso quedó registrado con mayúsculas en el ID del documento
        for (String variante in variaciones) {
          DocumentSnapshot docVar = await FirebaseFirestore.instance.collection('conductores_flota').doc(variante).get();
          if (docVar.exists) {
            docFlota = docVar;
            break;
          }
        }
      }

      if (docFlota.exists) {
        String correoAdminFlota = (docFlota['empresa_correo'] ?? "").toString().trim().toLowerCase();
        String nombreEmpresa = "TRANSPORTE CORPORATIVO";
        String rutEmpresa = "";
        String celularEmpresa = "";
        String sitioWeb = "";
        String? rutaLogo;

        // Buscar datos de la empresa vinculada
        DocumentSnapshot docEmpresa = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(correoAdminFlota)
            .get();

        if (!docEmpresa.exists) {
          QuerySnapshot q = await FirebaseFirestore.instance
              .collection('empresas')
              .where('correo', whereIn: [correoAdminFlota, correoAdminFlota.toUpperCase()])
              .get();
          if (q.docs.isNotEmpty) docEmpresa = q.docs.first;
        }

        if (docEmpresa.exists) {
          final data = docEmpresa.data() as Map<String, dynamic>? ?? {};
          nombreEmpresa = data['empresa_nombre'] ?? data['nombre'] ?? "TAXI-VÍA AERO TRANSPORTE";
          rutEmpresa = data['rut_empresa'] ?? data['rut'] ?? "78.325.923-0";
          celularEmpresa = data['celular_contacto'] ?? data['celular'] ?? "928207018";
          sitioWeb = data['sitio_web'] ?? data['web'] ?? "";
          rutaLogo = data['ruta_logo'] ?? data['logo_url'];
        }

        setState(() {
          _esFlota = true;
          _empresaCorreoReal = correoAdminFlota;
          datosEmpresaActiva = DatosEmpresa(
            nombreConductor: docFlota['nombre'] ?? widget.datosEmpresa.nombreConductor,
            nombreEmpresa: nombreEmpresa,
            rutEmpresa: rutEmpresa,
            celular: celularEmpresa, 
            correo: emailClean,
            patente: docFlota['patente'] ?? widget.datosEmpresa.patente,
            sitioWeb: sitioWeb,
            rutaLogo: rutaLogo,
          );
          _cargandoVinculo = false;
        });
        _escucharRecibosNube(correoAdminFlota);
        return;
      } 
      
      // 2. Si no es flota, buscar como Conductor Independiente
      DocumentSnapshot docIndep = await FirebaseFirestore.instance
          .collection('conductores_independientes')
          .doc(emailClean)
          .get();

      Map<String, dynamic>? dataIndep;
      bool encontradoIndep = false;

      if (docIndep.exists) {
        dataIndep = docIndep.data() as Map<String, dynamic>;
        encontradoIndep = true;
      } else {
        QuerySnapshot qIndep = await FirebaseFirestore.instance
            .collection('conductores_independientes')
            .where('correo', whereIn: variaciones)
            .get();
        if (qIndep.docs.isEmpty) {
          qIndep = await FirebaseFirestore.instance
              .collection('conductores_independientes')
              .where('email', whereIn: variaciones)
              .get();
        }
        if (qIndep.docs.isNotEmpty) {
          docIndep = qIndep.docs.first;
          dataIndep = docIndep.data() as Map<String, dynamic>;
          encontradoIndep = true;
        }
      }

      if (encontradoIndep && dataIndep != null) {
        _empresaCorreoReal = emailClean;
        setState(() {
          _esFlota = false;
          datosEmpresaActiva = DatosEmpresa(
            nombreConductor: dataIndep!['nombre'] ?? widget.datosEmpresa.nombreConductor,
            nombreEmpresa: dataIndep['empresa_nombre'] ?? dataIndep['nombre_empresa'] ?? widget.datosEmpresa.nombreEmpresa,
            rutEmpresa: dataIndep['rut_empresa'] ?? dataIndep['rut'] ?? widget.datosEmpresa.rutEmpresa,
            celular: dataIndep['celular_contacto'] ?? dataIndep['celular'] ?? widget.datosEmpresa.celular,
            correo: emailClean,
            patente: dataIndep['patente'] ?? widget.datosEmpresa.patente,
            sitioWeb: dataIndep['sitio_web'] ?? widget.datosEmpresa.sitioWeb,
            rutaLogo: dataIndep['ruta_logo'] ?? widget.datosEmpresa.rutaLogo,
          );
          _cargandoVinculo = false;
        });
        _escucharRecibosNube(emailClean);
      } else {
        setState(() { 
          _esFlota = false;
          _cargandoVinculo = false; 
        });
      }
    } catch (e) {
      setState(() { 
        _esFlota = false;
        _cargandoVinculo = false; 
      });
    }
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PantallaBienvenida()),
      (route) => false,
    );
  }

  Future<bool> _solicitarConfirmacionSalida() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar Sesión", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
        content: const Text("¿Estás seguro de que deseas cerrar tu sesión?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("VOLVER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("CERRAR SESIÓN"),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<void> _eliminarComprobanteDeLista(Recibo reciboAEliminar, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Comprobante", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("¿Estás seguro de que deseas eliminar este comprobante? Esta acción borrará el registro permanentemente de la nube."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SÍ, ELIMINAR"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final String correoFiltro = (_empresaCorreoReal ?? datosEmpresaActiva.correo).trim().toLowerCase();
        final q = await FirebaseFirestore.instance.collection('recibos')
          .where('numero', isEqualTo: reciboAEliminar.numero)
          .where('empresa_correo', isEqualTo: correoFiltro)
          .get();
        for (var doc in q.docs) {
          await doc.reference.delete();
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comprobante eliminado con éxito.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  void _abrirDialogoEditarPerfil() {
    final nombreCtrl = TextEditingController(text: datosEmpresaActiva.nombreConductor);
    final empresaCtrl = TextEditingController(text: datosEmpresaActiva.nombreEmpresa);
    final rutCtrl = TextEditingController(text: datosEmpresaActiva.rutEmpresa);
    final celularCtrl = TextEditingController(text: datosEmpresaActiva.celular);
    final patenteCtrl = TextEditingController(text: datosEmpresaActiva.patente);
    final webCtrl = TextEditingController(text: datosEmpresaActiva.sitioWeb);
    String? nuevoLogoBase64 = datosEmpresaActiva.rutaLogo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Editar Datos de Empresa", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre Conductor")),
                if (!_esFlota) ...[
                  TextField(controller: empresaCtrl, decoration: const InputDecoration(labelText: "Nombre Empresa")),
                  TextField(controller: rutCtrl, decoration: const InputDecoration(labelText: "RUT Empresa")),
                  TextField(controller: celularCtrl, decoration: const InputDecoration(labelText: "Celular Contacto")),
                  TextField(controller: webCtrl, decoration: const InputDecoration(labelText: "Sitio Web")),
                ],
                TextField(controller: patenteCtrl, decoration: const InputDecoration(labelText: "Patente")),
                const SizedBox(height: 20),
                if (!_esFlota) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
                      uploadInput.click();
                      uploadInput.onChange.listen((e) {
                        final files = uploadInput.files;
                        if (files != null && files.isNotEmpty) {
                          final reader = html.FileReader();
                          reader.readAsDataUrl(files[0]);
                          reader.onLoadEnd.listen((e) {
                            String base64Result = reader.result as String;
                            base64Result = base64Result.split(',').last;
                            setDialogState(() {
                              nuevoLogoBase64 = base64Result;
                            });
                          });
                        }
                      });
                    },
                    icon: const Icon(Icons.image),
                    label: const Text("SUBIR / CAMBIAR LOGO"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[50], foregroundColor: const Color(0xFF0D47A1)),
                  ),
                  if (nuevoLogoBase64 != null) ...[
                    const SizedBox(height: 10),
                    const Text("✓ Imagen de logo procesada", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ]
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Actualizando perfil corporativo... ⏳")));
                
                final String emailKey = datosEmpresaActiva.correo.trim().toLowerCase();

                if (_esFlota) {
                  await FirebaseFirestore.instance.collection('conductores_flota').doc(emailKey).update({
                    'nombre': nombreCtrl.text.trim(),
                    'patente': patenteCtrl.text.trim().toUpperCase(),
                  });
                } else {
                  final mapaActualizado = {
                    'nombre': nombreCtrl.text.trim(),
                    'empresa_nombre': empresaCtrl.text.trim(),
                    'rut_empresa': rutCtrl.text.trim(),
                    'celular_contacto': celularCtrl.text.trim(),
                    'patente': patenteCtrl.text.trim().toUpperCase(),
                    'sitio_web': webCtrl.text.trim(),
                    'ruta_logo': nuevoLogoBase64,
                  };
                  await FirebaseFirestore.instance.collection('conductores_independientes').doc(emailKey).update(mapaActualizado);
                }
                _analizarPerfilYVinculacion();
              },
              child: const Text("GUARDAR PERFIL"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _exportarCSVFinanzas() async {
    try {
      if (misRecibos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar.")));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generando Excel financiero... ⏳")));
      
      String csvData = "Numero;Fecha;Pasajero;Origen;Destino;Monto\n";
      double sumaTotal = 0; 

      final fMoneda = NumberFormat('#,##0', 'es_CL');

      for (var r in misRecibos) {
        final fecha = DateFormat('dd/MM/yyyy').format(r.fecha);
        final passenger = r.sr.replaceAll('"', '""');
        final origen = r.origen.replaceAll('"', '""');
        final destino = r.destino.replaceAll('"', '""');
        final montoFormateado = "\$${fMoneda.format(r.monto)}";
        
        csvData += "${r.numero};$fecha;\"$passenger\";\"$origen\";\"$destino\";\"$montoFormateado\"\n";
        sumaTotal += r.monto; 
      }
      
      final totalFormateado = "\$${fMoneda.format(sumaTotal)}";
      csvData += ";;;;\"TOTAL:\";\"$totalFormateado\"\n";
      
      final nombreArchivo = "Reporte_Financiero_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.csv";
      final String correoKey = (_empresaCorreoReal ?? datosEmpresaActiva.correo).trim().toLowerCase();

      try {
        await FirebaseFirestore.instance.collection('reportes').add({
          'empresa_correo': correoKey,
          'fecha': DateTime.now().toIso8601String(),
          'monto_total': sumaTotal,
          'total_recibos': misRecibos.length,
          'csv_data': csvData,
          'nombre_archivo': nombreArchivo,
        });
      } catch (e) {
        print("Error respaldando historial de reportes: $e");
      }

      if (kIsWeb) {
        final bytes = utf8.encode('\uFEFF$csvData'); 
        final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", nombreArchivo)
          ..style.display = 'none';
        
        html.document.body?.children.add(anchor);
        anchor.click();
        
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo CSV descargado.')));
      } else {
        final bytes = Uint8List.fromList([239, 187, 191] + utf8.encode(csvData));
        await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al generar .CSV: $e")));
    }
  }

  void _descargarReporteExistente(String csvData, String nombreArchivo) async {
    if (kIsWeb) {
      final bytes = utf8.encode('\uFEFF$csvData'); 
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", nombreArchivo)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      final bytes = Uint8List.fromList([239, 187, 191] + utf8.encode(csvData));
      await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
    }
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

  Future<Uint8List?> _generarBytesPDF(Recibo recibo) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? imagenLogo;
      pw.MemoryImage? imagenPagos;

      if (datosEmpresaActiva.rutaLogo != null && datosEmpresaActiva.rutaLogo!.isNotEmpty) {
        try {
          if (datosEmpresaActiva.rutaLogo!.startsWith('http')) {
            final request = await HttpClient().getUrl(Uri.parse(datosEmpresaActiva.rutaLogo!));
            final response = await request.close();
            final List<int> bytes = [];
            await for (var chunk in response) { bytes.addAll(chunk); }
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else if (datosEmpresaActiva.rutaLogo!.length > 500) { 
            final bytes = base64Decode(datosEmpresaActiva.rutaLogo!);
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          }
        } catch (e) { print(e); }
      }

      try {
        final ByteData bytesPagos = await rootBundle.load('assets/pagos.jpg'); 
        imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
      } catch (_) {
        try { 
          final ByteData bytesPagos = await rootBundle.load('assets/pagos.png');
          imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
        } catch (_) {}
      }

      const String svgWhatsapp = '''<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#25D366" d="M12.031 0C5.383 0 0 5.383 0 12.031c0 2.124.551 4.195 1.597 6.012L.038 24l6.113-1.603a11.96 11.96 0 0 0 5.88 1.535h.005c6.648 0 12.031-5.384 12.031-12.032C24.067 5.383 18.679 0 12.031 0zm0 21.933h-.004a9.922 9.922 0 0 1-5.062-1.385l-.363-.215-3.766.987.998-3.668-.236-.376a9.92 9.92 0 0 1-1.517-5.313c0-5.502 4.478-9.98 9.98-9.98 5.502 0 9.98 4.478 9.98 9.98 0 5.502-4.478 9.98-9.98 9.98z"/><path fill="#FFF" d="M17.505 14.453c-.301-.151-1.777-.878-2.052-.979-.276-.1-.477-.151-.678.151-.201.301-.778.979-.953 1.18-.175.201-.351.226-.652.075-.301-.151-1.27-.468-2.42-1.493-.895-.798-1.501-1.784-1.677-2.085-.175-.301-.019-.464.132-.614.135-.135.301-.351.452-.527.151-.175.201-.351.301-.502.1-.201.05-.376-.025-.527-.075-.151-.678-1.631-.928-2.233-.245-.59-.493-.51-.678-.519-.175-.01-.376-.01-.577-.01-.201 0-.527.075-.803.376-.276.301-1.053 1.029-1.053 2.509s1.078 2.91 1.229 3.111c.151.201 2.124 3.242 5.143 4.545.719.31 1.28.495 1.718.633.723.23 1.382.197 1.901.12.583-.087 1.777-.726 2.028-1.43.251-.703.251-1.305.175-1.43-.075-.125-.276-.2-.577-.351z"/></svg>''';

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(22 * PdfPageFormat.cm, 11 * PdfPageFormat.cm, marginAll: 1 * PdfPageFormat.cm),
          build: (pw.Context context) {
            return pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (imagenLogo != null) pw.Image(imagenLogo, width: 80, height: 80)
                      else pw.Container(width: 80, height: 80, color: PdfColors.grey200, alignment: pw.Alignment.center, child: pw.Text("LOGO")),
                      pw.SizedBox(width: 15),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text("COMPROBANTE SERVICIO DE TRANSPORTE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 5),
                            pw.Text(datosEmpresaActiva.nombreEmpresa.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            if (datosEmpresaActiva.rutEmpresa.isNotEmpty) pw.Text("RUT: ${datosEmpresaActiva.rutEmpresa}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            
                            pw.SizedBox(height: 2),
                            pw.Text(datosEmpresaActiva.correo.toLowerCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            if (datosEmpresaActiva.sitioWeb.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(datosEmpresaActiva.sitioWeb.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            ],
                            
                            pw.SizedBox(height: 5),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.SvgImage(svg: svgWhatsapp, width: 14, height: 14),
                                pw.SizedBox(width: 5),
                                pw.Text("+56 ${datosEmpresaActiva.celular}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Recibo N° ${recibo.numero.toString().padLeft(4, '0')}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            children: [
                              pw.Text("Fecha ", style: const pw.TextStyle(fontSize: 10)),
                              _construirCajitaPDF(DateFormat('dd').format(recibo.fecha)),
                              _construirCajitaPDF(DateFormat('MM').format(recibo.fecha)),
                              _construirCajitaPDF(DateFormat('yy').format(recibo.fecha)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  
                  _construirLineaPDF("SR (A):", recibo.sr.toUpperCase()),
                  pw.SizedBox(height: 8),
                  if (recibo.esConvenio) ...[
                    _construirLineaPDF("EMPRESA CONVENIO:", recibo.empresaPasajero.toUpperCase()),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Row(
                    children: [
                      pw.Expanded(child: _construirLineaPDF("ORIGEN:", recibo.origen.toUpperCase())),
                      pw.SizedBox(width: 15),
                      pw.Expanded(child: _construirLineaPDF("DESTINO:", recibo.destino.toUpperCase())),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  _construirLineaPDF("OBSERVACIONES:", recibo.observaciones.toUpperCase()),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: _construirLineaPDF("CONDUCTOR:", datosEmpresaActiva.nombreConductor.toUpperCase())),
                      pw.SizedBox(width: 15),
                      pw.Expanded(flex: 2, child: _construirLineaPDF("PATENTE:", datosEmpresaActiva.patente.toUpperCase())),
                    ],
                  ),
                  
                  pw.Spacer(),
                  
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (recibo.mostrarLogosPago && imagenPagos != null)
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
                              child: pw.Text(NumberFormat.currency(locale: 'es_CL', symbol: '', decimalDigits: 0).format(recibo.monto), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
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
      return null;
    }
  }

  Future<void> _abrirOpcionesPDFDesdeLista(Recibo recibo) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Procesando documento... ⏳"), duration: Duration(milliseconds: 800)));
    
    final Uint8List? pdfBytes = await _generarBytesPDF(recibo);
    if (pdfBytes == null) return;
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
              title: const Text("Abrir y Ver PDF"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text("Compartir / Descargar"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.sharePdf(bytes: pdfBytes, filename: 'Recibo_N${recibo.numero}_Independiente.pdf');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
    if (_cargandoVinculo) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await _solicitarConfirmacionSalida();
        if (salir) _cerrarSesion();
      },
      child: _esFlota 
        ? Scaffold(
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
                  child: _construirAvatarLogo(datosEmpresaActiva.rutaLogo),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Hola, ${datosEmpresaActiva.nombreConductor}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(datosEmpresaActiva.nombreEmpresa, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black87, width: 1.5),
                    ),
                    child: Text(
                      datosEmpresaActiva.patente, 
                      style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.white),
                  onPressed: _abrirDialogoEditarPerfil,
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    final salir = await _solicitarConfirmacionSalida();
                    if (salir) _cerrarSesion();
                  },
                ),
              ],
            ),
            body: _buildVistaComprobantes(),
          )
        : DefaultTabController(
            length: 2,
            child: Scaffold(
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
                    child: _construirAvatarLogo(datosEmpresaActiva.rutaLogo),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Hola, ${datosEmpresaActiva.nombreConductor}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(datosEmpresaActiva.nombreEmpresa, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black87, width: 1.5),
                      ),
                      child: Text(
                        datosEmpresaActiva.patente, 
                        style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _abrirDialogoEditarPerfil,
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      final salir = await _solicitarConfirmacionSalida();
                      if (salir) _cerrarSesion();
                    },
                  ),
                ],
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(icon: Icon(Icons.receipt_long), text: "Comprobantes"),
                    Tab(icon: Icon(Icons.bar_chart), text: "Mis Finanzas"),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _buildVistaComprobantes(),
                  _buildVistaFinanzasIndependiente(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildVistaComprobantes() {
    final f = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              int proximoNumero = 1;
              if (misRecibos.isNotEmpty) {
                proximoNumero = misRecibos.map((e) => e.numero).reduce((curr, next) => curr > next ? curr : next) + 1;
              }

              final resultado = await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaFormulario(numeroSugerido: proximoNumero)));
              
              if (resultado != null && resultado is Recibo) {
                try {
                  // 🚀 BLINDAJE EN ESCRITURA: Forzamos minúsculas absolutas al guardar los índices relacionales
                  final String correoConductorClean = datosEmpresaActiva.correo.trim().toLowerCase();
                  final String correoEmpresaClean = (_empresaCorreoReal ?? datosEmpresaActiva.correo).trim().toLowerCase();

                  await FirebaseFirestore.instance.collection('recibos').add({
                    'numero': resultado.numero,
                    'sr': resultado.sr, 
                    'origen': resultado.origen, 
                    'destino': resultado.destino,
                    'observaciones': resultado.observaciones,
                    'monto': resultado.monto,
                    'fecha': resultado.fecha.toIso8601String(), 
                    'esConvenio': resultado.esConvenio,
                    'empresaPasajero': resultado.empresaPasajero,
                    'conductor_email': correoConductorClean,
                    'conductor_nombre': datosEmpresaActiva.nombreConductor,
                    'patente': datosEmpresaActiva.patente,
                    'empresa_correo': correoEmpresaClean, 
                    'mostrar_logos': resultado.mostrarLogosPago,
                  });
                } catch (e) {
                  print("Error al subir a la nube: $e");
                }
                _abrirOpcionesPDFDesdeLista(resultado);
              }
            },
            icon: const Icon(Icons.add), label: const Text("NUEVO COMPROBANTE"),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFFE3F2FD), foregroundColor: const Color(0xFF0D47A1), elevation: 0),
          ),
        ),
        Expanded(
          child: misRecibos.isEmpty
              ? const Center(child: Text("Sin comprobantes generados.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: misRecibos.length,
                  itemBuilder: (context, index) {
                    final recibo = misRecibos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: const Color(0xFFE3F2FD), child: Text(recibo.numero.toString(), style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold))),
                        title: Text("Pasajero: ${recibo.sr}"),
                        subtitle: Text("Monto: ${f.format(recibo.monto)}\nEmitido por: ${datosEmpresaActiva.nombreConductor.toUpperCase()}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              onPressed: () => _abrirOpcionesPDFDesdeLista(recibo), 
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () => _eliminarComprobanteDeLista(recibo, index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVistaFinanzasIndependiente() {
    double totalDia = 0;
    double totalSemana = 0;
    double totalMes = 0;

    final ahora = DateTime.now();
    
    for (var r in misRecibos) {
      if (r.fecha.year == ahora.year && r.fecha.month == ahora.month && r.fecha.day == ahora.day) {
        totalDia += r.monto;
      }
      if (ahora.difference(r.fecha).inDays <= 7) {
        totalSemana += r.monto;
      }
      if (r.fecha.year == ahora.year && r.fecha.month == ahora.month) {
        totalMes += r.monto;
      }
    }

    final fMoneda = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    final String correoFiltroReporte = (_empresaCorreoReal ?? datosEmpresaActiva.correo).trim().toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTarjetaMoneda("MI RENDIMIENTO HOY", fMoneda.format(totalDia), Colors.blue),
          const SizedBox(height: 16),
          _buildTarjetaMoneda("MI RENDIMIENTO SEMANAL", fMoneda.format(totalSemana), Colors.orange),
          const SizedBox(height: 16),
          _buildTarjetaMoneda("MI TOTAL MENSUAL", fMoneda.format(totalMes), Colors.green),
          const SizedBox(height: 40),
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.analytics),
            label: const Text("GENERAR MI .CSV FINANCIERO", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _exportarCSVFinanzas, 
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 15),
          const Text("HISTORIAL DE REPORTES GENERADOS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reportes')
                .where('empresa_correo', isEqualTo: correoFiltroReporte) // 🚀 Consulta estandarizada en minúsculas
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No hay reportes archivados.", style: TextStyle(color: Colors.grey, fontSize: 13)));
              
              final listaDocs = List<QueryDocumentSnapshot>.from(docs);
              listaDocs.sort((a, b) => (b.data() as Map<String, dynamic>)['fecha'].toString().compareTo((a.data() as Map<String, dynamic>)['fecha'].toString()));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: listaDocs.length,
                itemBuilder: (context, index) {
                  final rData = listaDocs[index].data() as Map<String, dynamic>;
                  final fechaRep = DateTime.parse(rData['fecha'] ?? DateTime.now().toIso8601String());
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file, color: Colors.green),
                      title: Text(rData['nombre_archivo'] ?? 'Finanzas.csv', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text("Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(fechaRep)}\nMonto: ${fMoneda.format(rData['monto_total'] ?? 0)} (${rData['total_recibos'] ?? 0} viajes)"),
                      trailing: IconButton(
                        icon: const Icon(Icons.download_for_offline, color: Color(0xFF0D47A1), size: 28),
                        onPressed: () => _descargarReporteExistente(rData['csv_data'] ?? '', rData['nombre_archivo'] ?? 'Reporte.csv'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaMoneda(String t, String m, Color c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border(left: BorderSide(color: c, width: 6)), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), 
            blurRadius: 10, 
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(m, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }
}

class PantallaFormulario extends StatefulWidget {
  final int numeroSugerido;
  const PantallaFormulario({super.key, required this.numeroSugerido});

  @override
  State<PantallaFormulario> createState() => _PantallaFormularioState();
}

class _PantallaFormularioState extends State<PantallaFormulario> {
  final _srController = TextEditingController();
  final _origenController = TextEditingController();
  final _destinoController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _montoController = TextEditingController();
  final _empresaPasajeroController = TextEditingController();
  final _fechaCtrl = TextEditingController(); 

  DateTime _fechaSeleccionada = DateTime.now(); 
  bool _esConvenio = false;
  bool _mostrarLogosPago = true; 

  @override
  void initState() {
    super.initState();
    _fechaCtrl.text = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Comprobante N° ${widget.numeroSugerido.toString().padLeft(4, '0')}", style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0D47A1), iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _fechaCtrl,
              readOnly: true,
              onTap: () => _seleccionarFecha(context),
              decoration: InputDecoration(
                labelText: "Fecha del Servicio",
                suffixIcon: const Icon(Icons.calendar_month, color: Color(0xFF0D47A1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.blue[50],
              ),
            ),
            const SizedBox(height: 15),

            SwitchListTile(
              title: const Text("Convenio de Empresa", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Habilita esto si el pasajero viaja por convenio"),
              value: _esConvenio, activeThumbColor: const Color(0xFF0D47A1), 
              onChanged: (bool valor) { setState(() { _esConvenio = valor; }); },
            ),
            if (_esConvenio) ...[
              TextField(controller: _empresaPasajeroController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Nombre Empresa del Pasajero", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 15),
            ],
            TextField(controller: _srController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Nombre Pasajero (Sr/Sra)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: _origenController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Origen", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _destinoController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Destino", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
              ],
            ),
            const SizedBox(height: 15),
            TextField(controller: _observacionesController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Observaciones", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 15),
            TextField(
              controller: _montoController, 
              decoration: InputDecoration(labelText: "Valor \$", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              keyboardType: TextInputType.number, 
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
            ),
            const SizedBox(height: 15),
            SwitchListTile(
              title: const Text("Mostrar medios de pago", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Agrega Redcompra, visa Y Mastercard Al Pdf"),
              value: _mostrarLogosPago, activeThumbColor: const Color(0xFF0D47A1), 
              onChanged: (bool valor) { setState(() { _mostrarLogosPago = valor; }); },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () {
                if (_srController.text.isEmpty || _montoController.text.isEmpty) return;
                
                final nuevoRecibo = Recibo(
                  numero: widget.numeroSugerido, sr: _srController.text, origen: _origenController.text,
                  destino: _destinoController.text, observaciones: _observacionesController.text,
                  monto: double.tryParse(_montoController.text) ?? 0.0, 
                  fecha: _fechaSeleccionada, 
                  esConvenio: _esConvenio, empresaPasajero: _empresaPasajeroController.text,
                  mostrarLogosPago: _mostrarLogosPago,
                );
                Navigator.pop(context, nuevoRecibo);
              },
              child: const Text("GUARDAR COMPROBANTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaDetalleRecibo extends StatelessWidget {
  final Recibo recibo;
  final DatosEmpresa datosEmpresa;

  const PantallaDetalleRecibo({super.key, required this.recibo, required this.datosEmpresa});

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

  Future<void> _generarYCompartirPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? imagenLogo;
      pw.MemoryImage? imagenPagos;

      if (datosEmpresa.rutaLogo != null && datosEmpresa.rutaLogo!.isNotEmpty) {
        try {
          if (datosEmpresa.rutaLogo!.startsWith('http')) {
            final uri = Uri.parse(datosEmpresa.rutaLogo!);
            final request = await HttpClient().getUrl(uri);
            final response = await request.close();
            final List<int> bytes = [];
            await for (var chunk in response) { bytes.addAll(chunk); }
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else if (datosEmpresa.rutaLogo!.length > 500) { 
            final bytes = base64Decode(datosEmpresa.rutaLogo!);
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          }
        } catch (e) {
          print("Aviso: Logo no cargado ($e)");
        }
      }

      try {
        final ByteData bytesPagos = await rootBundle.load('assets/pagos.jpg'); 
        imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
      } catch (e) {
        try { 
          final ByteData bytesPagos = await rootBundle.load('assets/pagos.png');
          imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
        } catch (_) {}
      }

      const String svgWhatsapp = '''<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#25D366" d="M12.031 0C5.383 0 0 5.383 0 12.031c0 2.124.551 4.195 1.597 6.012L.038 24l6.113-1.603a11.96 11.96 0 0 0 5.88 1.535h.005c6.648 0 12.031-5.384 12.031-12.032C24.067 5.383 18.679 0 12.031 0zm0 21.933h-.004a9.922 9.922 0 0 1-5.062-1.385l-.363-.215-3.766.987.998-3.668-.236-.376a9.92 9.92 0 0 1-1.517-5.313c0-5.502 4.478-9.98 9.98-9.98 5.502 0 9.98 4.478 9.98 9.98 0 5.502-4.478 9.98-9.98 9.98z"/><path fill="#FFF" d="M17.505 14.453c-.301-.151-1.777-.878-2.052-.979-.276-.1-.477-.151-.678.151-.201.301-.778.979-.953 1.18-.175.201-.351.226-.652.075-.301-.151-1.27-.468-2.42-1.493-.895-.798-1.501-1.784-1.677-2.085-.175-.301-.019-.464.132-.614.135-.135.301-.351.452-.527.151-.175.201-.351.301-.502.1-.201.05-.376-.025-.527-.075-.151-.678-1.631-.928-2.233-.245-.59-.493-.51-.678-.519-.175-.01-.376-.01-.577-.01-.201 0-.527.075-.803.376-.276.301-1.053 1.029-1.053 2.509s1.078 2.91 1.229 3.111c.151.201 2.124 3.242 5.143 4.545.719.31 1.28.495 1.718.633.723.23 1.382.197 1.901.12.583-.087 1.777-.726 2.028-1.43.251-.703.251-1.305.175-1.43-.075-.125-.276-.2-.577-.351z"/></svg>''';

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(22 * PdfPageFormat.cm, 11 * PdfPageFormat.cm, marginAll: 1 * PdfPageFormat.cm),
          build: (pw.Context context) {
            return pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (imagenLogo != null) pw.Image(imagenLogo, width: 80, height: 80)
                      else pw.Container(width: 80, height: 80, color: PdfColors.grey200, alignment: pw.Alignment.center, child: pw.Text("LOGO")),
                      pw.SizedBox(width: 15),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text("COMPROBANTE SERVICIO DE TRANSPORTE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 5),
                            pw.Text(datosEmpresa.nombreEmpresa.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            if (datosEmpresa.rutEmpresa.isNotEmpty) pw.Text("RUT: ${datosEmpresa.rutEmpresa}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            
                            pw.SizedBox(height: 2),
                            pw.Text(datosEmpresa.correo.toLowerCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            if (datosEmpresa.sitioWeb.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(datosEmpresa.sitioWeb.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            ],
                            
                            pw.SizedBox(height: 5),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.SvgImage(svg: svgWhatsapp, width: 14, height: 14),
                                pw.SizedBox(width: 5),
                                pw.Text("+56 ${datosEmpresa.celular}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Recibo N° ${recibo.numero.toString().padLeft(4, '0')}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            children: [
                              pw.Text("Fecha ", style: const pw.TextStyle(fontSize: 10)),
                              _construirCajitaPDF(DateFormat('dd').format(recibo.fecha)),
                              _construirCajitaPDF(DateFormat('MM').format(recibo.fecha)),
                              _construirCajitaPDF(DateFormat('yy').format(recibo.fecha)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  
                  _construirLineaPDF("SR (A):", recibo.sr.toUpperCase()),
                  pw.SizedBox(height: 8),
                  if (recibo.esConvenio) ...[
                    _construirLineaPDF("EMPRESA CONVENIO:", recibo.empresaPasajero.toUpperCase()),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Row(
                    children: [
                      pw.Expanded(child: _construirLineaPDF("ORIGEN:", recibo.origen.toUpperCase())),
                      pw.SizedBox(width: 15), 
                      pw.Expanded(child: _construirLineaPDF("DESTINO:", recibo.destino.toUpperCase())),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  _construirLineaPDF("OBSERVACIONES:", recibo.observaciones.toUpperCase()),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: _construirLineaPDF("CONDUCTOR:", datosEmpresa.nombreConductor.toUpperCase())),
                      pw.SizedBox(width: 15),
                      pw.Expanded(flex: 2, child: _construirLineaPDF("PATENTE:", datosEmpresa.patente.toUpperCase())),
                    ],
                  ),
                  
                  pw.Spacer(),
                  
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (recibo.mostrarLogosPago && imagenPagos != null)
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
                              child: pw.Text(NumberFormat.currency(locale: 'es_CL', symbol: '', decimalDigits: 0).format(recibo.monto), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
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

      final pdfBytes = await pdf.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: "Recibo_N${recibo.numero}_${recibo.sr}.pdf");
      
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fMoneda = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: AppBar(title: Text("Comprobante N° ${recibo.numero.toString().padLeft(4, '0')}", style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0D47A1), iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.all(25.0),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(15), 
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), 
                    blurRadius: 10, 
                    spreadRadius: 2, 
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text("COMPROBANTE N° ${recibo.numero.toString().padLeft(4, '0')}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)))),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey, thickness: 1), 
                  const SizedBox(height: 20),
                  _construirFilaDato("Sr (a):", recibo.sr),
                  if (recibo.esConvenio) ...[
                    const SizedBox(height: 10),
                    _construirFilaDato("Convenio:", recibo.empresaPasajero),
                  ],
                  const SizedBox(height: 10),
                  _construirFilaDato("Origen:", recibo.origen),
                  const SizedBox(height: 10),
                  _construirFilaDato("Destino:", recibo.destino),
                  const SizedBox(height: 10),
                  _construirFilaDato("Obs:", recibo.observaciones),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("VALOR:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(fMoneda.format(recibo.monto), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generando comprobante... ⏳')));
                      await _generarYCompartirPDF(context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("COMPARTIR COMPROBANTE", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirFilaDato(String titulo, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(titulo, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16))),
      ],
    );
  }
}