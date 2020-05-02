import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {

  String idRequisicao;
  Corrida(this.idRequisicao);
  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  Set<Marker> _marcadores = {};
  Map<String,dynamic>_dadosRequisicao;
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
  CameraPosition(target: LatLng(-23.563999, -46.653256));
  String _textoBotao = "Aceitar Corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  //Position _localMotorista;
  String _mensagemStatus="";
  String _idRequisicao;
  Position _localMotorista;
  String _statusRequisicao=StatusRequisicao.AGUARDANDO;


  _alterarBotaoPrincipal(String texto, Color cor, Function funcao){
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }


  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }
  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
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

  _recuperaUltimaLocalizacao() async{
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    if(position != null){
      _localMotorista = position;
      _exibirMarcador(position, "imagens/motorista.png", "meu local");
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 19
      );
      _movimentarCamera(cameraPosition);
      //atualizar localização em tempo real do motorista

    }

    /*
    setState(() {
      if(position != null){
        _exibirMarcadorPassageiro(position);
        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 19
        );
        _movimentarCamera(_posicaoCamera);

      }
    });

     */

  }

  _adicionarListenerLocalizacao(){
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10
    );

    geolocator.getPositionStream(locationOptions).listen((Position position){
      /*_localMotorista = position;
      _exibirMarcador(position, "imagens/motorista.png", "meu local");
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 19
      );
      _movimentarCamera(cameraPosition);

       */

      if(position != null){
        if(_idRequisicao != null && _idRequisicao.isNotEmpty){
          if(_statusRequisicao!= StatusRequisicao.AGUARDANDO){
            //atualiza local passageiro
            UsuarioFirebase.atualizarDadosLocalizacao(
                _idRequisicao,
                position.latitude,
                position.longitude);
          }else{
            //aguardando
            setState(() {
              _localMotorista = position;
            });
            _statusAguardando();
          }
        }/*else if(position != null){
          setState(() {
            _localMotorista = position;
          });
        }
        */
      }

      /*
       _exibirMarcadorPassageiro(position);
      _posicaoCamera = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
          zoom: 19
      );
      _movimentarCamera(_posicaoCamera);
      setState(() {
        _localMotorista=position;
      });

       */

    });
  }
  _recuperaRequisicao() async {
    String idRequisicao = widget.idRequisicao;
    Firestore db = Firestore.instance;
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicoes")
        .document(idRequisicao)
        .get();
    //_dadosRequisicao = documentSnapshot.data;
    //_adicionarListenerRequisicao();
  }

  _adicionarListenerRequisicao() async {
    Firestore db = Firestore.instance;
    //String idRequisicao = _dadosRequisicao["id"];
    await db.collection("requisicoes")
    .document(_idRequisicao).snapshots().listen((snapshots){

      if(snapshots.data != null) {
        _dadosRequisicao = snapshots.data;
        Map<String, dynamic> dados = snapshots.data;
        _statusRequisicao = dados["status"];

        switch (_statusRequisicao) {
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
  _statusACaminho(){
    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal(
        "Iniciar corrida",
        Color(0xff1ebbd8),
        (){
          _iniciarCorrida();
        }
    );
    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];
    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];
    //exbir dois marcadores
    _exibirDoisMarcadores(
        LatLng(latitudeMotorista,longitudeMotorista),
        LatLng(latitudePassageiro,longitudePassageiro)
    );

    //south <= north
    var nLat, nLon, sLat, sLon;
    if(latitudeMotorista <= latitudePassageiro){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    }else{
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }
    if(longitudeMotorista <= longitudePassageiro){
      sLon = latitudeMotorista;
      nLon = longitudePassageiro;
    }else{
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }


    _movimentarCameraBounds(
        LatLngBounds(
            northeast: LatLng(nLat,nLon),
            southwest: LatLng(sLat,sLon)
        )
    );
  }

  _finalizarCorrida(){

    Firestore db = Firestore.instance;
    db.collection("requisicoes")
    .document(_idRequisicao)
    .updateData({
      "status" : StatusRequisicao.FINALIZADA
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
        .document(idPassageiro)
        .updateData({
      "status" : StatusRequisicao.FINALIZADA
    });

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .document(idMotorista)
        .updateData({
      "status" : StatusRequisicao.FINALIZADA
    });


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
    _mensagemStatus = "Viagem Finalizada";
    _alterarBotaoPrincipal(
        "Confirmar - R\$ ${valorViagemFormatado}",
        Color(0xff1ebbd8),
            (){
         _confirmarCorrida();
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
  _confirmarCorrida(){
    Firestore db = Firestore.instance;
    db.collection("requisicoes")
        .document(_idRequisicao)
        .updateData({
      "status" : StatusRequisicao.CONFIRMADA
    });
    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
        .document(idPassageiro)
        .delete();
    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .document(idMotorista)
        .delete();

  }

  _statusConfirmada(){
    Navigator.pushReplacementNamed(
        context, "/painel-motorista");
  }

  _statusEmViagem(){
    _mensagemStatus = "Em viagem";
    _alterarBotaoPrincipal(
        "Finalizar Corrida",
        Color(0xff1ebbd8),
            (){
          _finalizarCorrida();
        }
    );
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];
    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];
    //exbir dois marcadores
    _exibirDoisMarcadores(
        LatLng(latitudeOrigem,longitudeOrigem),
        LatLng(latitudeDestino,longitudeDestino)
    );

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

  _iniciarCorrida(){
    Firestore db = Firestore.instance;
    db.collection("requisicoes")
    .document(_idRequisicao)
    .updateData({
      "origem": {
        "latitude" : _dadosRequisicao["motorista"]["latitude"],
        "longitude" : _dadosRequisicao["motorista"]["longitude"]
      },
      "status" : StatusRequisicao.VIAGEM
    });
    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
    .document(idPassageiro)
    .updateData({
      "status" : StatusRequisicao.VIAGEM
    });
    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .document(idMotorista)
        .updateData({
      "status" : StatusRequisicao.VIAGEM
    });
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

  _exibirDoisMarcadores(LatLng motorista, LatLng passageiro){

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorMotorista = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(motorista.latitude, motorista.longitude),
          infoWindow: InfoWindow(title: "Local Motorista"),
          icon: icone);
      _listaMarcadores.add(marcadorMotorista);
    });
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png")
        .then((BitmapDescriptor iconeP) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(passageiro.latitude, passageiro.longitude),
          infoWindow: InfoWindow(title: "Local Passageiro"),
          icon: iconeP);
      _listaMarcadores.add(marcadorPassageiro);
    });
    setState(() {
      _marcadores = _listaMarcadores;
      //_movimentarCamera(CameraPosition(
          //target: LatLng(motorista.latitude,motorista.longitude),
        //  zoom: 18
      //));
    });



  }

  _statusAguardando(){
    _alterarBotaoPrincipal(
        "Aceitar Corrida",
        Color(0xff1ebbd8),
            (){
          _aceitarCorrida();
        }
    );
    if(_localMotorista !=null){
      double motoristaLat = _localMotorista.latitude;
      double motoristaLong = _localMotorista.longitude;
      Position position = Position(
          latitude:motoristaLat,
          longitude: motoristaLong);

      _exibirMarcador(
          position,
          "imagens/motorista.png",
          "Motorista"
      );
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 19
      );
      _movimentarCamera(cameraPosition);
    }

  }

  _aceitarCorrida() async {
    //recupera dados do usuario

    Usuario motorista   = await UsuarioFirebase.getDadosUsuarioLogado();
   // motorista.latitude  = _dadosRequisicao["motorista"]["latitude"];
   // motorista.longitude = _dadosRequisicao["motorista"]["longitude"];
    motorista.latitude  = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;
    Firestore db = Firestore.instance;
    String idRequisicao = _dadosRequisicao["id"];
    
    db.collection("requisicoes")
    .document(idRequisicao)
    .updateData({
      "motorista": motorista.toMap(),
      "status" : StatusRequisicao.A_CAMINHO
    }).then((_){
      //atualizar requisicao ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa").document(idPassageiro)
      .updateData({
        "status" : StatusRequisicao.A_CAMINHO
      });
      //salvar requisicao ativa para o motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista")
          .document(idMotorista)
          .setData({
            "id_requisicao": idRequisicao,
            "id_usuario": idMotorista,
            "status" : StatusRequisicao.A_CAMINHO
          });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _idRequisicao = widget.idRequisicao;
    _adicionarListenerRequisicao();
    _recuperaUltimaLocalizacao();
    _adicionarListenerLocalizacao();

    //adicinar listener para mudanças na requisicao
    //_recuperaRequisicao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel Corrida - " + _mensagemStatus),
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
              zoomControlsEnabled: false,
              //-23,559200, -46,658878
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
}
