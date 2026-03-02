// lib/screens/police_form_screen.dart – v3
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class PoliceFormScreen extends StatefulWidget {
  final Police? police;
  const PoliceFormScreen({super.key, this.police});
  @override State<PoliceFormScreen> createState() => _PoliceFormScreenState();
}
class _PoliceFormScreenState extends State<PoliceFormScreen> {
  final _db=DatabaseService(); final _notif=NotificationService();
  final _fk=GlobalKey<FormState>();
  final _adC=TextEditingController(),_sC=TextEditingController(),_tC=TextEditingController(),
    _eC=TextEditingController(),_tcC=TextEditingController(),_dC=TextEditingController(),
    _siC=TextEditingController(),_tuC=TextEditingController(),_bsC=TextEditingController(),
    _plC=TextEditingController(),_maC=TextEditingController(),_moC=TextEditingController(),
    _yC=TextEditingController(),_rC=TextEditingController(),_adrC=TextEditingController(),
    _uvC=TextEditingController(),_nC=TextEditingController(),_otC=TextEditingController();
  PoliceType _tur=PoliceType.trafik;
  DateTime _bas=DateTime.now(),_bit=DateTime.now().add(const Duration(days:365));
  bool _busy=false;

  @override void initState(){super.initState();final p=widget.police;if(p!=null){_adC.text=p.musteriAdi;_sC.text=p.soyadi;_tC.text=p.telefon;_eC.text=p.email??'';_tcC.text=p.tcKimlikNo??'';_dC.text=p.dogumTarihi??'';_siC.text=p.sirket;_tuC.text=p.tutar==0?'':p.tutar.toStringAsFixed(0);_bsC.text=p.belgeSeriNo??'';_plC.text=p.aracPlaka??'';_maC.text=p.aracMarka??'';_moC.text=p.aracModel??'';_yC.text=p.aracYil??'';_rC.text=p.ruhsatSeriNo??'';_adrC.text=p.adres??'';_uvC.text=p.uavt??'';_nC.text=p.notlar??'';_otC.text=p.ozelTurAdi??'';_tur=p.tur;_bas=p.baslangicTarihi;_bit=p.bitisTarihi;}}
  @override void dispose(){for(final c in [_adC,_sC,_tC,_eC,_tcC,_dC,_siC,_tuC,_bsC,_plC,_maC,_moC,_yC,_rC,_adrC,_uvC,_nC,_otC])c.dispose();super.dispose();}

  Future<void> _kaydet() async {
    if(!_fk.currentState!.validate()) return;
    setState(()=>_busy=true);
    final p=Police(id:widget.police?.id,musteriAdi:_adC.text.trim(),soyadi:_sC.text.trim(),telefon:_tC.text.trim(),email:_eC.text.trim().isEmpty?null:_eC.text.trim(),tcKimlikNo:_tcC.text.trim().isEmpty?null:_tcC.text.trim(),dogumTarihi:_dC.text.trim().isEmpty?null:_dC.text.trim(),sirket:_siC.text.trim(),tur:_tur,ozelTurAdi:_tur==PoliceType.diger?_otC.text.trim():null,baslangicTarihi:_bas,bitisTarihi:_bit,tutar:double.tryParse(_tuC.text.replaceAll(',','.'))??0,belgeSeriNo:_bsC.text.trim().isEmpty?null:_bsC.text.trim(),durum:PoliceStatus.beklemede,olusturmaTarihi:DateTime.now(),aracPlaka:_plC.text.trim().isEmpty?null:_plC.text.trim().toUpperCase(),aracMarka:_maC.text.trim().isEmpty?null:_maC.text.trim(),aracModel:_moC.text.trim().isEmpty?null:_moC.text.trim(),aracYil:_yC.text.trim().isEmpty?null:_yC.text.trim(),ruhsatSeriNo:_rC.text.trim().isEmpty?null:_rC.text.trim(),adres:_adrC.text.trim().isEmpty?null:_adrC.text.trim(),uavt:_uvC.text.trim().isEmpty?null:_uvC.text.trim(),notlar:_nC.text.trim().isEmpty?null:_nC.text.trim());
    int savedId;
    if(widget.police==null) {
      savedId = await _db.ekle(p);
    } else {
      savedId = p.id!;
      await _db.guncelle(p);
    }
    final pWithId = p.copyWith(id: savedId);
    await _notif.policeIcinBildirimler(pWithId);
    setState(()=>_busy=false);
    if(!mounted) return;
    Navigator.pop(context,true);
  }

  Widget _tarihSec(String l,DateTime val,Function(DateTime) cb)=>GestureDetector(
    onTap:()async{final t=await showDatePicker(context:context,initialDate:val,firstDate:DateTime(2000),lastDate:DateTime(2040));if(t!=null)setState(()=>cb(t));},
    child:InputDecorator(decoration:InputDecoration(labelText:l,prefixIcon:const Icon(Icons.event_outlined),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12)),
      child:Text(DateFormat('d MMMM y','tr').format(val))));

  Widget _tf(TextEditingController c,String l,{bool req=false,TextInputType? t,int? max,int rows=1,String? hint})=>TextFormField(controller:c,keyboardType:t,maxLength:max,maxLines:rows,decoration:InputDecoration(labelText:l,hintText:hint,counterText:'',border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12)),validator:req?(v)=>v==null||v.trim().isEmpty?'$l zorunlu':null:null);
  Widget _sec(String t)=>Padding(padding:const EdgeInsets.only(bottom:8,top:4),child:Text(t,style:TextStyle(fontWeight:FontWeight.w800,fontSize:13,color:Theme.of(context).colorScheme.primary)));

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    appBar:AppBar(title:Text(widget.police==null?'Yeni Poliçe':'Poliçeyi Düzenle',style:const TextStyle(fontWeight:FontWeight.w700)),centerTitle:true),
    body:Form(key:_fk,child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _sec('👤 Müşteri Bilgileri'),
      Row(children:[Expanded(child:_tf(_adC,'Ad *',req:true)),const SizedBox(width:10),Expanded(child:_tf(_sC,'Soyad *',req:true))]),const SizedBox(height:10),
      _tf(_tC,'Telefon *',req:true,t:TextInputType.phone),const SizedBox(height:10),
      _tf(_eC,'E-posta',t:TextInputType.emailAddress),const SizedBox(height:10),
      _tf(_tcC,'TC Kimlik No',t:TextInputType.number,max:11),const SizedBox(height:10),
      _tf(_dC,'Doğum Tarihi',hint:'01.01.1990'),const SizedBox(height:16),
      _sec('📋 Poliçe Bilgileri'),
      _tf(_siC,'Sigorta Şirketi *',req:true),const SizedBox(height:10),
      _tf(_tuC,'Prim Tutarı (₺) *',req:true,t:TextInputType.number),const SizedBox(height:10),
      DropdownButtonFormField<PoliceType>(value:_tur,isExpanded:true,
        decoration:InputDecoration(labelText:'Sigorta Türü *',border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12)),
        items:PoliceType.values.map((t)=>DropdownMenuItem(value:t,child:Text('${t.emoji} ${t.adi}'))).toList(),
        onChanged:(v)=>setState(()=>_tur=v!)),
      if(_tur==PoliceType.diger)...[const SizedBox(height:10),_tf(_otC,'Özel Tür Adı *',req:true)],
      const SizedBox(height:10),
      _tarihSec('Başlangıç Tarihi',_bas,(d)=>_bas=d),const SizedBox(height:10),
      _tarihSec('Bitiş Tarihi *',_bit,(d)=>_bit=d),const SizedBox(height:10),
      _tf(_bsC,'Belge / Poliçe Seri No'),const SizedBox(height:16),
      if(_tur.aracGerektiriyor)...[
        _sec('🚗 Araç Bilgileri'),
        _tf(_plC,'Plaka'),const SizedBox(height:10),
        Row(children:[Expanded(child:_tf(_maC,'Marka')),const SizedBox(width:10),Expanded(child:_tf(_moC,'Model'))]),const SizedBox(height:10),
        Row(children:[Expanded(child:_tf(_yC,'Yıl',t:TextInputType.number,max:4)),const SizedBox(width:10),Expanded(child:_tf(_rC,'Ruhsat Seri'))]),const SizedBox(height:16),
      ],
      if(_tur.adresGerektiriyor)...[
        _sec('🏠 Konut Bilgileri'),
        _tf(_adrC,'Sigortalı Adres',rows:2),const SizedBox(height:10),
        _tf(_uvC,'UAVT Kodu'),const SizedBox(height:16),
      ],
      _sec('📝 Not'),
      _tf(_nC,'Notlar (isteğe bağlı)',rows:3),const SizedBox(height:24),
      FilledButton.icon(onPressed:_busy?null:_kaydet,
        icon:_busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_outlined),
        label:const Text('Kaydet',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
        style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52))),
      const SizedBox(height:20),
    ]))),
  );
}
