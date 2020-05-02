import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/model/Destino.dart';
import 'package:uber/model/Marcador.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class PainelPassageiro extends StatefulWidget {
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  String _idRequisicao;
  TextEditingController _controllerDestino = TextEditingController();
  List<String> itensMenu = ["Configurações", "Deslogar"];
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
  CameraPosition(target: LatLng(-23.563999, -46.653256));
  Set<Marker> _marcadores = {};
  //controles para exibição na tela
  bool _exibirCaixaEnderecoDeestino = true;
  String _textoBotao = "Chamar Uber";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  Position _localPassageiro;
  Map<String,dynamic> _dadosRequisicao;
  StreamSubscription<DocumentSnapshot> _streamSubscriptionRequisicoes;

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
          Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);
      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }
  _chamarUber() async {

    String enderecoDestino = _controllerDestino.text;
    if( enderecoDestino.isNotEmpty ){
      List<Placemark> listaEnderecos = await Geolocator()
          .placemarkFromAddress(enderecoDestino);

      if(listaEnderecos != null && listaEnderecos.length>0){
        Placemark endereco = listaEnderecos[0];
        Destino destino = Destino();
        destino.cidade = endereco.administrativeArea;
        destino.cep = endereco.postalCode;
        destino.bairro = endereco.subLocality;
        destino.rua = endereco.thoroughfare;
        destino.numero = endereco.subThoroughfare;

        destino.latitude = endereco.position.latitude;
        destino.longitude = endereco.position.longitude;

        String enderecoConfirmacao;
        enderecoConfirmacao = "\n Cidade: " + destino.cidade;
        enderecoConfirmacao += "\n Rua: " + destino.rua + ", " + destino.numero;
        enderecoConfirmacao += "\n Bairro: " + destino.bairro;
        enderecoConfirmacao += "\n CEP: " + destino.cep;

        showDialog(
            context: context,
          builder: (context){
              return AlertDialog(
                title: Text("Confirmação do Endereço"),
                content: Text(enderecoConfirmacao),
                actions: <Widget>[
                  FlatButton(
                    child: Text("Cancelar", style: TextStyle(color: Colors.red),),
                    onPressed: (){
                      Navigator.pop(context);
                    },
                  ),
                  FlatButton(
                    child: Text("Confirmar", style: TextStyle(color: Colors.green),),
                    onPressed: (){
                      _salvarRequisicao(destino);
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
          }
        );
      }
    }
  }

  _salvarRequisicao(Destino destino)async{

    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro.latitude = _localPassageiro.latitude;
    passageiro.longitude = _localPassageiro.longitude;
    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    Firestore db = Firestore.instance;

    db.collection("requisicoes")
    .document(requisicao.id)
    .setData(requisicao.toMap());

    //requisição ativa
    Map<String,dynamic> dadosRequisicaoAtiva={};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db.collection("requisicao_ativa")
    .document(passageiro.idUsuario)
    .setData(dadosRequisicaoAtiva);

    //chama metodo para alterar interface para o status aguardando
    //_statusAguardando();

    //adicionar listener para requisicao
    if(_streamSubscriptionRequisicoes == null){
      _adicionarListenerRequisicao(requisicao.id);
    }
  }
  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }
  _recuperaUltimaLocalizacao() async{
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);
    _localPassageiro = position;
    _exibirMarcadorPassageiro(position );
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    // _localPassageiro = position;
    _movimentarCamera(cameraPosition);
    setState(() {
      if(position != null){


        /*
        _exibirMarcadorPassageiro(position);
        _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);

        _movimentarCamera(_posicaoCamera);

         */
      }
    });

  }

  _adicionarListenerLocalizacao(){
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10
    );
    geolocator.getPositionStream(locationOptions).listen((Position position){
      //_localPassageiro = position;
      //_exibirMarcadorPassageiro(position );
      //CameraPosition cameraPosition = CameraPosition(
        //  target: LatLng(position.latitude, position.longitude), zoom: 19);
      //_localPassageiro = position;
      //_movimentarCamera(cameraPosition);
      /*
      _exibirMarcadorPassageiro(position);
      _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
     // _localPassageiro = position;
      _movimentarCamera(_posicaoCamera);

       */
      if(_idRequisicao != null && _idRequisicao.isNotEmpty){
        //atualiza local passageiro
        UsuarioFirebase.atualizarDadosLocalizacao(
            _idRequisicao,
            position.latitude,
            position.longitude);
      }else{
          setState(() {
            _localPassageiro = position;
          });
          _statusUberNaoChamado();
      }

    });
  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao){
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado(){

    _exibirCaixaEnderecoDeestino = true;
    _alterarBotaoPrincipal(
        "Chamar Uber",
        Color(0xff1ebbd8),
        (){
          _chamarUber();
        }
    );
    if(_localPassageiro != null){
      Position position = Position(
          latitude: _localPassageiro.latitude,
          longitude: _localPassageiro.longitude
      );
      _exibirMarcadorPassageiro( position );
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);
      // _localPassageiro = position;
      _movimentarCamera(cameraPosition);
    }


  }

  _statusAguardando(){
    _exibirCaixaEnderecoDeestino = false;
    _alterarBotaoPrincipal(
        "Cancelar",
        Colors.red,
            (){
          _cancelarUber();
        }
    );
    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];
    Position position = Position(
        latitude: passageiroLat,
        longitude:passageiroLon
    );
    _exibirMarcadorPassageiro(position );
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);
    // _localPassageiro = position;
    _movimentarCamera(cameraPosition);
  }

  _statusACaminho(){
    _exibirCaixaEnderecoDeestino=false;
    _alterarBotaoPrincipal(
        "Motorista a Caminho",
        Colors.grey,
            (){

        }
    );

    double latitudeDestino = _dadosRequisicao["passageiro"]["latitude"];
    double longitudeDestino = _dadosRequisicao["passageiro"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];
    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem,longitudeOrigem),
        "imagens/motorista.png",
        "Local motorista");
    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino,longitudeDestino),
        "imagens/passageiro.png",
        "Local destino");
    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);
  }

  _statusEmViagem(){
    _exibirCaixaEnderecoDeestino = false;
    //_mensagemStatus = "Em viagem";
    _alterarBotaoPrincipal(
        "Em Viagem",
        Colors.grey,
        (){}
    );
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem,longitudeOrigem),
        "imagens/motorista.png",
        "Local motorista");
    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino,longitudeDestino),
        "imagens/destino.png",
        "Local destino");
    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);
  }

  _statusFinalizada()async{

    //calcula valor da corrida
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["origem"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["origem"]["longitude"];

    double distanciaEmMetros = await Geolocator().distanceBetween(
        latitudeOrigem,
        longitudeOrigem,
        latitudeDestino,
        longitudeDestino);
    //converte para km
    double distanciaKm = distanciaEmMetros / 1000;
    //valor cobrado 8 reais por km
    double valorViagem = distanciaKm*8;
    //formatar valor da viagem
    var f = NumberFormat('#,##0.00', 'pt_BR');
    var valorViagemFormatado = f.format(valorViagem);
    _alterarBotaoPrincipal(
        "Total - R\$ ${valorViagemFormatado}",
        Colors.green,
            (){
        }
    );
    _marcadores = {};
    Position position = Position(
        latitude:latitudeDestino,
        longitude: longitudeDestino);

    _exibirMarcador(
        position,
        "imagens/destino.png",
        "Destino"
    );
    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 19
    );
    _movimentarCamera(cameraPosition);
  }

  _statusConfirmada(){
    if(_streamSubscriptionRequisicoes!= null){
      _exibirCaixaEnderecoDeestino=true;
      _alterarBotaoPrincipal(
      "Chamar Uber",
          Color(0xff1ebbd8),
          (){
          _chamarUber();
          }
          );
      _dadosRequisicao = {};
    }
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        icone)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);
      setState(() {
        _marcadores.add(marcador);
      });
    });
  }

  _exibirCentralizarDoisMarcadores(Marcador marcadorOrigem, Marcador marcadorDestino){

    double latitudeOrigem = marcadorOrigem.local.latitude;
    double longitudeOrigem = marcadorOrigem.local.longitude;

    double latitudeDestino = marcadorDestino.local.latitude;
    double longitudeDestino = marcadorDestino.local.longitude;

    //exbir dois marcadores
    _exibirDoisMarcadores(
        marcadorOrigem,
        marcadorDestino);

    //south <= north
    var nLat, nLon, sLat, sLon;
    if(latitudeOrigem <= latitudeDestino){
      sLat = latitudeOrigem;
      nLat = latitudeDestino;
    }else{
      sLat = latitudeDestino;
      nLat = latitudeOrigem;
    }
    if(longitudeOrigem <= longitudeDestino){
      sLon = longitudeOrigem;
      nLon = longitudeDestino;
    }else{
      sLon = longitudeDestino;
      nLon = longitudeOrigem;
    }
    _movimentarCameraBounds(
        LatLngBounds(
            northeast: LatLng(nLat,nLon),
            southwest: LatLng(sLat,sLon)
        )
    );
  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(
        CameraUpdate.newLatLngBounds(
            latLngBounds,
            100
        )
    );
  }

  _exibirDoisMarcadores(Marcador marcadorOrigem, Marcador marcadorDestino){
    //LatLng motorista, LatLng passageiro
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    LatLng latLngOrigem = marcadorOrigem.local;
    LatLng latLngDestino = marcadorDestino.local;
    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        marcadorOrigem.caminhoImagem)
        .then((BitmapDescriptor icone) {
      Marker mOrigem = Marker(
          markerId: MarkerId(marcadorOrigem.caminhoImagem),
          position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
          infoWindow: InfoWindow(title: marcadorOrigem.titulo),
          icon: icone);
      _listaMarcadores.add(mOrigem);
    });
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        marcadorDestino.caminhoImagem)
        .then((BitmapDescriptor iconeP) {
      Marker mDestino = Marker(
          markerId: MarkerId(marcadorDestino.caminhoImagem),
          position: LatLng(latLngDestino.latitude, latLngDestino.longitude),
          infoWindow: InfoWindow(title: marcadorDestino.titulo),
          icon: iconeP);
      _listaMarcadores.add(mDestino);
    });
    setState(() {
      _marcadores = _listaMarcadores;
      //_movimentarCamera(CameraPosition(
      //target: LatLng(motorista.latitude,motorista.longitude),
      //  zoom: 18
      //));
    });
  }



  _cancelarUber()async{
    FirebaseUser firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    Firestore db = Firestore.instance;
    db.collection("requisicoes")
    .document(_idRequisicao)
    .updateData({
      "status": StatusRequisicao.CANCELADA
    }).then((_){
      db.collection("requisicao_ativa")
          .document(firebaseUser.uid)
          .delete();
    });
  }

  _recuperarRequisicaoAtiva()async{
    FirebaseUser firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot = await db.collection("requisicao_ativa")
    .document(firebaseUser.uid)
    .get();

    if(documentSnapshot.data != null){
      Map<String,dynamic> dados = documentSnapshot.data;
      _idRequisicao = dados["id_requisicao"];
      _adicionarListenerRequisicao(_idRequisicao);
    }else{
      _statusUberNaoChamado();
    }
  }

  _adicionarListenerRequisicao(String idRequisicao)async{
    Firestore db = Firestore.instance;

    _streamSubscriptionRequisicoes = await db.collection("requisicoes")
        .document(idRequisicao).snapshots().listen((snapshots){
      if( snapshots.data != null ){

        Map<String,dynamic> dados = snapshots.data;
        _dadosRequisicao = dados;
        String status = dados["status"];
        _idRequisicao = dados["id_requisicao"];
        switch( status ){

          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;

          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;

          case StatusRequisicao.VIAGEM:
            _statusEmViagem();
            break;

          case StatusRequisicao.FINALIZADA:
            _statusFinalizada();
            break;

          case StatusRequisicao.CONFIRMADA:
            _statusConfirmada();
            break;
        }
      }
    });

  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    //adicionar listener para requisicao ativa
    _recuperarRequisicaoAtiva();
    _recuperaUltimaLocalizacao();
    _adicionarListenerLocalizacao();
    //_statusUberNaoChamado();


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel passageiro"),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
            itemBuilder: (context) {
              return itensMenu.map((String item) {
                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();
            },
          )
        ],
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _marcadores,
              //-23,559200, -46,658878
            ),

            Visibility(
              visible: _exibirCaixaEnderecoDeestino,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20),
                                width: 10,
                                height: 10,
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.green,
                                ),
                              ),
                              hintText: "Meu local",
                              border: InputBorder.none,
                              contentPadding:
                              EdgeInsets.only(left: 15, top: 16)),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 55,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white),
                        child: TextField(
                          controller: _controllerDestino,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20),
                                width: 10,
                                height: 10,
                                child: Icon(
                                  Icons.local_taxi,
                                  color: Colors.black,
                                ),
                              ),
                              hintText: "Digite o destino",
                              border: InputBorder.none,
                              contentPadding:
                              EdgeInsets.only(left: 15, top: 16)),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),

            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: RaisedButton(
                    child: Text(
                      _textoBotao,
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: _corBotao,
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: _funcaoBotao
                )
              ),
            )

          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _streamSubscriptionRequisicoes.cancel();
  }
}
