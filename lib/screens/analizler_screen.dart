// ============================================================
// lib/screens/analizler_screen.dart  –  v3
// Detaylı analizler:
//   • Seçilebilir dönem (1–12 ay)
//   • Aylık üretim karşılaştırması
//   • Yüzdesel başarı/başarısız grafikler
//   • Tür dağılımı, şirket bazlı performans
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';

class AnalizlerScreen extends StatefulWidget {
  const AnalizlerScreen({super.key});
  @override
  State<AnalizlerScreen> createState() => _AnalizlerScreenState();
}

class _AnalizlerScreenState extends State<AnalizlerScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabCtrl;

  int _yil = DateTime.now().year;
  int _donem = 6; // kaç ay
  List<Map<String,dynamic>> _veri = [];
  bool _yukleniyor = true;

  final _donemler = [1,2,3,6,12];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final simdiAy = DateTime.now().month;
    final bas = (simdiAy - _donem + 1).clamp(1, 12);
    final bit = simdiAy;
    final v = await _db.aralikAnaliz(_yil, bas, bit);
    setState(() { _veri = v; _yukleniyor = false; });
  }

  // ── Hesaplama yardımcıları ─────────────────────────────
  int get _toplamPolice     => _veri.fold(0,(s,r)=>s+(r['toplam']as int));
  int get _toplamYapildi    => _veri.fold(0,(s,r)=>s+(r['yapildi']as int));
  int get _toplamYapilamadi => _veri.fold(0,(s,r)=>s+(r['yapilamadi']as int));
  double get _toplamGelir   => _veri.fold(0.0,(s,r)=>s+(r['gelir']as double));
  double get _basariOrani   => _toplamPolice>0 ? _toplamYapildi/_toplamPolice*100 : 0;

  double get _toplamKomisyon => _veri.fold(0.0,(s,r)=>s+(r['komisyon']as double? ?? 0.0));

  String get _paraFmt => NumberFormat.currency(locale:'tr',symbol:'₺',decimalDigits:0).format(_toplamGelir);
  String get _komisyonFmt => NumberFormat.currency(locale:'tr',symbol:'₺',decimalDigits:0).format(_toplamKomisyon);

  static const List<Color> _ayRenkleri = [
    Color(0xFF1565C0),Color(0xFF1E88E5),Color(0xFF42A5F5),
    Color(0xFF66BB6A),Color(0xFF2E7D32),Color(0xFF81C784),
    Color(0xFFE65100),Color(0xFFFF7043),Color(0xFFFFA726),
    Color(0xFF7B1FA2),Color(0xFF9C27B0),Color(0xFFBA68C8),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Analizler', style: TextStyle(fontWeight:FontWeight.w800)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Özet'),
            Tab(text: 'Üretim'),
            Tab(text: 'Başarı'),
            Tab(text: 'Karşılaştır'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Dönem Seçici ──────────────────────────────
          Container(
            color: context.bgScaffold,
            padding: const EdgeInsets.symmetric(horizontal:12, vertical:10),
            child: Row(
              children: [
                const Text('Dönem:', style:TextStyle(fontWeight:FontWeight.w700, fontSize:13)),
                const SizedBox(width:10),
                ..._donemler.map((d) => Padding(
                  padding: const EdgeInsets.only(right:6),
                  child: ChoiceChip(
                    label: Text(d==12?'1 Yıl':'$d Ay'),
                    selected: _donem==d,
                    onSelected: (_) { setState(()=>_donem=d); _yukle(); },
                    selectedColor: scheme.primary,
                    labelStyle: TextStyle(
                      color: _donem==d ? Colors.white : null,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                )),
                const Spacer(),
                Text(_yil.toString(),
                    style:TextStyle(fontWeight:FontWeight.w800,color:scheme.primary)),
              ],
            ),
          ),
          // ── İçerik ────────────────────────────────────
          Expanded(
            child: _yukleniyor
                ? const Center(child:CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _ozet(),
                      _uretimGrafigi(),
                      _basariGrafigi(),
                      _karsilastirma(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: ÖZET ───────────────────────────────────────────
  Widget _ozet() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // KPI Grid
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _kpiKarti('📋','Toplam','$_toplamPolice poliçe', Colors.blue),
            _kpiKarti('✅','Yapılan','$_toplamYapildi poliçe', Colors.green),
            _kpiKarti('💰','Toplam Prim',_paraFmt, Colors.orange),
            _kpiKarti('📈','Komisyon',_komisyonFmt, Colors.purple),
          ],
        ),
        const SizedBox(height:12),
        // Başarı oranı ayrı kart
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (_basariOrani>=70?Colors.green:_basariOrani>=40?Colors.orange:Colors.red).withOpacity(.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (_basariOrani>=70?Colors.green:_basariOrani>=40?Colors.orange:Colors.red).withOpacity(.2)),
          ),
          child: Row(children: [
            const Text('📊', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Başarı Oranı', style: TextStyle(fontSize: 11, color: context.textSub)),
              Text('${_basariOrani.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: _basariOrani>=70?Colors.green.shade700:_basariOrani>=40?Colors.orange.shade700:Colors.red.shade700)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$_toplamYapildi / $_toplamPolice',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textMain)),
              Text('yapıldı / toplam', style: TextStyle(fontSize: 10, color: context.textSub)),
            ]),
          ]),
        ),
        const SizedBox(height:16),

        // Özet grafik (Pasta)
        _kartBaslikli('🥧 Durum Dağılımı', _pastaGrafik()),
        const SizedBox(height:12),

        // Aylık mini tablo
        _kartBaslikli('📅 Aylık Özet Tablosu', _aylikTablo()),
      ],
    );
  }

  Widget _kpiKarti(String emoji, String baslik, String deger, Color renk) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renk.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color:renk.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style:TextStyle(fontSize:22)),
          const Spacer(),
          Text(deger, style:TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:renk)),
          Text(baslik, style:TextStyle(fontSize:11,color:context.textSub)),
        ],
      ),
    );
  }

  Widget _pastaGrafik() {
    if (_veri.isEmpty) return const SizedBox(height:120, child:Center(child:Text('Veri yok')));
    final yap  = _toplamYapildi.toDouble();
    final yap2 = _toplamYapilamadi.toDouble();
    final bekl = _veri.fold(0,(s,r)=>s+(r['beklemede']as int)).toDouble();
    final son  = _veri.fold(0,(s,r)=>s+(r['dahaSonra']as int)).toDouble();
    final top  = yap+yap2+bekl+son;
    if(top==0) return const SizedBox(height:80,child:Center(child:Text('Henüz veri yok')));

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(PieChartData(
              sections: [
                if(yap>0)  PieChartSectionData(value:yap, color:Colors.green.shade600, title:'${(yap/top*100).toStringAsFixed(0)}%', titleStyle:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold), radius:70),
                if(yap2>0) PieChartSectionData(value:yap2, color:Colors.red.shade600, title:'${(yap2/top*100).toStringAsFixed(0)}%', titleStyle:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold), radius:70),
                if(bekl>0) PieChartSectionData(value:bekl, color:Colors.blue.shade400, title:'${(bekl/top*100).toStringAsFixed(0)}%', titleStyle:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold), radius:70),
                if(son>0)  PieChartSectionData(value:son, color:Colors.orange.shade600, title:'${(son/top*100).toStringAsFixed(0)}%', titleStyle:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold), radius:70),
              ],
              centerSpaceRadius: 30,
            )),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lejantItem(Colors.green.shade600, 'Yapıldı: ${yap.toInt()}'),
              _lejantItem(Colors.red.shade600,   'Yapılamadı: ${yap2.toInt()}'),
              _lejantItem(Colors.blue.shade400,  'Beklemede: ${bekl.toInt()}'),
              _lejantItem(Colors.orange.shade600,'Daha Sonra: ${son.toInt()}'),
            ],
          ),
          const SizedBox(width:8),
        ],
      ),
    );
  }

  Widget _lejantItem(Color c, String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical:3),
    child: Row(children:[
      Container(width:10,height:10,decoration:BoxDecoration(color:c,shape:BoxShape.circle)),
      const SizedBox(width:6),
      Text(t,style:const TextStyle(fontSize:11)),
    ]),
  );

  Widget _aylikTablo() {
    if(_veri.isEmpty) return const Text('Veri yok');
    const ay = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    return Column(
      children: [
        // Başlık
        Row(children: [
          _hucre('Ay', bold:true, flex:1),
          _hucre('Top.', bold:true),
          _hucre('Yap.', bold:true, renk:Colors.green.shade700),
          _hucre('Prim', bold:true, renk:Colors.orange.shade700, flex:2),
          _hucre('Kom.', bold:true, renk:Colors.purple.shade700, flex:2),
        ]),
        const Divider(height:1),
        ..._veri.map((r) {
          final top = r['toplam'] as int;
          final yap = r['yapildi'] as int;
          final g = r['gelir'] as double;
          final k = r['komisyon'] as double? ?? 0.0;
          return Row(children: [
            _hucre(ay[r['ay'] as int], bold:true, flex:1),
            _hucre('$top'),
            _hucre('$yap', renk:Colors.green.shade700),
            _hucre(g>=1000?'${(g/1000).toStringAsFixed(1)}K':'${g.toInt()}',
                renk:Colors.orange.shade700, flex:2),
            _hucre(k>=1000?'${(k/1000).toStringAsFixed(1)}K':'${k.toInt()}',
                renk:Colors.purple.shade700, flex:2),
          ]);
        }),
      ],
    );
  }

  Widget _hucre(String t, {bool bold=false, Color? renk, int flex=1}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical:7,horizontal:4),
      child: Text(t, textAlign:TextAlign.center,
          style:TextStyle(fontSize:11,fontWeight:bold?FontWeight.w800:FontWeight.w500,color:renk)),
    ),
  );

  // ── TAB 2: ÜRETİM GRAFİĞİ ────────────────────────────────
  Widget _uretimGrafigi() {
    if(_veri.isEmpty) return const Center(child:Text('Veri yok'));
    const aylar = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _kartBaslikli(
          '📊 Aylık Toplam Poliçe Sayısı',
          SizedBox(
            height: 220,
            child: BarChart(BarChartData(
              barGroups: _veri.asMap().entries.map((e) {
                final r = e.value;
                final yap  = (r['yapildi']   as int).toDouble();
                final yap2 = (r['yapilamadi'] as int).toDouble();
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(toY:yap,  color:Colors.green.shade600, width:10, borderRadius:BorderRadius.circular(4)),
                    BarChartRodData(toY:yap2, color:Colors.red.shade500,   width:10, borderRadius:BorderRadius.circular(4)),
                  ],
                  showingTooltipIndicators: [],
                );
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v,_) {
                    final idx = v.toInt();
                    if(idx<0||idx>=_veri.length) return const SizedBox();
                    return Text(aylar[_veri[idx]['ay']as int], style:const TextStyle(fontSize:9));
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, reservedSize:24,
                    getTitlesWidget:(v,_)=>Text(v.toInt().toString(),style:const TextStyle(fontSize:9)))),
                rightTitles: const AxisTitles(sideTitles:SideTitles(showTitles:false)),
                topTitles:   const AxisTitles(sideTitles:SideTitles(showTitles:false)),
              ),
              borderData: FlBorderData(show:false),
              gridData: FlGridData(drawVerticalLine:false),
            )),
          ),
        ),
        const SizedBox(height:12),
        _kartBaslikli(
          '💰 Aylık Gelir (₺)',
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), (e.value['gelir']as double)/1000)
                  ).toList(),
                  isCurved: true,
                  color: Colors.orange.shade700,
                  barWidth: 3,
                  dotData: const FlDotData(show:true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.orange.shade700.withOpacity(.1),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v,_) {
                    final idx = v.toInt();
                    if(idx<0||idx>=_veri.length) return const SizedBox();
                    return Text(aylar[_veri[idx]['ay']as int], style:const TextStyle(fontSize:9));
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, reservedSize:30,
                    getTitlesWidget:(v,_)=>Text('${v.toStringAsFixed(0)}K',style:const TextStyle(fontSize:9)))),
                rightTitles: const AxisTitles(sideTitles:SideTitles(showTitles:false)),
                topTitles:   const AxisTitles(sideTitles:SideTitles(showTitles:false)),
              ),
              borderData: FlBorderData(show:false),
              gridData: const FlGridData(drawVerticalLine:false),
            )),
          ),
        ),
        const SizedBox(height:12),
        // Lejant
        Row(children:[
          _lejantItem(Colors.green.shade600, 'Yapılan'),
          const SizedBox(width:16),
          _lejantItem(Colors.red.shade500, 'Yapılamayan'),
          const SizedBox(width:16),
          _lejantItem(Colors.orange.shade700, 'Gelir'),
        ]),
      ],
    );
  }

  // ── TAB 3: BAŞARI GRAFİĞİ ─────────────────────────────────
  Widget _basariGrafigi() {
    if(_veri.isEmpty) return const Center(child:Text('Veri yok'));
    const aylar = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _kartBaslikli(
          '📈 Aylık Başarı Oranı (%)',
          SizedBox(
            height: 220,
            child: BarChart(BarChartData(
              maxY: 100,
              barGroups: _veri.asMap().entries.map((e) {
                final r   = e.value;
                final top = r['toplam'] as int;
                final yap = r['yapildi'] as int;
                final oran = top>0 ? yap/top*100 : 0.0;
                final renk = oran>=70 ? Colors.green.shade600
                           : oran>=40 ? Colors.orange.shade600
                           : Colors.red.shade600;
                return BarChartGroupData(x:e.key, barRods:[
                  BarChartRodData(
                    toY: oran,
                    color: renk,
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    rodStackItems: [],
                  ),
                ]);
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v,_) {
                    final i = v.toInt();
                    if(i<0||i>=_veri.length) return const SizedBox();
                    return Text(aylar[_veri[i]['ay']as int],style:const TextStyle(fontSize:9));
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, reservedSize:28,
                    getTitlesWidget:(v,_)=>Text('${v.toInt()}%',style:const TextStyle(fontSize:9)))),
                rightTitles: const AxisTitles(sideTitles:SideTitles(showTitles:false)),
                topTitles:   const AxisTitles(sideTitles:SideTitles(showTitles:false)),
              ),
              borderData: FlBorderData(show:false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color:Colors.grey.withOpacity(.15), strokeWidth:1),
              ),
            )),
          ),
        ),
        const SizedBox(height:12),
        // Yüzdesel özet kartları
        Row(children:[
          Expanded(child:_yuzdKarti('Ortalama Başarı', '${_basariOrani.toStringAsFixed(1)}%',
              _basariOrani>=70?Colors.green:_basariOrani>=40?Colors.orange:Colors.red)),
          const SizedBox(width:10),
          Expanded(child:_yuzdKarti('Kayıp Oran',
              '${(_toplamPolice>0?_toplamYapilamadi/_toplamPolice*100:0).toStringAsFixed(1)}%',
              Colors.red)),
        ]),
        const SizedBox(height:12),
        _kartBaslikli(
          '📊 Yapılan vs Yapılamayan',
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              barGroups: _veri.asMap().entries.map((e) {
                final r    = e.value;
                final top  = r['toplam']    as int;
                final yap  = r['yapildi']   as int;
                final yap2 = r['yapilamadi'] as int;
                final yOran  = top>0?yap/top*100.0:0.0;
                final y2Oran = top>0?yap2/top*100.0:0.0;
                return BarChartGroupData(x:e.key, barsSpace:4, barRods:[
                  BarChartRodData(toY:yOran,  color:Colors.green.shade600, width:12, borderRadius:BorderRadius.circular(4)),
                  BarChartRodData(toY:y2Oran, color:Colors.red.shade500,   width:12, borderRadius:BorderRadius.circular(4)),
                ]);
              }).toList(),
              maxY: 100,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles:true,
                    getTitlesWidget:(v,_){final i=v.toInt();if(i<0||i>=_veri.length)return const SizedBox();return Text(aylar[_veri[i]['ay']as int],style:const TextStyle(fontSize:9));})),
                leftTitles: AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:28,getTitlesWidget:(v,_)=>Text('${v.toInt()}%',style:const TextStyle(fontSize:9)))),
                rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
                topTitles:  const AxisTitles(sideTitles:SideTitles(showTitles:false)),
              ),
              borderData:FlBorderData(show:false),
            )),
          ),
        ),
      ],
    );
  }

  Widget _yuzdKarti(String baslik, String deger, Color renk) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: renk.withOpacity(.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color:renk.withOpacity(.2)),
    ),
    child: Column(
      children: [
        Text(deger,style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:renk)),
        Text(baslik,style:TextStyle(fontSize:11,color:context.textSub)),
      ],
    ),
  );

  // ── TAB 4: KARŞILAŞTIRMA ──────────────────────────────────
  Widget _karsilastirma() {
    if(_veri.length<2) return const Center(child:Text('En az 2 aylık veri gerekli'));
    const aylar = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _kartBaslikli(
          '📈 Üretim Trendi (Toplam)',
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), (e.value['toplam']as int).toDouble())
                  ).toList(),
                  isCurved: true,
                  color: Colors.blue.shade600,
                  barWidth: 3,
                  dotData: const FlDotData(show:true),
                  belowBarData: BarAreaData(show:true,color:Colors.blue.shade600.withOpacity(.08)),
                ),
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), (e.value['yapildi']as int).toDouble())
                  ).toList(),
                  isCurved: true,
                  color: Colors.green.shade600,
                  barWidth: 2,
                  dotData: const FlDotData(show:true),
                ),
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), (e.value['yapilamadi']as int).toDouble())
                  ).toList(),
                  isCurved: true,
                  color: Colors.red.shade500,
                  barWidth: 2,
                  dashArray: [5,5],
                  dotData: const FlDotData(show:true),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles:true,
                    getTitlesWidget:(v,_){final i=v.toInt();if(i<0||i>=_veri.length)return const SizedBox();return Text(aylar[_veri[i]['ay']as int],style:const TextStyle(fontSize:9));})),
                leftTitles:  AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:22,getTitlesWidget:(v,_)=>Text(v.toInt().toString(),style:const TextStyle(fontSize:9)))),
                rightTitles: const AxisTitles(sideTitles:SideTitles(showTitles:false)),
                topTitles:   const AxisTitles(sideTitles:SideTitles(showTitles:false)),
              ),
              borderData:FlBorderData(show:false),
              gridData:FlGridData(drawVerticalLine:false),
            )),
          ),
        ),
        const SizedBox(height:8),
        Row(children:[
          _lejantItem(Colors.blue.shade600,'Toplam'),
          const SizedBox(width:14),
          _lejantItem(Colors.green.shade600,'Yapılan'),
          const SizedBox(width:14),
          _lejantItem(Colors.red.shade500,'Yapılamayan'),
        ]),
        const SizedBox(height:14),

        // En iyi / en kötü ay
        _kartBaslikli('🏆 Performans Özeti', _performansOzet(aylar)),
      ],
    );
  }

  Widget _performansOzet(List<String> aylar) {
    if(_veri.isEmpty) return const SizedBox();
    final sorted = [..._veri]..sort((a,b)=>
        (b['yapildi']as int).compareTo(a['yapildi']as int));
    final enIyi  = sorted.first;
    final enKotu = sorted.last;
    final enYuksekGelir = [..._veri]..sort((a,b)=>(b['gelir']as double).compareTo(a['gelir']as double));

    return Column(
      children: [
        _performansSatiri('🏆 En İyi Ay', aylar[enIyi['ay']as int],
            '${enIyi["yapildi"]} yapılan', Colors.green),
        _performansSatiri('📉 En Düşük Ay', aylar[enKotu['ay']as int],
            '${enKotu["yapildi"]} yapılan', Colors.red),
        _performansSatiri('💰 En Yüksek Gelir',
            aylar[enYuksekGelir.first['ay']as int],
            '₺${NumberFormat('#,###','tr').format(enYuksekGelir.first['gelir'])}',
            Colors.orange),
      ],
    );
  }

  Widget _performansSatiri(String etiket, String ay, String deger, Color renk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical:6),
      child: Row(children:[
        Text(etiket,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal:10,vertical:4),
          decoration: BoxDecoration(color:renk.withOpacity(.1),borderRadius:BorderRadius.circular(8)),
          child: Text('$ay · $deger',style:TextStyle(color:renk,fontSize:12,fontWeight:FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _kartBaslikli(String baslik, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color:Colors.black.withOpacity(.05),blurRadius:8,offset:const Offset(0,2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik,style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:context.textMain)),
          const SizedBox(height:12),
          child,
        ],
      ),
    );
  }
}
