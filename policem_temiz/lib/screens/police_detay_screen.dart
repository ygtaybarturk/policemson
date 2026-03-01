// lib/screens/police_detay_screen.dart  –  v3
// "Bilgiler" butonu → tam sigorta bilgi formu (tüm türler, manuel düzenle)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import 'police_form_screen.dart';

class PoliceDetayScreen extends StatefulWidget {
  final int policeId;
  const PoliceDetayScreen({super.key, required this.policeId});
  @override
  State<PoliceDetayScreen> createState() => _PoliceDetayScreenState();
}

class _PoliceDetayScreenState extends State<PoliceDetayScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  Police? _p;
  bool _yukleniyor = true;
  bool _duzenleme  = false;
  late TabController _tc;

  // Form kontrolcüleri
  late TextEditingController _tcCtrl, _dogumCtrl, _emailCtrl,
      _belgeSeriCtrl, _plakaCtrl, _markaCtrl, _modelCtrl,
      _yilCtrl, _ruhsatCtrl, _adresCtrl, _uavtCtrl, _notlarCtrl,
      _sirketCtrl, _tutarCtrl, _musteriAdiCtrl, _soyadiCtrl, _telCtrl;
  PoliceType _tur = PoliceType.trafik;
  String? _ozelTurAdi;
  DateTime? _bitisT, _baslangicT;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tc.dispose();
    for(final c in [_tcCtrl,_dogumCtrl,_emailCtrl,_belgeSeriCtrl,_plakaCtrl,
      _markaCtrl,_modelCtrl,_yilCtrl,_ruhsatCtrl,_adresCtrl,_uavtCtrl,
      _notlarCtrl,_sirketCtrl,_tutarCtrl,_musteriAdiCtrl,_soyadiCtrl,_telCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(()=>_yukleniyor=true);
    final p = await _db.getir(widget.policeId);
    if(p!=null) {
      setState(() {
        _p = p; _yukleniyor = false;
        _doldur(p);
      });
    }
  }

  void _doldur(Police p) {
    _musteriAdiCtrl = TextEditingController(text: p.musteriAdi);
    _soyadiCtrl     = TextEditingController(text: p.soyadi);
    _telCtrl        = TextEditingController(text: p.telefon);
    _emailCtrl      = TextEditingController(text: p.email??'');
    _tcCtrl         = TextEditingController(text: p.tcKimlikNo??'');
    _dogumCtrl      = TextEditingController(text: p.dogumTarihi??'');
    _sirketCtrl     = TextEditingController(text: p.sirket);
    _tutarCtrl      = TextEditingController(text: p.tutar==0?'':p.tutar.toStringAsFixed(0));
    _belgeSeriCtrl  = TextEditingController(text: p.belgeSeriNo??'');
    _plakaCtrl      = TextEditingController(text: p.aracPlaka??'');
    _markaCtrl      = TextEditingController(text: p.aracMarka??'');
    _modelCtrl      = TextEditingController(text: p.aracModel??'');
    _yilCtrl        = TextEditingController(text: p.aracYil??'');
    _ruhsatCtrl     = TextEditingController(text: p.ruhsatSeriNo??'');
    _adresCtrl      = TextEditingController(text: p.adres??'');
    _uavtCtrl       = TextEditingController(text: p.uavt??'');
    _notlarCtrl     = TextEditingController(text: p.notlar??'');
    _tur            = p.tur;
    _ozelTurAdi     = p.ozelTurAdi;
    _bitisT         = p.bitisTarihi;
    _baslangicT     = p.baslangicTarihi;
  }

  Future<void> _kaydet() async {
    if(_p==null) return;
    final g = _p!.copyWith(
      musteriAdi:    _musteriAdiCtrl.text.trim(),
      soyadi:        _soyadiCtrl.text.trim(),
      telefon:       _telCtrl.text.trim(),
      email:         _emailCtrl.text.trim().isEmpty?null:_emailCtrl.text.trim(),
      tcKimlikNo:    _tcCtrl.text.trim().isEmpty?null:_tcCtrl.text.trim(),
      dogumTarihi:   _dogumCtrl.text.trim().isEmpty?null:_dogumCtrl.text.trim(),
      sirket:        _sirketCtrl.text.trim(),
      tur:           _tur,
      ozelTurAdi:    _ozelTurAdi,
      bitisTarihi:   _bitisT??_p!.bitisTarihi,
      baslangicTarihi: _baslangicT??_p!.baslangicTarihi,
      tutar:         double.tryParse(_tutarCtrl.text.replaceAll(',','.'))?? _p!.tutar,
      belgeSeriNo:   _belgeSeriCtrl.text.trim().isEmpty?null:_belgeSeriCtrl.text.trim(),
      aracPlaka:     _plakaCtrl.text.trim().isEmpty?null:_plakaCtrl.text.trim().toUpperCase(),
      aracMarka:     _markaCtrl.text.trim().isEmpty?null:_markaCtrl.text.trim(),
      aracModel:     _modelCtrl.text.trim().isEmpty?null:_modelCtrl.text.trim(),
      aracYil:       _yilCtrl.text.trim().isEmpty?null:_yilCtrl.text.trim(),
      ruhsatSeriNo:  _ruhsatCtrl.text.trim().isEmpty?null:_ruhsatCtrl.text.trim(),
      adres:         _adresCtrl.text.trim().isEmpty?null:_adresCtrl.text.trim(),
      uavt:          _uavtCtrl.text.trim().isEmpty?null:_uavtCtrl.text.trim(),
      notlar:        _notlarCtrl.text.trim().isEmpty?null:_notlarCtrl.text.trim(),
    );
    await _db.guncelle(g);
    setState(()=>_p=g);
    setState(()=>_duzenleme=false);
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('✅ Bilgiler kaydedildi!'),backgroundColor:Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    if(_yukleniyor) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final p = _p!;
    final renk = _durumRengi(p.durum);
    final fmt  = DateFormat('d MMM y','tr');
    return Scaffold(
      appBar: AppBar(
        title: Text(p.tamAd, style:const TextStyle(fontWeight:FontWeight.w700)),
        centerTitle: true,
        actions: [
          if(_duzenleme)
            TextButton.icon(onPressed:_kaydet, icon:const Icon(Icons.save), label:const Text('Kaydet'))
          else
            IconButton(icon:const Icon(Icons.edit_outlined), onPressed:()=>setState(()=>_duzenleme=true)),
        ],
        bottom: TabBar(controller:_tc, tabs:const [
          Tab(icon:Icon(Icons.info_outline), text:'Bilgiler'),
          Tab(icon:Icon(Icons.picture_as_pdf), text:'PDF'),
          Tab(icon:Icon(Icons.notes), text:'Notlar'),
        ]),
      ),
      body: Column(
        children: [
          // Özet şerit
          Container(
            padding: const EdgeInsets.fromLTRB(14,10,14,10),
            color: renk.withOpacity(.07),
            child: Row(children:[
              Text(p.tur.emoji, style:const TextStyle(fontSize:26)),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${p.goruntulenenTur} – ${p.sirket}',
                    style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                Text('${fmt.format(p.bitisTarihi)} · ₺${NumberFormat('#,##0','tr').format(p.tutar)}',
                    style:TextStyle(fontSize:11,color:Colors.grey.shade600)),
              ])),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
                decoration:BoxDecoration(color:renk.withOpacity(.12),borderRadius:BorderRadius.circular(16),border:Border.all(color:renk.withOpacity(.3))),
                child: Text(_durumAdi(p.durum), style:TextStyle(color:renk,fontSize:10,fontWeight:FontWeight.w700)),
              ),
            ]),
          ),
          Expanded(child:TabBarView(controller:_tc,children:[
            _bilgiFormu(p),
            _pdfSekme(p),
            _notlarSekme(),
          ])),
        ],
      ),
    );
  }

  // ── TAB 1: Bilgi Formu ─────────────────────────────────────
  Widget _bilgiFormu(Police p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_duzenleme) ...[
            _sec('👤 Kişisel Bilgiler'),
            Row(children:[
              Expanded(child:_tf(_musteriAdiCtrl,'Ad *')),
              const SizedBox(width:10),
              Expanded(child:_tf(_soyadiCtrl,'Soyad *')),
            ]),
            const SizedBox(height:10),
            _tf(_telCtrl,'Telefon',tip:TextInputType.phone),
            const SizedBox(height:10),
            _tf(_emailCtrl,'E-posta',tip:TextInputType.emailAddress),
            const SizedBox(height:10),
            _tf(_tcCtrl,'TC Kimlik No',tip:TextInputType.number,max:11),
            const SizedBox(height:10),
            _tf(_dogumCtrl,'Doğum Tarihi (GG.AA.YYYY)'),
            const SizedBox(height:16),

            _sec('📋 Poliçe Bilgileri'),
            _tf(_sirketCtrl,'Sigorta Şirketi'),
            const SizedBox(height:10),
            _tf(_tutarCtrl,'Prim Tutarı (₺)',tip:TextInputType.number),
            const SizedBox(height:10),
            // Tür seçici
            DropdownButtonFormField<PoliceType>(
              value: _tur,
              isExpanded: true,
              decoration: InputDecoration(
                labelText:'Sigorta Türü',
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),
                contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
              ),
              items: PoliceType.values.map((t)=>DropdownMenuItem(
                value:t, child:Text('${t.emoji} ${t.adi}'))).toList(),
              onChanged: (v) => setState(()=>_tur=v!),
            ),
            if (_tur==PoliceType.diger) ...[
              const SizedBox(height:10),
              _tf(TextEditingController(text:_ozelTurAdi),'Özel Tür Adı'),
            ],
            const SizedBox(height:10),
            // Tarihler
            _tarihSec('Başlangıç Tarihi', _baslangicT, (d)=>setState(()=>_baslangicT=d)),
            const SizedBox(height:10),
            _tarihSec('Bitiş Tarihi *', _bitisT, (d)=>setState(()=>_bitisT=d)),
            const SizedBox(height:10),
            _tf(_belgeSeriCtrl,'Belge / Poliçe Seri No'),
            const SizedBox(height:16),

            // Araç (Kasko/Trafik)
            if (_tur.aracGerektiriyor) ...[
              _sec('🚗 Araç Bilgileri'),
              _tf(_plakaCtrl,'Araç Plakası'),
              const SizedBox(height:10),
              Row(children:[
                Expanded(child:_tf(_markaCtrl,'Marka')),
                const SizedBox(width:10),
                Expanded(child:_tf(_modelCtrl,'Model')),
              ]),
              const SizedBox(height:10),
              Row(children:[
                Expanded(child:_tf(_yilCtrl,'Yıl',tip:TextInputType.number,max:4)),
                const SizedBox(width:10),
                Expanded(child:_tf(_ruhsatCtrl,'Ruhsat Seri No')),
              ]),
              const SizedBox(height:16),
            ],

            // Konut/DASK
            if (_tur.adresGerektiriyor) ...[
              _sec('🏠 Konut Bilgileri'),
              _tf(_adresCtrl,'Sigortalı Adres',max:null,satir:2),
              const SizedBox(height:10),
              _tf(_uavtCtrl,'UAVT Kodu'),
              const SizedBox(height:16),
            ],

            FilledButton.icon(
              onPressed: _kaydet,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Değişiklikleri Kaydet',style:TextStyle(fontWeight:FontWeight.bold)),
              style: FilledButton.styleFrom(minimumSize:const Size.fromHeight(48)),
            ),
          ] else ...[
            // Sadece oku modu
            _bilgiKarti('👤 Müşteri', [
              _satir('Ad Soyad', p.tamAd),
              _satir('Telefon',  p.telefon),
              if(p.email!=null)     _satir('E-posta',   p.email!),
              if(p.tcKimlikNo!=null) _satir('TC Kimlik',p.tcKimlikNo!),
              if(p.dogumTarihi!=null)_satir('Doğum',    p.dogumTarihi!),
            ]),
            const SizedBox(height:10),
            _bilgiKarti('📋 Poliçe', [
              _satir('Tür',     '${p.tur.emoji} ${p.goruntulenenTur}'),
              _satir('Şirket',  p.sirket),
              _satir('Tutar',   '₺${NumberFormat('#,##0','tr').format(p.tutar)}'),
              _satir('Başlangıç',DateFormat('d MMM y','tr').format(p.baslangicTarihi)),
              _satir('Bitiş',  DateFormat('d MMM y','tr').format(p.bitisTarihi)),
              if(p.belgeSeriNo!=null) _satir('Belge No', p.belgeSeriNo!),
            ]),
            if(p.tur.aracGerektiriyor && (p.aracPlaka!=null||p.aracMarka!=null)) ...[
              const SizedBox(height:10),
              _bilgiKarti('🚗 Araç', [
                if(p.aracPlaka!=null)   _satir('Plaka',     p.aracPlaka!),
                if(p.aracMarka!=null)   _satir('Araç',      '${p.aracMarka} ${p.aracModel??""} ${p.aracYil??""}'),
                if(p.ruhsatSeriNo!=null)_satir('Ruhsat',    p.ruhsatSeriNo!),
              ]),
            ],
            if(p.tur.adresGerektiriyor && p.adres!=null) ...[
              const SizedBox(height:10),
              _bilgiKarti('🏠 Konut', [
                _satir('Adres', p.adres!),
                if(p.uavt!=null) _satir('UAVT', p.uavt!),
              ]),
            ],
            const SizedBox(height:12),
            OutlinedButton.icon(
              onPressed: ()=>setState(()=>_duzenleme=true),
              icon:const Icon(Icons.edit_outlined),
              label:const Text('Bilgileri Düzenle'),
              style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(44)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.only(bottom:8),
    child: Text(t,style:TextStyle(fontWeight:FontWeight.w800,fontSize:13,color:Theme.of(context).colorScheme.primary)),
  );

  Widget _tf(TextEditingController c, String l,
      {TextInputType? tip, int? max, int satir=1}) =>
    TextField(controller:c, keyboardType:tip, maxLength:max, maxLines:satir,
      decoration:InputDecoration(
        labelText:l, counterText:'',
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),
        contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
      ),
    );

  Widget _tarihSec(String l, DateTime? val, Function(DateTime) cb) {
    final fmt = DateFormat('d MMMM y','tr');
    return GestureDetector(
      onTap:() async {
        final t = await showDatePicker(
          context:context,
          initialDate:val??DateTime.now(),
          firstDate:DateTime(2000),
          lastDate:DateTime(2035),
        );
        if(t!=null) cb(t);
      },
      child:InputDecorator(
        decoration:InputDecoration(
          labelText:l, prefixIcon:const Icon(Icons.event_outlined),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),
          contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
        ),
        child:Text(val!=null?fmt.format(val):'Seçmek için tıkla',
            style:TextStyle(color:val!=null?Colors.black87:Colors.grey.shade500)),
      ),
    );
  }

  Widget _bilgiKarti(String baslik, List<Widget> satirlar) => Container(
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(12),
      border:Border.all(color:Colors.grey.shade200),
    ),
    child:Column(children:[
      Container(
        padding:const EdgeInsets.fromLTRB(14,10,14,8),
        decoration:BoxDecoration(
          color:Theme.of(context).colorScheme.primaryContainer.withOpacity(.3),
          borderRadius:const BorderRadius.vertical(top:Radius.circular(12)),
        ),
        child:Row(children:[
          Text(baslik,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)),
        ]),
      ),
      ...satirlar,
    ]),
  );

  Widget _satir(String e, String v) => Padding(
    padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
    child:Row(children:[
      SizedBox(width:110,child:Text(e,style:TextStyle(fontSize:12,color:Colors.grey.shade600))),
      Expanded(child:Text(v,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
    ]),
  );

  // ── TAB 2: PDF ─────────────────────────────────────────────
  Widget _pdfSekme(Police p) {
    return SingleChildScrollView(
      padding:const EdgeInsets.all(16),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          if(!p.pdfVarMi) ...[
            Center(child:Column(children:[
              const SizedBox(height:30),
              Icon(Icons.picture_as_pdf,size:64,color:Colors.red.shade200),
              const SizedBox(height:12),
              const Text('PDF dosyası eklenmemiş',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600)),
              const SizedBox(height:18),
              FilledButton.icon(
                onPressed:_pdfSec,
                icon:const Icon(Icons.upload_file),
                label:const Text('PDF Dosyası Ekle'),
                style:FilledButton.styleFrom(backgroundColor:Colors.red.shade600,
                    padding:const EdgeInsets.symmetric(horizontal:24,vertical:12)),
              ),
            ])),
          ] else ...[
            Container(
              padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:Colors.red.shade50,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.red.shade200)),
              child:Row(children:[
                const Icon(Icons.picture_as_pdf,size:40,color:Colors.red),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(p.pdfDosyaYolu!.split('/').last,style:const TextStyle(fontWeight:FontWeight.bold),overflow:TextOverflow.ellipsis),
                  Text('${p.tamAd} · ${p.goruntulenenTur}',style:TextStyle(fontSize:11,color:Colors.grey.shade600)),
                ])),
              ]),
            ),
            const SizedBox(height:14),
            Row(children:[
              Expanded(child:OutlinedButton.icon(
                onPressed:_pdfAc,
                icon:const Icon(Icons.open_in_new),
                label:const Text('Aç'),
                style:OutlinedButton.styleFrom(foregroundColor:Colors.red.shade700,side:BorderSide(color:Colors.red.shade600),padding:const EdgeInsets.symmetric(vertical:12)),
              )),
              const SizedBox(width:10),
              Expanded(child:FilledButton.icon(
                onPressed:_paylasimSheet,
                icon:const Icon(Icons.share),
                label:const Text('Paylaş'),
                style:FilledButton.styleFrom(backgroundColor:Colors.red.shade600,padding:const EdgeInsets.symmetric(vertical:12)),
              )),
            ]),
            const SizedBox(height:10),
            OutlinedButton.icon(
              onPressed:_pdfSec,
              icon:const Icon(Icons.swap_horiz),
              label:const Text('PDF\'yi Değiştir'),
              style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(42)),
            ),
            const SizedBox(height:20),
            const Text('Hızlı Paylaşım',style:TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height:10),
            Wrap(spacing:8,runSpacing:8,children:[
              _paylasBut('WhatsApp',Colors.green.shade600,_whatsapp),
              _paylasBut('E-posta',Colors.orange.shade600,_eposta),
              _paylasBut('SMS',Colors.teal.shade600,_sms),
              _paylasBut('Kaydet',Colors.purple.shade600,_kaydet2),
              _paylasBut('Diğer',Colors.blue.shade600,_genelPaylas),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _paylasBut(String l, Color c, VoidCallback fn) => InkWell(
    onTap:fn,
    borderRadius:BorderRadius.circular(10),
    child:Container(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
      decoration:BoxDecoration(color:c.withOpacity(.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:c.withOpacity(.25))),
      child:Text(l,style:TextStyle(color:c,fontWeight:FontWeight.w700,fontSize:12)),
    ),
  );

  // ── TAB 3: Notlar ──────────────────────────────────────────
  Widget _notlarSekme() => SingleChildScrollView(
    padding:const EdgeInsets.all(16),
    child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          const Text('Genel Notlar',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
          TextButton.icon(
            onPressed:()=>setState(()=>_duzenleme=!_duzenleme),
            icon:Icon(_duzenleme?Icons.save_outlined:Icons.edit_outlined),
            label:Text(_duzenleme?'Kaydet':'Düzenle'),
          ),
        ]),
        const SizedBox(height:10),
        _duzenleme
            ? TextField(controller:_notlarCtrl,maxLines:12,
                decoration:InputDecoration(hintText:'Notları yaz…',border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),filled:true))
            : Container(
                width:double.infinity,
                padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(color:Colors.grey.shade50,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.grey.shade200)),
                child:Text(
                  _notlarCtrl.text.isEmpty?'Henüz not eklenmemiş.':_notlarCtrl.text,
                  style:TextStyle(color:_notlarCtrl.text.isEmpty?Colors.grey.shade400:null,height:1.6),
                ),
              ),
      ],
    ),
  );

  // ── PDF işlemleri ──────────────────────────────────────────
  Future<void> _pdfSec() async {
    final r = await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['pdf'],dialogTitle:'Poliçe PDF seçin');
    if(r==null||r.files.single.path==null) return;
    await _db.pdfYolu(widget.policeId, r.files.single.path!);
    setState(()=>_p=_p!.copyWith(pdfDosyaYolu:r.files.single.path!));
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('📄 PDF eklendi!'),backgroundColor:Colors.green));
  }

  Future<void> _pdfAc() async {
    if(_p?.pdfDosyaYolu==null) return;
    if(!await File(_p!.pdfDosyaYolu!).exists()) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('⚠️ Dosya bulunamadı!'),backgroundColor:Colors.orange));
      return;
    }
    await OpenFilex.open(_p!.pdfDosyaYolu!);
  }

  void _paylasimSheet() {
    showModalBottomSheet(
      context:context,backgroundColor:Colors.transparent,
      builder:(_)=>Container(
        margin:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24)),
        padding:const EdgeInsets.all(20),
        child:Column(
          mainAxisSize:MainAxisSize.min,
          children:[
            const Text('Paylaşım Seçenekleri',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
            const SizedBox(height:16),
            GridView.count(
              crossAxisCount:4,shrinkWrap:true,mainAxisSpacing:12,crossAxisSpacing:8,
              children:[
                _modalItem(Icons.message,'WhatsApp',Colors.green,_whatsapp),
                _modalItem(Icons.mail_outline,'E-posta',Colors.orange,_eposta),
                _modalItem(Icons.sms_outlined,'SMS',Colors.teal,_sms),
                _modalItem(Icons.download_outlined,'Kaydet',Colors.purple,_kaydet2),
                _modalItem(Icons.share,'Diğer',Colors.blue,_genelPaylas),
                _modalItem(Icons.picture_as_pdf,'Aç',Colors.red,(){Navigator.pop(context);_pdfAc();}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalItem(IconData icon, String l, Color c, VoidCallback fn) => GestureDetector(
    onTap:(){Navigator.pop(context);fn();},
    child:Column(children:[
      Container(width:52,height:52,decoration:BoxDecoration(color:c.withOpacity(.1),borderRadius:BorderRadius.circular(14),border:Border.all(color:c.withOpacity(.2))),child:Icon(icon,color:c,size:24)),
      const SizedBox(height:4),
      Text(l,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w600)),
    ]),
  );

  String get _mesaj {
    final fmt = DateFormat('d MMMM y','tr');
    return '🛡️ Sayın ${_p!.tamAd},\n${_p!.goruntulenenTur} poliçeniz ${fmt.format(_p!.bitisTarihi)} tarihinde sona erecektir.\nYenileme için lütfen iletişime geçiniz.';
  }

  Future<void> _whatsapp()    async => Share.shareXFiles([XFile(_p!.pdfDosyaYolu!)],text:_mesaj);
  Future<void> _genelPaylas() async => Share.shareXFiles([XFile(_p!.pdfDosyaYolu!)],text:_mesaj);
  Future<void> _kaydet2()     async => Share.shareXFiles([XFile(_p!.pdfDosyaYolu!)],text:'Telefona kaydetmek için "Dosyalara Kaydet" seçin');
  Future<void> _eposta()      async {
    final uri = Uri(scheme:'mailto',path:_p!.email??'',queryParameters:{'subject':'Poliçe Belgesi','body':_mesaj});
    if(await canLaunchUrl(uri)) launchUrl(uri);
  }
  Future<void> _sms()         async {
    final uri = Uri(scheme:'sms',path:_p!.telefon,queryParameters:{'body':_mesaj});
    if(await canLaunchUrl(uri)) launchUrl(uri);
  }

  Color  _durumRengi(PoliceStatus d) => switch(d){PoliceStatus.yapildi=>Colors.green.shade600,PoliceStatus.yapilamadi=>Colors.red.shade600,PoliceStatus.dahaSonra=>Colors.orange.shade700,_=>Colors.blue.shade400};
  String _durumAdi(PoliceStatus d)   => switch(d){PoliceStatus.yapildi=>'✓ Yapıldı',PoliceStatus.yapilamadi=>'✗ Yapılamadı',PoliceStatus.dahaSonra=>'◷ Daha Sonra',_=>'⏳ Beklemede'};
}
